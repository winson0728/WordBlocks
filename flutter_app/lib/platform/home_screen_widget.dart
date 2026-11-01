import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../data/lexicon.dart';

/// Feeds the Android home-screen widget (android/.../TodayRootWidget.kt).
///
/// The widget gets the whole list of daily roots once, and picks today's entry itself with the
/// same day number as [Lexicon.rootOfTheDay], so it changes at midnight even if the app is never
/// opened.
class HomeScreenWidget {
  static const _androidName = 'io.github.winson0728.wordblocks.TodayRootWidget';

  static Future<void> publish(Lexicon lexicon) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    final roots = [
      for (final m in lexicon.dailyRoots)
        {
          'forms': m.forms,
          'meaning': m.meaning,
          'words': lexicon.wordsWith(m.id).take(3).map((w) => w.word).join(' · '),
        },
    ];
    try {
      await HomeWidget.saveWidgetData<String>('roots', jsonEncode(roots));
      await HomeWidget.updateWidget(qualifiedAndroidName: _androidName);
    } catch (e) {
      // No widget host (tests, or a device without widget support): nothing to update.
      debugPrint('Home-screen widget not updated: $e');
    }
  }
}
