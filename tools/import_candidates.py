#!/usr/bin/env python3
"""Find high-frequency words worth adding to WordBlocks.

Pulls example words from two MIT-licensed open datasets, keeps the ones that are
common in everyday and business English, splits each one with WordBlocks' own
prefix/root/suffix inventory, and writes a review list:

  data/candidates.tsv       words not yet in data/words.txt, most frequent first
  data/candidate-roots.tsv  roots the datasets know but WordBlocks lacks, ranked
                            by how many common words they would unlock

Nothing here is added to the app automatically. A person (or Claude) reviews a
candidate, writes the Chinese meaning, literal gloss and example sentence, and
copies the line into data/words.txt. Then run `node tools/build-data.mjs`.

Sources (downloaded at pinned commits, cached in .cache/):
  colingoldberg/morphemes                        MIT, (c) 2019 Colin Goldberg
  WithEnglishWeCan/generated-english-roots-list  MIT
Frequency: the `wordfreq` package (pip install wordfreq). Its data is CC BY-SA 4.0;
it is used only to rank and filter at build time and none of it is shipped.

Usage:
  python3 tools/import_candidates.py [--min-zipf 3.5] [--limit 400]
"""
import argparse
import json
import re
import sys
import urllib.request
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CACHE = ROOT / ".cache"
SOURCES = {
    "colingoldberg": "https://raw.githubusercontent.com/colingoldberg/morphemes/846aa473cb27916f2c3acedb52d98f3a2e2a6572/data/morphemes.json",
    "withenglishwecan": "https://raw.githubusercontent.com/WithEnglishWeCan/generated-english-roots-list/bf26e3842137d8f7bbc6e69ef39c05b43e3a22a6/english.roots.list.build.json",
}


def fetch(name):
    CACHE.mkdir(exist_ok=True)
    path = CACHE / f"{name}.json"
    if not path.exists():
        with urllib.request.urlopen(SOURCES[name], timeout=60) as r:
            path.write_bytes(r.read())
    return json.loads(path.read_text(encoding="utf-8"))


def read_rows(name, n):
    out = []
    for line in (ROOT / "data" / name).read_text(encoding="utf-8").splitlines():
        if line.strip() and not line.startswith("#"):
            f = line.split("|")
            if len(f) == n:
                out.append([x.strip() for x in f])
    return out


def load_inventory():
    morphemes = {r[0]: {"id": r[0], "type": r[1], "forms": r[2], "meaning": r[3]} for r in read_rows("morphemes.txt", 6)}
    words = {}
    for r in read_rows("words.txt", 5):
        words[r[0]] = r
    spellings = set()
    for m in morphemes.values():
        if m["id"] == "panGod":
            continue
        for f in re.sub(r"（.*）", "", m["forms"]).split(" / "):
            t = re.sub(r"[^a-z]", "", f.lower())
            if t:
                spellings.add((t, m["id"], m["type"]))
    for r in words.values():
        for tok in r[1].split():
            mid, _, text = tok.partition("=")
            if mid != "panGod" and mid in morphemes:
                spellings.add((text or mid, mid, morphemes[mid]["type"]))
    return morphemes, words, sorted(spellings)


def split(word, spellings):
    """Same dynamic programme as autoSeg() in index.html: prefixes, then roots, then suffixes,
    with unknown letters allowed at a cost. Returns (parts, unknown_letter_count) or None."""
    phase = {"pre": 0, "root": 1, "suf": 2}
    n = len(word)
    best = {(0, 0, 0): (0.0, None)}
    for i in range(n):
        for p in range(3):
            for r in range(2):
                cur = best.get((i, p, r))
                if not cur:
                    continue

                def relax(j, np_, nr, cost, seg):
                    k = (j, np_, nr)
                    c = cur[0] + cost
                    if k not in best or c < best[k][0]:
                        best[k] = (c, ((i, p, r), seg))

                for t, mid, typ in spellings:
                    if not word.startswith(t, i):
                        continue
                    fp = phase[typ]
                    if fp < p or (typ == "suf" and not r):
                        continue
                    cost = 1 + (0.9 if len(t) <= 2 else 0) + (1 if len(t) == 1 else 0)
                    relax(i + len(t), fp, 1 if (r or typ == "root") else 0, cost, (mid, t))
                relax(i + 1, p, r, 1.4 if word[i] in "aeiou" else 2.6, (None, word[i]))
    end = min((best[k] for k in [(n, p, 1) for p in range(3)] if k in best), default=None, key=lambda x: x[0])
    if not end:
        return None
    segs = []
    node = end
    while node and node[1]:
        prev, seg = node[1]
        segs.append(seg)
        node = best[prev]
    segs.reverse()
    out = []
    for mid, t in segs:
        if mid is None and out and out[-1][0] is None:
            out[-1] = (None, out[-1][1] + t)
        else:
            out.append((mid, t))
    unknown = sum(len(t) for mid, t in out if mid is None)
    return out, unknown


