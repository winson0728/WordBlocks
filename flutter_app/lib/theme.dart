import 'package:flutter/material.dart';

import 'data/lexicon.dart';

/// Same palette as the web app: blue prefixes, orange roots, violet suffixes.
const _light = {
  MorphemeType.pre: Color(0xFF2A68C9),
  MorphemeType.root: Color(0xFFBF5A14),
  MorphemeType.suf: Color(0xFF7647C9),
  MorphemeType.link: Color(0xFF7D8B88),
};
const _dark = {
  MorphemeType.pre: Color(0xFF7BA9F6),
  MorphemeType.root: Color(0xFFF29A56),
  MorphemeType.suf: Color(0xFFB597F6),
  MorphemeType.link: Color(0xFF7F8E8A),
};

const accent = Color(0xFF0D6A61);

Color morphemeColor(BuildContext context, MorphemeType type) =>
    (Theme.of(context).brightness == Brightness.dark ? _dark : _light)[type]!;

/// A light wash of [color] over the current surface, for block and chip backgrounds.
Color tint(BuildContext context, Color color, [double amount = .13]) =>
    Color.alphaBlend(color.withValues(alpha: amount), Theme.of(context).colorScheme.surface);

/// Serif face for English words, so they stand apart from Chinese text.
const latin = 'serif';

ThemeData buildTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(seedColor: accent, brightness: brightness);
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor: brightness == Brightness.light ? const Color(0xFFEDF1F0) : const Color(0xFF0F1514),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
  );
}
