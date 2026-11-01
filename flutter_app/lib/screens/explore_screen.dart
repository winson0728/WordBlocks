import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../data/lexicon.dart';
import '../theme.dart';
import '../widgets/blocks.dart';

void openMorpheme(BuildContext context, String id) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => MorphemePage(id: id)));

void openWord(BuildContext context, Word w) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => WordPage(word: w)));

/// Browse prefixes, roots and suffixes by category.
class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  MorphemeType _tab = MorphemeType.root;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final lex = scope.lexicon;
    final q = _query.trim().toLowerCase();
    final lv = scope.store.maxLevel;
    final items = lex.morphemes.values.where((m) {
      if (m.type != _tab || lex.wordsWith(m.id, maxLevel: lv).isEmpty) return false;
      if (q.isEmpty) return true;
      return m.forms.toLowerCase().contains(q) ||
          m.meaning.contains(q) ||
          lex.wordsWith(m.id, maxLevel: lv).any((w) => w.word.contains(q) || w.meaning.contains(q));
    }).toList();

    return ListenableBuilder(
      listenable: scope.store,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          const TodayRootCard(),
          const SizedBox(height: 16),
          TextField(
            key: const Key('explore-search'),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: '搜尋字根、字義或單字',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: 12),
          SegmentedButton<MorphemeType>(
            segments: const [
              ButtonSegment(value: MorphemeType.root, label: Text('字根')),
              ButtonSegment(value: MorphemeType.pre, label: Text('字首')),
              ButtonSegment(value: MorphemeType.suf, label: Text('字尾')),
            ],
            selected: {_tab},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() => _tab = s.first),
          ),
          const SizedBox(height: 8),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text('找不到符合「$_query」的${typeNames[_tab]}。試試切換上方的類型。', textAlign: TextAlign.center),
            ),
          for (final cat in lex.categories)
            if (items.any((m) => m.category == cat.id)) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 16, 4, 4),
                child: Text(cat.name, style: Theme.of(context).textTheme.labelLarge),
              ),
              for (final m in items.where((m) => m.category == cat.id))
                ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  title: Row(children: [
                    Text(m.label,
                        style: TextStyle(
                            fontFamily: latin,
                            fontWeight: FontWeight.w700,
                            fontSize: 17,
                            color: morphemeColor(context, m.type))),
                    if (scope.store.isLearned(m.id))
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Icon(Icons.check_circle, size: 14, color: Colors.green.shade600, semanticLabel: '已學會'),
                      ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(m.meaning, overflow: TextOverflow.ellipsis)),
                  ]),
                  trailing: Text('${lex.wordsWith(m.id, maxLevel: lv).length}', style: Theme.of(context).textTheme.bodySmall),
                  onTap: () => openMorpheme(context, m.id),
                ),
            ],
        ],
      ),
    );
  }
}

/// What the Android home-screen widget will show: one root per day.
class TodayRootCard extends StatelessWidget {
  const TodayRootCard({super.key});

  @override
  Widget build(BuildContext context) {
    final lex = AppScope.of(context).lexicon;
    final m = lex.rootOfTheDay(DateTime.now());
    final c = morphemeColor(context, m.type);
    final ws = lex.wordsWith(m.id).take(3).map((w) => w.word).join(' · ');
    return Card(
      color: tint(context, c, .1),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => openMorpheme(context, m.id),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('今日字根', style: Theme.of(context).textTheme.labelMedium),
                Text(m.forms,
                    style: TextStyle(fontFamily: latin, fontWeight: FontWeight.w700, fontSize: 28, color: c)),
                Text(m.meaning, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(ws, style: const TextStyle(fontFamily: latin)),
              ]),
            ),
            const Icon(Icons.chevron_right),
          ]),
        ),
      ),
    );
  }
}

class MorphemePage extends StatefulWidget {
  const MorphemePage({super.key, required this.id});
  final String id;

  @override
  State<MorphemePage> createState() => _MorphemePageState();
}

class _MorphemePageState extends State<MorphemePage> {
  /// Roots whose stories count toward the 神話獵人 badge.
  static const _mythStories = {'panGod', 'bank'};

  @override
  void initState() {
    super.initState();
    if (_mythStories.contains(widget.id)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) AppScope.of(context).store.bump('myth', once: true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.id;
    final scope = AppScope.of(context);
    final m = scope.lexicon.morphemes[id]!;
    final c = morphemeColor(context, m.type);
    final words = scope.lexicon.wordsWith(id, maxLevel: scope.store.maxLevel);
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(m.label, style: const TextStyle(fontFamily: latin))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  TypeChip(m.type),
                  const SizedBox(width: 8),
                  Text(scope.lexicon.categoryName(m.category), style: text.labelMedium),
                  if (scope.store.isLearned(id)) ...[
                    const SizedBox(width: 8),
                    Text('已學會', style: text.labelMedium?.copyWith(color: Colors.green.shade700)),
                  ],
                ]),
                const SizedBox(height: 8),
                Text(m.forms, style: TextStyle(fontFamily: latin, fontWeight: FontWeight.w700, fontSize: 28, color: c)),
                Text(m.meaning, style: text.titleLarge),
                Text(m.origin, style: text.bodySmall),
                if (m.story != null) ...[
                  const Divider(height: 28),
                  Text(m.story!, style: text.bodyLarge?.copyWith(height: 1.7)),
                ],
                if (m.scene != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(children: [
                      Icon(Icons.image_outlined, color: c),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('聯想插圖 · AI 生成提示', style: text.labelSmall),
                          Text(m.scene!),
                        ]),
                      ),
                    ]),
                  ),
                ],
              ]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 20, 4, 6),
            child: Text('${words.length} 個單字', style: text.labelLarge),
          ),
          Card(
            child: Column(children: [
              for (final w in words)
                ListTile(
                  title: ColoredWord(word: w, highlight: id),
                  subtitle: Text(w.meaning),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => openWord(context, w),
                ),
            ]),
          ),
        ],
      ),
    );
  }
}

class WordPage extends StatelessWidget {
  const WordPage({super.key, required this.word});
  final Word word;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(word.word, style: const TextStyle(fontFamily: latin))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(child: ColoredWord(word: word, size: 32)),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(levelNames[word.level]!, style: text.labelSmall),
                  ),
                ]),
                const SizedBox(height: 14),
                LegoRow(parts: word.parts, onTapPart: (p) => openMorpheme(context, p.id!)),
                const SizedBox(height: 16),
                Text.rich(TextSpan(children: [
                  TextSpan(text: '${word.literal} → '),
                  TextSpan(text: word.meaning, style: const TextStyle(fontWeight: FontWeight.w700)),
                ]), style: text.bodyLarge),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(word.example, style: const TextStyle(fontFamily: latin, fontSize: 16, height: 1.5)),
                ),
                const SizedBox(height: 10),
                Text('點積木可以查看該字首、字根或字尾的所有單字。', style: text.bodySmall),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
