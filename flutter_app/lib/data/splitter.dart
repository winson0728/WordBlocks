import 'lexicon.dart';

enum AnalysisSource { lexicon, guess, none }

class Analysis {
  const Analysis(this.word, this.parts, this.source, {this.entry, this.inflectedFrom});

  final String word;
  final List<WordPart> parts;
  final AnalysisSource source;

  /// The reviewed lexicon entry, when there is one.
  final Word? entry;

  /// The form the user typed when it was matched to a base word ("disrupted" -> "disrupt").
  final String? inflectedFrom;
}

class _Form {
  const _Form(this.text, this.id, this.type);
  final String text;
  final String id;
  final MorphemeType type;
}

class _Step {
  const _Step(this.cost, this.prev, this.part);
  final double cost;
  final String? prev;
  final WordPart? part;
}

/// Splits English words into prefixes, roots and suffixes.
/// Mirrors analyze() and autoSeg() in the web app's index.html.
class Splitter {
  Splitter(this.lexicon) {
    final seen = <String>{};
    void add(String text, Morpheme m) {
      if (m.id == 'panGod' || text.isEmpty) return;
      if (seen.add('$text|${m.type.name}')) _forms.add(_Form(text, m.id, m.type));
    }

    for (final m in lexicon.morphemes.values) {
      for (final s in m.spellings) {
        add(s, m);
      }
    }
    for (final w in lexicon.words) {
      for (final p in w.parts) {
        add(p.text, lexicon.morphemes[p.id]!);
      }
    }
  }

  final Lexicon lexicon;
  final List<_Form> _forms = [];

  static const _inflections = [
    ['ies', 'y'], ['ied', 'y'], ['ing', 'e'], ['ing', ''], ['ed', 'e'], ['ed', ''], ['d', ''], ['es', ''], ['s', ''],
  ];

  Analysis? analyze(String raw) {
    final s = raw.toLowerCase().replaceAll(RegExp('[^a-z]'), '');
    if (s.isEmpty) return null;
    final direct = lexicon.byWord[s];
    if (direct != null) return Analysis(s, direct.parts, AnalysisSource.lexicon, entry: direct);
    for (final pair in _inflections) {
      if (s.endsWith(pair[0])) {
        final base = s.substring(0, s.length - pair[0].length) + pair[1];
        final w = lexicon.byWord[base];
        if (w != null) return Analysis(w.word, w.parts, AnalysisSource.lexicon, entry: w, inflectedFrom: s);
      }
    }
    final g = guess(s);
    if (g != null) return Analysis(s, g, AnalysisSource.guess);
    return Analysis(s, const [], AnalysisSource.none);
  }

  /// Cheapest split of [s] as prefixes, then at least one root, then suffixes.
  /// Unknown letters are allowed at a cost; returns null when too much is unknown.
  List<WordPart>? guess(String s) {
    const phase = {MorphemeType.pre: 0, MorphemeType.root: 1, MorphemeType.suf: 2};
    final n = s.length;
    String key(int i, int p, int r) => '$i|$p|$r';
    final best = <String, _Step>{key(0, 0, 0): const _Step(0, null, null)};

    for (var i = 0; i < n; i++) {
      for (var p = 0; p < 3; p++) {
        for (var r = 0; r < 2; r++) {
          final from = key(i, p, r);
          final cur = best[from];
          if (cur == null) continue;
          void relax(int j, int np, int nr, double cost, WordPart part) {
            final k = key(j, np, nr);
            final c = cur.cost + cost;
            final old = best[k];
            if (old == null || c < old.cost) best[k] = _Step(c, from, part);
          }

          for (final f in _forms) {
            if (!s.startsWith(f.text, i)) continue;
            final fp = phase[f.type]!;
            if (fp < p || (f.type == MorphemeType.suf && r == 0)) continue;
            final len = f.text.length;
            final cost = 1.0 + (len <= 2 ? 0.9 : 0.0) + (len == 1 ? 1.0 : 0.0);
            relax(i + len, fp, (r == 1 || f.type == MorphemeType.root) ? 1 : 0, cost, WordPart(f.id, f.text));
          }
          relax(i + 1, p, r, 'aeiou'.contains(s[i]) ? 1.4 : 2.6, WordPart(null, s[i]));
        }
      }
    }

    _Step? end;
    for (var p = 0; p < 3; p++) {
      final o = best[key(n, p, 1)];
      if (o != null && (end == null || o.cost < end.cost)) end = o;
    }
    if (end == null) return null;

    final segs = <WordPart>[];
    for (_Step? node = end; node != null && node.part != null; node = best[node.prev]) {
      segs.insert(0, node.part!);
    }
    final out = <WordPart>[];
    for (final g in segs) {
      if (g.id == null && out.isNotEmpty && out.last.id == null) {
        out[out.length - 1] = WordPart(null, out.last.text + g.text);
      } else {
        out.add(g);
      }
    }
    final unknown = out.where((g) => g.id == null).fold<int>(0, (a, g) => a + g.text.length);
    return unknown / n > .45 ? null : out;
  }
}
