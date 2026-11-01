import 'package:flutter/material.dart';

import 'data/lexicon.dart';
import 'data/review_store.dart';
import 'data/splitter.dart';

/// Makes the loaded data available to every screen.
class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.lexicon,
    required this.splitter,
    required this.store,
    required super.child,
  });

  final Lexicon lexicon;
  final Splitter splitter;
  final ReviewStore store;

  static AppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope not found');
    return scope!;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      lexicon != oldWidget.lexicon || store != oldWidget.store;
}
