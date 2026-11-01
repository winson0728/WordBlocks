import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum Grade { again, hard, good, easy }

const gradeNames = {Grade.again: '重來', Grade.hard: '困難', Grade.good: '良好', Grade.easy: '簡單'};

/// Memory state of one review card (a prefix or root).
class CardState {
  const CardState({
    this.ease = 2.5,
    this.intervalDays = 0,
    this.reps = 0,
    this.lapses = 0,
    this.last,
    required this.due,
  });

  factory CardState.fromJson(Map<String, dynamic> j) => CardState(
        ease: (j['ease'] as num).toDouble(),
        intervalDays: j['ivl'] as int,
        reps: j['reps'] as int,
        lapses: j['lapses'] as int,
        last: j['last'] == null ? null : Grade.values[j['last'] as int],
        due: DateTime.fromMillisecondsSinceEpoch(j['due'] as int),
      );

  final double ease;
  final int intervalDays;
  final int reps;
  final int lapses;
  final Grade? last;
  final DateTime due;

  bool get learned => reps >= 1 && last != null && last != Grade.again;

  Map<String, dynamic> toJson() => {
        'ease': ease,
        'ivl': intervalDays,
        'reps': reps,
        'lapses': lapses,
        'last': last?.index,
        'due': due.millisecondsSinceEpoch,
      };
}

/// Simplified SM-2, the same rules as nextState() in the web app.
CardState schedule(CardState? card, Grade g, DateTime now) {
  final c = card ?? CardState(due: now);
  var ease = c.ease, ivl = c.intervalDays, reps = c.reps, lapses = c.lapses;
  DateTime due;
  switch (g) {
    case Grade.again:
      reps = 0;
      lapses++;
      ease = max(1.3, ease - .2);
      ivl = 0;
      due = now.add(const Duration(minutes: 1));
    case Grade.hard:
      if (reps == 0) {
        ivl = 0;
        due = now.add(const Duration(minutes: 10));
      } else {
        ivl = max(1, (ivl * 1.2).round());
        due = now.add(Duration(days: ivl));
      }
      ease = max(1.3, ease - .15);
      reps++;
    case Grade.good:
      ivl = reps == 0 ? 1 : (reps == 1 ? 3 : (max(ivl, 1) * ease).round());
      due = now.add(Duration(days: ivl));
      reps++;
    case Grade.easy:
      ivl = reps == 0 ? 4 : (max(ivl, 1) * ease * 1.3).round();
      ease += .15;
      due = now.add(Duration(days: ivl));
      reps++;
  }
  return CardState(ease: ease, intervalDays: ivl, reps: reps, lapses: lapses, last: g, due: due);
}

String formatDelay(Duration d) {
  if (d.inMinutes < 60) return '${max(1, d.inMinutes)} 分';
  if (d.inHours < 24) return '${d.inHours} 小時';
  if (d.inDays < 31) return '${d.inDays} 天';
  return '${(d.inDays / 30).toStringAsFixed(d.inDays < 300 ? 1 : 0)} 個月';
}

/// Review progress, kept on the device with shared_preferences.
class ReviewStore extends ChangeNotifier {
  ReviewStore(this._prefs) {
    final raw = _prefs.getString(_key);
    if (raw != null) {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      (j['cards'] as Map<String, dynamic>).forEach((k, v) => _cards[k] = CardState.fromJson(v as Map<String, dynamic>));
      _newDay = j['newDay'] as String? ?? '';
      _newToday = j['newToday'] as int? ?? 0;
      _days.addAll((j['days'] as List? ?? const []).cast<String>());
      puzzlesSolved = j['puzzles'] as int? ?? 0;
    }
  }

  static const _key = 'wordblocks.review.v1';
  static const newPerDay = 8;

  final SharedPreferences _prefs;
  final Map<String, CardState> _cards = {};
  final Set<String> _days = {};
  String _newDay = '';
  int _newToday = 0;
  int puzzlesSolved = 0;

  static String dayKey(DateTime t) =>
      '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';

  CardState? card(String id) => _cards[id];
  bool isLearned(String id) => _cards[id]?.learned ?? false;
  int learnedCount(Iterable<String> ids) => ids.where(isLearned).length;

  int newLeftToday(DateTime now) => _newDay == dayKey(now) ? max(0, newPerDay - _newToday) : newPerDay;

  /// Due cards first (oldest first), then today's allowance of new cards (roots before prefixes).
  List<String> buildQueue(List<String> deck, DateTime now, {bool Function(String id)? isRoot, int extraNew = 0}) {
    final due = deck.where((id) => _cards[id] != null && !_cards[id]!.due.isAfter(now)).toList()
      ..sort((a, b) => _cards[a]!.due.compareTo(_cards[b]!.due));
    final fresh = deck.where((id) => _cards[id] == null).toList();
    if (isRoot != null) {
      fresh.sort((a, b) => (isRoot(b) ? 1 : 0) - (isRoot(a) ? 1 : 0));
    }
    return [...due, ...fresh.take(newLeftToday(now) + extraNew)];
  }

  void grade(String id, Grade g, DateTime now) {
    final today = dayKey(now);
    if (_cards[id] == null) {
      if (_newDay != today) {
        _newDay = today;
        _newToday = 0;
      }
      _newToday++;
    }
    _cards[id] = schedule(_cards[id], g, now);
    _days.add(today);
    _save();
  }

  void recordPuzzle() {
    puzzlesSolved++;
    _save();
  }

  int streak(DateTime now) {
    var t = DateTime(now.year, now.month, now.day);
    if (!_days.contains(dayKey(t))) t = t.subtract(const Duration(days: 1));
    var n = 0;
    while (_days.contains(dayKey(t))) {
      n++;
      t = t.subtract(const Duration(days: 1));
    }
    return n;
  }

  void _save() {
    _prefs.setString(
      _key,
      jsonEncode({
        'cards': _cards.map((k, v) => MapEntry(k, v.toJson())),
        'newDay': _newDay,
        'newToday': _newToday,
        'days': _days.toList(),
        'puzzles': puzzlesSolved,
      }),
    );
    notifyListeners();
  }
}
