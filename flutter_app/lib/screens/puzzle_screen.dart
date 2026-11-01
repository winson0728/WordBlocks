import 'dart:math';

import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../data/lexicon.dart';
import '../widgets/blocks.dart';

class _Puzzle {
  _Puzzle({required this.meaning, required this.hint, required this.answers, required this.tiles});
  final String meaning;
  final String hint;
  final List<String> answers;
  final List<WordPart> tiles;
  final List<int> placed = [];
  bool solved = false;
  bool wrong = false;
  bool showHint = false;

  String get spelled => placed.map((i) => tiles[i].text).join();
}

/// Build the word that matches a Chinese meaning by tapping blocks.
class PuzzleScreen extends StatefulWidget {
  const PuzzleScreen({super.key, this.random});
  final Random? random;

  @override
  State<PuzzleScreen> createState() => _PuzzleScreenState();
}

class _PuzzleScreenState extends State<PuzzleScreen> {
  late final Random _rng = widget.random ?? Random();
  _Puzzle? _p;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _p ??= _first();
  }

  _Puzzle _first() => _Puzzle(
        meaning: '預先警告',
        hint: '兩種拼法都對：古英語的 fore + warn，或拉丁語的 pre + mon + ition（預感）',
        answers: const ['forewarn', 'premonition'],
        tiles: [
          for (final s in ['fore', 'warn', 'pre', 'mon', 'ion=ition', 'dict', 'ject', 'struct'])
            WordPart(s.split('=').first, s.contains('=') ? s.split('=').last : s),
        ]..shuffle(_rng),
      );

  _Puzzle _next() {
    final lex = AppScope.of(context).lexicon;
    final lv = AppScope.of(context).store.maxLevel;
    final pool = lex.words
        .where((w) => w.level <= lv && w.parts.length >= 2 && !(_p?.answers.contains(w.word) ?? false))
        .toList();
    final w = pool[_rng.nextInt(pool.length)];
    final texts = {for (final p in w.parts) p.text};
    final extra = <WordPart>[];
    for (final o in [...lex.words]..shuffle(_rng)) {
      for (final p in o.parts) {
        if (extra.length < 4 && o != w && texts.add(p.text)) extra.add(p);
      }
      if (extra.length >= 4) break;
    }
    return _Puzzle(meaning: w.meaning, hint: w.literal, answers: [w.word], tiles: [...w.parts, ...extra]..shuffle(_rng));
  }

  void _check() {
    final p = _p!;
    if (p.placed.isEmpty) return;
    setState(() {
      if (p.answers.contains(p.spelled)) {
        p.solved = true;
        AppScope.of(context).store.recordPuzzle();
      } else {
        p.wrong = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = _p!;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final store = AppScope.of(context).store;
    final other = p.answers.where((a) => a != p.spelled).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('請拼出意思是', style: text.labelMedium),
              Text(p.meaning, style: text.headlineMedium),
            ]),
          ),
          Column(children: [
            Text('${store.puzzlesSolved}', style: text.titleLarge),
            Text('已完成', style: text.bodySmall),
          ]),
        ]),
        SizedBox(height: 28, child: p.showHint ? Text('提示：${p.hint}', style: text.bodySmall) : null),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          constraints: const BoxConstraints(minHeight: 110),
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          decoration: BoxDecoration(
            color: p.solved ? Colors.green.withValues(alpha: .08) : scheme.surfaceContainerLow,
            border: Border.all(color: p.solved ? Colors.green : scheme.outlineVariant, width: 2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: p.placed.isEmpty
              ? Center(child: Text('點選下方積木放進來', style: text.bodyMedium))
              : Wrap(crossAxisAlignment: WrapCrossAlignment.end, children: [
                  for (var k = 0; k < p.placed.length; k++)
                    LegoBlock(
                      part: p.tiles[p.placed[k]],
                      onTap: p.solved
                          ? null
                          : () => setState(() {
                                p.placed.removeAt(k);
                                p.wrong = false;
                              }),
                    ),
                ]),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 48,
          child: p.solved
              ? Text('拼對了！${p.spelled}。${other.isEmpty ? '' : '另一個答案是 ${other.join('、')}。'}',
                  style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.w600))
              : p.wrong
                  ? Text('拼出來是 ${p.spelled}，還不是答案。點槽裡的積木可以拿掉它。',
                      style: TextStyle(color: Colors.red.shade700))
                  : null,
        ),
        Wrap(spacing: 12, runSpacing: 14, children: [
          for (var i = 0; i < p.tiles.length; i++)
            LegoBlock(
              part: p.tiles[i],
              used: p.placed.contains(i),
              onTap: p.solved
                  ? null
                  : () => setState(() {
                        p.placed.add(i);
                        p.wrong = false;
                      }),
            ),
        ]),
        const SizedBox(height: 20),
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (p.solved)
            FilledButton(onPressed: () => setState(() => _p = _next()), child: const Text('下一題'))
          else ...[
            FilledButton(onPressed: _check, child: const Text('檢查')),
            OutlinedButton(onPressed: () => setState(() => p.placed.clear()), child: const Text('清空')),
            OutlinedButton(onPressed: () => setState(() => p.showHint = true), child: const Text('提示')),
            OutlinedButton(onPressed: () => setState(() => _p = _next()), child: const Text('換一題')),
          ],
        ]),
      ],
    );
  }
}
