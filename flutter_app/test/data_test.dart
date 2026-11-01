import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wordblocks/data/lexicon.dart';
import 'package:wordblocks/data/review_store.dart';
import 'package:wordblocks/data/splitter.dart';

void main() {
  late Lexicon lex;
  late Splitter splitter;

  setUpAll(() {
    lex = Lexicon.fromJson(jsonDecode(File('assets/wordblocks.json').readAsStringSync()) as Map<String, dynamic>);
    splitter = Splitter(lex);
  });

  group('lexicon', () {
    test('every word is spelled by its parts and every part exists', () {
      expect(lex.words.length, greaterThan(400));
      for (final w in lex.words) {
        expect(w.parts.map((p) => p.text).join(), w.word);
        for (final p in w.parts) {
          expect(lex.morphemes.containsKey(p.id), isTrue, reason: '${w.word}: ${p.id}');
        }
      }
    });

    test('words are indexed by morpheme', () {
      expect(lex.wordsWith('struct').map((w) => w.word), containsAll(['construct', 'destroy', 'infrastructure']));
      expect(lex.morphemes['sub']!.spellings, ['sub', 'sup', 'su']);
      expect(lex.morphemes['inneg']!.label, 'in-');
    });

    test('root of the day is stable within a day and is a root', () {
      final a = lex.rootOfTheDay(DateTime(2026, 11, 1, 8));
      final b = lex.rootOfTheDay(DateTime(2026, 11, 1, 23));
      expect(a.id, b.id);
      expect(a.type, MorphemeType.root);
    });
  });

  group('splitter', () {
    test('finds reviewed entries, including inflected forms', () {
      final r = splitter.analyze('Disrupted')!;
      expect(r.source, AnalysisSource.lexicon);
      expect(r.word, 'disrupt');
      expect(r.inflectedFrom, 'disrupted');
    });

    test('guesses unseen words from known parts', () {
      final r = splitter.analyze('transportation')!;
      expect(r.source, AnalysisSource.guess);
      expect(r.parts.map((p) => p.text), ['trans', 'port', 'ation']);
      expect(r.parts.map((p) => p.id), ['trans', 'port', 'ion']);
    });

    test('gives up on words with no known root', () {
      expect(splitter.analyze('dog')!.source, AnalysisSource.none);
      expect(splitter.analyze('  '), isNull);
    });
  });

  group('scheduling', () {
    final now = DateTime(2026, 11, 1, 9);

    test('new card intervals', () {
      expect(schedule(null, Grade.again, now).due.difference(now), const Duration(minutes: 1));
      expect(schedule(null, Grade.hard, now).due.difference(now), const Duration(minutes: 10));
      expect(schedule(null, Grade.good, now).intervalDays, 1);
      expect(schedule(null, Grade.easy, now).intervalDays, 4);
    });

    test('good answers grow the interval; again resets it', () {
      var c = schedule(null, Grade.good, now);
      c = schedule(c, Grade.good, now);
      expect(c.intervalDays, 3);
      c = schedule(c, Grade.good, now);
      expect(c.intervalDays, 8); // 3 * 2.5 rounded
      final lapsed = schedule(c, Grade.again, now);
      expect(lapsed.reps, 0);
      expect(lapsed.lapses, 1);
      expect(lapsed.ease, closeTo(2.3, 1e-9));
      expect(lapsed.learned, isFalse);
    });

    test('state survives a JSON round trip', () {
      final c = schedule(schedule(null, Grade.good, now), Grade.easy, now);
      final back = CardState.fromJson(jsonDecode(jsonEncode(c.toJson())) as Map<String, dynamic>);
      expect(back.intervalDays, c.intervalDays);
      expect(back.ease, c.ease);
      expect(back.due, c.due);
      expect(back.last, Grade.easy);
    });

    test('delay labels', () {
      expect(formatDelay(const Duration(minutes: 10)), '10 分');
      expect(formatDelay(const Duration(hours: 5)), '5 小時');
      expect(formatDelay(const Duration(days: 3)), '3 天');
      expect(formatDelay(const Duration(days: 45)), '1.5 個月');
    });
  });

  group('levels', () {
    test('every word has a level and lower levels are subsets', () {
      expect(lex.words.every((w) => w.level >= 1 && w.level <= 3), isTrue);
      expect(lex.words.where((w) => w.level == 1).length, greaterThan(200));
      final basic = lex.deckFor(1).toSet(), all = lex.deckFor(3).toSet();
      expect(all.containsAll(basic), isTrue);
      expect(lex.wordsWith('struct', maxLevel: 1).every((w) => w.level == 1), isTrue);
      expect(lex.wordsWith('struct').length, greaterThanOrEqualTo(lex.wordsWith('struct', maxLevel: 1).length));
    });
  });

  group('day number (shared with the web app and the Android widget)', () {
    test('counts calendar days since 2024-01-01', () {
      expect(Lexicon.dayNumber(DateTime(2024, 1, 1, 23, 59)), 0);
      expect(Lexicon.dayNumber(DateTime(2024, 3, 1)), 60); // 2024 is a leap year
      expect(Lexicon.dayNumber(DateTime(2026, 11, 1, 0, 1)), 1035);
    });
  });

  group('progress sync', () {
    Map<String, dynamic> card(int t, int reps) =>
        {'ease': 2.5, 'ivl': 1, 'reps': reps, 'lapses': 0, 'last': 2, 'due': 0, 't': t};

    test('newer card wins, days are combined, counters keep the larger value', () {
      final phone = {
        'cards': {'struct': card(200, 2), 'spect': card(100, 1)},
        'days': ['2026-10-30', '2026-11-01'],
        'counters': {'puzzles': 4, 'split': 1},
      };
      final web = {
        'cards': {'struct': card(150, 5), 'port': card(120, 1)},
        'days': ['2026-10-31', '2026-11-01'],
        'counters': {'puzzles': 2, 'myth': 1},
      };
      final m = mergeProgress(phone, web);
      expect((m['cards'] as Map)['struct']['t'], 200);
      expect((m['cards'] as Map).keys, containsAll(['struct', 'spect', 'port']));
      expect(m['days'], ['2026-10-30', '2026-10-31', '2026-11-01']);
      expect(m['counters'], {'puzzles': 4, 'split': 1, 'myth': 1});
      // Order does not matter.
      expect((mergeProgress(web, phone)['cards'] as Map)['struct']['t'], 200);
    });

    test('store imports another device and reports whether anything changed', () async {
      SharedPreferences.setMockInitialValues({});
      final store = ReviewStore(await SharedPreferences.getInstance());
      final now = DateTime(2026, 11, 1, 9);
      store.grade('struct', Grade.good, now);
      store.recordPuzzle();

      final other = {
        'cards': {'spect': schedule(null, Grade.easy, now).toJson()},
        'days': ['2026-10-31'],
        'counters': {'puzzles': 3},
      };
      expect(store.importProgress(other), isTrue);
      expect(store.isLearned('struct'), isTrue);
      expect(store.isLearned('spect'), isTrue);
      expect(store.puzzlesSolved, 3);
      expect(store.importProgress(other), isFalse); // already merged

      // Survives a restart.
      final reloaded = ReviewStore(await SharedPreferences.getInstance());
      expect(reloaded.exportProgress()['cards'], store.exportProgress()['cards']);
      expect(reloaded.streak(now), 2);
    });

    test('older saves with a top-level puzzle count are migrated', () async {
      SharedPreferences.setMockInitialValues({
        'wordblocks.review.v1': '{"cards":{},"days":[],"puzzles":7}',
      });
      final store = ReviewStore(await SharedPreferences.getInstance());
      expect(store.puzzlesSolved, 7);
    });
  });
}
