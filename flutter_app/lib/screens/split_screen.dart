import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../data/lexicon.dart';
import '../data/splitter.dart';
import '../theme.dart';
import '../widgets/blocks.dart';
import 'explore_screen.dart';

/// Quick lookup: type any English word and see it split into blocks.
class SplitScreen extends StatefulWidget {
  const SplitScreen({super.key});

  @override
  State<SplitScreen> createState() => _SplitScreenState();
}

class _SplitScreenState extends State<SplitScreen> {
  final _controller = TextEditingController(text: 'progressive');
  Analysis? _result;

  static const examples = ['progressive', 'international', 'unpredictable', 'maintain', 'bankrupt', 'transportation'];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _result ??= AppScope.of(context).splitter.analyze(_controller.text);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _run(String w) {
    _controller.text = w;
    final scope = AppScope.of(context);
    setState(() => _result = scope.splitter.analyze(w));
    if (_result != null) scope.store.bump('split');
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Row(children: [
          Expanded(
            child: TextField(
              key: const Key('split-input'),
              controller: _controller,
              autocorrect: false,
              textInputAction: TextInputAction.search,
              style: const TextStyle(fontFamily: latin, fontSize: 18),
              decoration: const InputDecoration(hintText: '輸入英文單字', border: OutlineInputBorder(), isDense: true),
              onSubmitted: _run,
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(onPressed: () => _run(_controller.text), child: const Text('拆解')),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 4, children: [
          for (final e in examples)
            ActionChip(label: Text(e, style: const TextStyle(fontFamily: latin)), onPressed: () => _run(e)),
        ]),
        const SizedBox(height: 20),
        if (r != null) _ResultCard(result: r),
      ],
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result});
  final Analysis result;

  @override
  Widget build(BuildContext context) {
    final lex = AppScope.of(context).lexicon;
    final text = Theme.of(context).textTheme;
    final r = result;
    if (r.source == AnalysisSource.none) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(r.word, style: const TextStyle(fontFamily: latin, fontSize: 28, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text('找不到可靠的拆解。這個字可能不是由拉丁或希臘字根組成，或它的字根還沒收錄。'),
          ]),
        ),
      );
    }
    final fromLexicon = r.source == AnalysisSource.lexicon;
    final root = r.parts.where((p) => p.id != null && lex.morphemes[p.id]!.type == MorphemeType.root).firstOrNull;
    final literal = r.entry?.literal ??
        r.parts.map((p) => p.id == null ? '（連接）' : lex.morphemes[p.id]!.shortMeaning).join(' + ');
    final badge = fromLexicon ? Colors.green.shade700 : Colors.orange.shade800;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 10, children: [
            Text(r.word, style: const TextStyle(fontFamily: latin, fontSize: 30, fontWeight: FontWeight.w700)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: tint(context, badge, .15), borderRadius: BorderRadius.circular(5)),
              child: Text(fromLexicon ? '詞庫收錄' : '自動推測', style: TextStyle(color: badge, fontSize: 12)),
            ),
            if (r.inflectedFrom != null) Text('由 ${r.inflectedFrom} 還原', style: text.bodySmall),
          ]),
          const SizedBox(height: 12),
          LegoRow(parts: r.parts, onTapPart: (p) => openMorpheme(context, p.id!)),
          const SizedBox(height: 14),
          Text.rich(TextSpan(children: [
            TextSpan(text: literal),
            if (r.entry != null) ...[
              const TextSpan(text: ' → '),
              TextSpan(text: r.entry!.meaning, style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ]), style: text.bodyLarge),
          const SizedBox(height: 10),
          if (r.entry != null)
            Text(r.entry!.example, style: const TextStyle(fontFamily: latin, fontSize: 15))
          else
            Text('自動推測是用字首、字根、字尾表比對出來的，可能不準確，也還沒有中文釋義。', style: text.bodySmall),
          if (root != null) ...[
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => openMorpheme(context, root.id!),
              child: Text('查看字根 ${lex.morphemes[root.id]!.label}'),
            ),
          ],
        ]),
      ),
    );
  }
}
