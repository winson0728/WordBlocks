import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum Grade { again, hard, good, easy }

const gradeNames = {Grade.again: '重來', Grade.hard: '困難', Grade.good: '良好', Grade.easy: '簡單'};

/// Memory state of one review card (a prefix or root).
/// The JSON shape is shared with the web app and the sync service.
class CardState {
  const CardState({
    this.ease = 2.5,
    this.intervalDays = 0,
    this.reps = 0,
    this.lapses = 0,
    this.last,
    required this.due,
    this.updatedAt = 0,
  });

  factory CardState.fromJson(Map<String, dynamic> j) => CardState(
        ease: (j['ease'] as num).toDouble(),
        intervalDays: (j['ivl'] as num).toInt(),
        reps: (j['reps'] as num).toInt(),
        lapses: (j['lapses'] as num? ?? 0).toInt(),
        last: j['last'] == null ? null : Grade.values[(j['last'] as num).toInt()],
        due: DateTime.fromMillisecondsSinceEpoch((j['due'] as num).toInt()),
        updatedAt: (j['t'] as num? ?? 0).toInt(),
      );

  final double ease;
  final int intervalDays;
  final int reps;
  final int lapses;
  final Grade? last;
  final DateTime due;

  /// When this card was last graded (ms since epoch). Sync keeps the newer copy.
  final int updatedAt;

  bool get learned => reps >= 1 && last != null && last != Grade.again;

  Map<String, dynamic> toJson() => {
        'ease': ease,
        'ivl': intervalDays,
        'reps': reps,
        'lapses': lapses,
        'last': last?.index,
        'due': due.millisecondsSinceEpoch,
        't': updatedAt,
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
  return CardState(
    ease: ease,
    intervalDays: ivl,
    reps: reps,
    lapses: lapses,
    last: g,
    due: due,
    updatedAt: now.millisecondsSinceEpoch,
  );
}

String formatDelay(Duration d) {
  if (d.inMinutes < 60) return '${max(1, d.inMinutes)} 分';
  if (d.inHours < 24) return '${d.inHours} 小時';
  if (d.inDays < 31) return '${d.inDays} 天';
  return '${(d.inDays / 30).toStringAsFixed(d.inDays < 300 ? 1 : 0)} 個月';
}

/// Merges two progress documents (the shape returned by [ReviewStore.exportProgress]).
/// Cards: the more recently graded copy wins. Study days: union. Counters: the larger value.
Map<String, dynamic> mergeProgress(Map<String, dynamic> a, Map<String, dynamic> b) {
  final cards = <String, dynamic>{...(a['cards'] as Map? ?? const {})};
  (b['cards'] as Map? ?? const {}).forEach((id, card) {
    final mine = cards[id] as Map?;
    if (mine == null) {
      cards[id as String] = card;
      return;
    }
    final tMine = (mine['t'] as num? ?? 0), tTheirs = ((card as Map)['t'] as num? ?? 0);
    if (tTheirs > tMine || (tTheirs == tMine && (card['reps'] as num) > (mine['reps'] as num))) {
      cards[id as String] = card;
    }
  });
  final days = <String>{
    ...((a['days'] as List?) ?? const []).cast<String>(),
    ...((b['days'] as List?) ?? const []).cast<String>(),
  }.toList()
    ..sort();
  final counters = <String, int>{};
  for (final src in [a['counters'], b['counters']]) {
    (src as Map? ?? const {}).forEach((k, v) => counters[k as String] = max(counters[k] ?? 0, (v as num).toInt()));
  }
  return {'v': 1, 'cards': cards, 'days': days, 'counters': counters};
}

/// Review progress and device settings, kept on the device with shared_preferences.
class ReviewStore extends ChangeNotifier {
  ReviewStore(this._prefs) {
    final raw = _prefs.getString(_key);
    if (raw != null) {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      _apply(j);
      _newDay = j['newDay'] as String? ?? '';
      _newToday = j['newToday'] as int? ?? 0;
      // Older saves kept the puzzle count at the top level.
      if (j['puzzles'] is int) counters['puzzles'] = max(counters['puzzles'] ?? 0, j['puzzles'] as int);
    }
  }

  static const _key = 'wordblocks.review.v1';
  static const _reminderKey = 'wordblocks.reminder';
  static const newPerDay = 8;

  final SharedPreferences _prefs;
  final Map<String, CardState> _cards = {};
  final Set<String> _days = {};
  String _newDay = '';
  int _newToday = 0;

  /// Activity counters used by badges: split, ext, puzzles, myth.
  final Map<String, int> counters = {};

  int get puzzlesSolved => counters['puzzles'] ?? 0;

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

  /// Adds one to a counter, or sets it to at least 1 when [once] is true.
  void bump(String counter, {bool once = false}) {
    final v = counters[counter] ?? 0;
    if (once && v >= 1) return;
    counters[counter] = v + 1;
    _save();
  }

  void recordPuzzle() => bump('puzzles');

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

  // ---- sync ----

  /// Progress that follows the user across devices (no device-only settings).
  Map<String, dynamic> exportProgress() => {
        'v': 1,
        'cards': _cards.map((k, v) => MapEntry(k, v.toJson())),
        'days': (_days.toList()..sort()),
        'counters': Map<String, int>.from(counters),
      };

  /// Merges progress from another device. Returns true when anything here changed.
  bool importProgress(Map<String, dynamic> remote) {
    final before = jsonEncode(exportProgress());
    final merged = mergeProgress(exportProgress(), remote);
    if (jsonEncode(merged) == before) return false;
    _apply(merged);
    _save();
    return true;
  }

  void _apply(Map<String, dynamic> j) {
    _cards.clear();
    (j['cards'] as Map<String, dynamic>? ?? const {})
        .forEach((k, v) => _cards[k] = CardState.fromJson(v as Map<String, dynamic>));
    _days
      ..clear()
      ..addAll((j['days'] as List? ?? const []).cast<String>());
    counters.clear();
    (j['counters'] as Map? ?? const {}).forEach((k, v) => counters[k as String] = (v as num).toInt());
  }

  // ---- word level filter (device only, not synced) ----

  /// Show words up to this level: 1 基礎, 2 進階 (default), 3 all.
  int get maxLevel => _prefs.getInt('wordblocks.level') ?? 2;

  Future<void> setMaxLevel(int level) async {
    await _prefs.setInt('wordblocks.level', level.clamp(1, 3));
    notifyListeners();
  }

  // ---- daily reminder (device only, not synced) ----

  bool get reminderOn => _prefs.getBool('$_reminderKey.on') ?? false;

  /// Minutes after midnight; default 20:30.
  int get reminderMinute => _prefs.getInt('$_reminderKey.minute') ?? 20 * 60 + 30;

  Future<void> setReminder({required bool on, int? minute}) async {
    await _prefs.setBool('$_reminderKey.on', on);
    if (minute != null) await _prefs.setInt('$_reminderKey.minute', minute);
    notifyListeners();
  }

  void _save() {
    _prefs.setString(
      _key,
      jsonEncode({...exportProgress(), 'newDay': _newDay, 'newToday': _newToday}),
    );
    notifyListeners();
  }
}
