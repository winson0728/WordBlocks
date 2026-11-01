import 'dart:math';

import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../data/lexicon.dart';
import '../theme.dart';

class _Badge {
  const _Badge(this.name, this.description, this.icon, this.color, this.progress, this.goal);
  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final int progress;
  final int goal;
  bool get unlocked => progress >= goal;
}

const _bronze = Color(0xFFA2603A), _silver = Color(0xFF7B8A93), _gold = Color(0xFFB07A12);

/// Unlock map by theme area plus achievement badges (same rules as the web app).
class BadgesScreen extends StatelessWidget {
  const BadgesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final lex = scope.lexicon;
    final store = scope.store;
    final text = Theme.of(context).textTheme;

    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final now = DateTime.now();
        final deck = lex.deckFor(store.maxLevel);
        ({int learned, int total, List<String> next}) area(String cat) {
          final ids = deck.where((id) => lex.morphemes[id]!.category == cat).toList();
          return (
            learned: store.learnedCount(ids),
            total: ids.length,
            next: [for (final id in ids.where((id) => !store.isLearned(id)).take(4)) lex.morphemes[id]!.label],
          );
        }

        final time = area('time');
        final c = store.counters;
        final badges = [
          _Badge('拆解新手', '第一次用拆解查單字', Icons.view_week, morphemeColor(context, MorphemeType.pre), min(c['split'] ?? 0, 1), 1),
          _Badge('積木學徒', '完成第一題字根積木', Icons.extension, morphemeColor(context, MorphemeType.root), min(store.puzzlesSolved, 1), 1),
          _Badge('積木大師', '完成 10 題字根積木', Icons.extension, morphemeColor(context, MorphemeType.root), min(store.puzzlesSolved, 10), 10),
          _Badge('神話獵人', '讀過一則神話或歷史字源故事（試試 Pan 或 bank）', Icons.auto_stories, morphemeColor(context, MorphemeType.suf), min(c['myth'] ?? 0, 1), 1),
          _Badge('七日不斷', '連續 7 天完成複習', Icons.local_fire_department, Colors.green.shade700, min(store.streak(now), 7), 7),
          _Badge('字根收藏家', '學會 30 個字首或字根', Icons.collections_bookmark, _gold, min(store.learnedCount(deck), 30), 30),
          _Badge('時間旅人', '學會「時間與順序」區的全部字根', Icons.hourglass_bottom, accent, time.learned, time.total),
        ];

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Text('解鎖地圖', style: text.titleMedium),
            const SizedBox(height: 8),
            for (final cat in lex.categories.where((c) => c.id != 'suf'))
              Builder(builder: (context) {
                final a = area(cat.id);
                final p = a.total == 0 ? 0.0 : a.learned / a.total;
                final (tierName, tierColor) = p >= 1
                    ? ('金牌', _gold)
                    : p >= .6
                        ? ('銀牌', _silver)
                        : p >= .3
                            ? ('銅牌', _bronze)
                            : ('尚未解鎖', Theme.of(context).colorScheme.outline);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(children: [
                        SizedBox(
                          width: 56,
                          height: 56,
                          child: Stack(alignment: Alignment.center, children: [
                            CircularProgressIndicator(
                              value: p,
                              strokeWidth: 6,
                              color: tierColor,
                              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                              semanticsLabel: '${cat.name} 進度',
                            ),
                            Text('${(p * 100).round()}%', style: text.labelMedium),
                          ]),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(cat.name, style: text.titleMedium),
                            Row(children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                                decoration: BoxDecoration(color: tint(context, tierColor, .18), borderRadius: BorderRadius.circular(5)),
                                child: Text(tierName, style: TextStyle(color: tierColor, fontSize: 12, fontWeight: FontWeight.w700)),
                              ),
                              const SizedBox(width: 8),
                              Text('${a.learned}/${a.total}', style: text.bodySmall),
                            ]),
                            Text(a.next.isEmpty ? '這一區全部學會了' : '下一批：${a.next.join(' · ')}',
                                style: text.bodySmall?.copyWith(fontFamily: latin), maxLines: 1, overflow: TextOverflow.ellipsis),
                          ]),
                        ),
                      ]),
                    ),
                  ),
                );
              }),
            const SizedBox(height: 16),
            Text('成就勳章', style: text.titleMedium),
            const SizedBox(height: 8),
            for (final b in badges)
              Opacity(
                opacity: b.unlocked ? 1 : .55,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  leading: CircleAvatar(
                    backgroundColor: tint(context, b.color, .2),
                    child: Icon(b.icon, color: b.unlocked ? b.color : Theme.of(context).colorScheme.outline),
                  ),
                  title: Text(b.name),
                  subtitle: Text(b.description),
                  trailing: Text(
                    b.unlocked ? '已解鎖' : '${b.progress}/${b.goal}',
                    style: TextStyle(color: b.unlocked ? Colors.green.shade700 : null, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
