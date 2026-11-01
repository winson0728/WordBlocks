import 'dart:math';

import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../data/lexicon.dart';
import '../data/review_store.dart';
import '../theme.dart';
import '../widgets/blocks.dart';

enum _Mode { meaning, choose }

class _Question {
  _Question(this.id, this.mode, {this.examples = const [], this.options = const [], this.target});
  final String id;
  final _Mode mode;
  final List<Word> examples;
  final List<Word> options;
  final Word? target;
  bool revealed = false;
  int? picked;
  bool? correct;
}

/// Spaced-repetition review of prefixes and roots.
class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key, this.random});

  /// Injectable for tests.
  final Random? random;

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  late final Random _rng = widget.random ?? Random();
  List<String>? _queue;
  _Question? _q;
  int _done = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_queue == null) _start();
  }

  void _start({int extraNew = 0}) {
    final scope = AppScope.of(context);
    final lex = scope.lexicon;
    _queue = scope.store.buildQueue(lex.deckFor(scope.store.maxLevel), DateTime.now(),
        isRoot: (id) => lex.morphemes[id]!.type == MorphemeType.root, extraNew: extraNew);
    _q = _queue!.isEmpty ? null : _make(_queue!.first);
  }

  _Question _make(String id) {
    final scope = AppScope.of(context);
    final lex = scope.lexicon;
    final lv = scope.store.maxLevel;
    final visible = lex.wordsWith(id, maxLevel: lv);
    final ws = [...(visible.isEmpty ? lex.wordsWith(id) : visible)]..shuffle(_rng);
    final card = scope.store.card(id);
    if (card != null && card.reps > 0 && _rng.nextBool()) {
      // Leave out words built on any morpheme that shares a meaning (spect and vid both mean "see").
      List<String> senses(Morpheme m) => m.meaning.split(RegExp('[、；（）]')).where((s) => s.isNotEmpty).toList();
      final mine = senses(lex.morphemes[id]!);
      final similar = {
        for (final m in lex.morphemes.values)
          if (senses(m).any(mine.contains)) m.id,
      };
      final others = lex.words.where((w) => w.level <= lv && !w.parts.any((p) => similar.contains(p.id))).toList()
        ..shuffle(_rng);
      if (others.length >= 3) {
        final target = ws.first;
        return _Question(id, _Mode.choose, target: target, options: ([target, ...others.take(3)])..shuffle(_rng));
      }
    }
    return _Question(id, _Mode.meaning, examples: ws.take(2).toList());
  }

  void _grade(Grade g) {
    final q = _q!;
    AppScope.of(context).store.grade(q.id, g, DateTime.now());
    setState(() {
      _queue!.removeAt(0);
      _done++;
      if (g == Grade.again) _queue!.add(q.id);
      _q = _queue!.isEmpty ? null : _make(_queue!.first);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final lex = scope.lexicon;
    final store = scope.store;
    final now = DateTime.now();
    final text = Theme.of(context).textTheme;
    final q = _q;
    final deck = lex.deckFor(store.maxLevel);

    final stats = Row(children: [
      _Stat('${_queue?.length ?? 0}', '本輪剩餘'),
      _Stat('${min(store.newLeftToday(now), deck.where((id) => store.card(id) == null).length)}', '今日新卡'),
      _Stat('${store.learnedCount(deck)}', '已學會'),
      _Stat('${store.streak(now)} 天', '連續學習'),
    ]);

    if (q == null) {
      return ListView(padding: const EdgeInsets.all(16), children: [
        stats,
        const SizedBox(height: 32),
        Text('今天的卡片都完成了', style: text.headlineSmall, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text('這一輪複習了 $_done 張。明天到期的卡片會自動排進來。', textAlign: TextAlign.center),
        const SizedBox(height: 20),
        Center(
          child: FilledButton(
            onPressed: () => setState(() => _start(extraNew: 5)),
            child: const Text('再學 5 張新卡'),
          ),
        ),
      ]);
    }

    final m = lex.morphemes[q.id]!;
    final c = morphemeColor(context, m.type);
    final card = store.card(q.id);

    final body = <Widget>[
      Row(children: [
        TypeChip(m.type),
        const SizedBox(width: 8),
        Text(card == null ? '新卡' : '複習', style: text.labelMedium),
      ]),
      const SizedBox(height: 14),
      if (q.mode == _Mode.meaning) ...[
        Text('這個${typeNames[m.type]}是什麼意思？', style: text.bodyLarge),
        const SizedBox(height: 12),
        Text(m.forms, style: TextStyle(fontFamily: latin, fontWeight: FontWeight.w700, fontSize: 44, color: c)),
        const SizedBox(height: 6),
        Wrap(spacing: 16, children: [for (final w in q.examples) ColoredWord(word: w, highlight: q.id, size: 17)]),
        if (q.revealed) ...[
          const Divider(height: 32),
          Text(m.meaning, style: text.headlineSmall),
          Text(m.origin, style: text.bodySmall),
          for (final w in q.examples) ...[
            const SizedBox(height: 12),
            LegoRow(parts: w.parts, mini: true),
            Text('${w.word}：${w.meaning}', style: text.bodySmall),
          ],
        ],
      ] else ...[
        Text.rich(TextSpan(children: [
          TextSpan(text: '哪一個單字含有${typeNames[m.type]}「'),
          TextSpan(text: m.meaning, style: const TextStyle(fontWeight: FontWeight.w700)),
          const TextSpan(text: '」？'),
        ]), style: text.bodyLarge),
        const SizedBox(height: 14),
        for (var i = 0; i < q.options.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: !q.revealed
                    ? null
                    : q.options[i] == q.target
                        ? tint(context, Colors.green)
                        : q.picked == i
                            ? tint(context, Colors.red)
                            : null,
              ),
              onPressed: q.revealed
                  ? null
                  : () => setState(() {
                        q.picked = i;
                        q.correct = q.options[i] == q.target;
                        q.revealed = true;
                      }),
              child: Text(q.options[i].word, style: const TextStyle(fontFamily: latin, fontSize: 18)),
            ),
          ),
        if (q.revealed) ...[
          Text(
            '${q.correct! ? '答對了' : '差一點'}，答案是 ${q.target!.word}（${q.target!.meaning}）',
            style: TextStyle(fontWeight: FontWeight.w700, color: q.correct! ? Colors.green.shade700 : Colors.red.shade700),
          ),
          const SizedBox(height: 8),
          LegoRow(parts: q.target!.parts, mini: true),
        ],
      ],
    ];

    final suggested = q.correct == null ? null : (q.correct! ? Grade.good : Grade.again);
    final footer = !q.revealed
        ? (q.mode == _Mode.meaning
            ? FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                onPressed: () => setState(() => q.revealed = true),
                child: const Text('顯示答案'),
              )
            : const SizedBox.shrink())
        : Row(children: [
            for (final g in Grade.values)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: _GradeButton(
                    highlighted: g == suggested,
                    label: gradeNames[g]!,
                    delay: formatDelay(schedule(card, g, now).due.difference(now)),
                    onPressed: () => _grade(g),
                  ),
                ),
              ),
          ]);

    // The answer buttons stay pinned at the bottom so they never scroll off screen on long cards.
    return Column(children: [
      Expanded(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          children: [
            stats,
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: body),
              ),
            ),
          ],
        ),
      ),
      Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 16), child: footer),
    ]);
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.value, this.label);
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(children: [
          Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontFamily: latin)),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ]),
      );
}

class _GradeButton extends StatelessWidget {
  const _GradeButton({required this.highlighted, required this.label, required this.delay, required this.onPressed});
  final bool highlighted;
  final String label;
  final String delay;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final style = ButtonStyle(
      padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: 10)),
      shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
    );
    final child = Column(mainAxisSize: MainAxisSize.min, children: [
      Text(label),
      Text(delay, style: Theme.of(context).textTheme.labelSmall),
    ]);
    return highlighted
        ? FilledButton.tonal(style: style, onPressed: onPressed, child: child)
        : OutlinedButton(style: style, onPressed: onPressed, child: child);
  }
}