def part_spec(parts):
    return " ".join(mid if mid == t else f"{mid}={t}" for mid, t in parts)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--min-zipf", type=float, default=3.5, help="keep words at least this common (3.5 is roughly the top 10k-15k words)")
    ap.add_argument("--limit", type=int, default=400)
    args = ap.parse_args()
    try:
        from wordfreq import zipf_frequency
    except ImportError:
        sys.exit("Install wordfreq first: pip install wordfreq")

    morphemes, known_words, spellings = load_inventory()
    known_forms = {t for t, _, _ in spellings}

    # word -> list of (source, root form, english meanings)
    found = defaultdict(list)
    for root, entry in fetch("withenglishwecan").items():
        for ex in entry.get("examples", []):
            w = ex.split(" - ")[0].strip().lower()
            found[w].append(("WEWC", root, "; ".join(entry.get("meanings", []))))
    for _, group in fetch("colingoldberg").items():
        forms = [f.get("form", "") for f in group.get("forms", []) if f.get("loc") == "embedded"]
        if not forms:
            continue
        for ex in group.get("examples", []):
            found[ex.strip().lower()].append(("CG", "/".join(forms), "; ".join(group.get("meaning", []))))

    candidates, missing_roots = [], defaultdict(lambda: {"words": set(), "meaning": ""})
    for w, srcs in found.items():
        if not re.fullmatch(r"[a-z]{5,}", w) or w in known_words:
            continue
        z = zipf_frequency(w, "en")
        if z < args.min_zipf:
            continue
        res = split(w, spellings)
        parts, unknown = res if res else ([], len(w))
        has_root = any(mid and morphemes[mid]["type"] == "root" for mid, _ in parts)
        status = "ready" if parts and unknown == 0 and has_root else "needs-root"
        candidates.append((z, w, status, part_spec(parts) if status == "ready" else "", srcs))
        for _, root, meaning in srcs:
            for form in root.split("/"):
                f = re.sub(r"[^a-z]", "", form.lower())
                if f and f not in known_forms:
                    missing_roots[f]["words"].add(w)
                    missing_roots[f]["meaning"] = missing_roots[f]["meaning"] or meaning

    candidates.sort(key=lambda c: (c[2] != "ready", -c[0]))
    with open(ROOT / "data" / "candidates.tsv", "w", encoding="utf-8") as f:
        f.write("# Generated by tools/import_candidates.py. Review before copying into words.txt.\n")
        f.write("zipf\tword\tstatus\tproposed parts (words.txt syntax)\tsource roots and English meanings\n")
        for z, w, status, spec, srcs in candidates[: args.limit]:
            src = " | ".join(sorted({f"{r}: {m}" for _, r, m in srcs}))[:200]
            f.write(f"{z:.2f}\t{w}\t{status}\t{spec}\t{src}\n")

    ranked = sorted(missing_roots.items(), key=lambda kv: -len(kv[1]["words"]))
    with open(ROOT / "data" / "candidate-roots.tsv", "w", encoding="utf-8") as f:
        f.write("# Roots in the open datasets that WordBlocks does not have yet, by number of common words they unlock.\n")
        f.write("root\tcommon words\tEnglish meaning\texamples\n")
        for root, info in ranked[:150]:
            ex = ", ".join(sorted(info["words"], key=lambda x: -zipf_frequency(x, "en"))[:8])
            f.write(f"{root}\t{len(info['words'])}\t{info['meaning'][:80]}\t{ex}\n")

    ready = sum(1 for c in candidates if c[2] == "ready")
    print(f"{len(candidates)} common words not yet in WordBlocks ({ready} can be split with existing roots).")
    print("Wrote data/candidates.tsv and data/candidate-roots.tsv")


if __name__ == "__main__":
    main()
