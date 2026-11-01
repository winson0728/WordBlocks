import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
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
}
