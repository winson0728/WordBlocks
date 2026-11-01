import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../data/lexicon.dart';
import '../theme.dart';

/// One building block: a prefix, root or suffix with its short meaning underneath.
class LegoBlock extends StatelessWidget {
  const LegoBlock({super.key, required this.part, this.mini = false, this.onTap, this.used = false});

  final WordPart part;
  final bool mini;
  final bool used;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final m = part.id == null ? null : AppScope.of(context).lexicon.morphemes[part.id];
    final type = m?.type ?? MorphemeType.link;
    final color = morphemeColor(context, type);
    final text = Theme.of(context).textTheme;
    final block = Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          constraints: BoxConstraints(minWidth: mini ? 0 : 64),
          padding: mini ? const EdgeInsets.fromLTRB(9, 6, 9, 5) : const EdgeInsets.fromLTRB(14, 9, 14, 8),
          decoration: BoxDecoration(
            color: tint(context, color),
            border: Border.all(color: color, width: 2),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!mini)
                Text(typeTags[type]!,
                    style: TextStyle(fontSize: 10, letterSpacing: 1, fontWeight: FontWeight.w600, color: color)),
              Text(part.text,
                  style: TextStyle(
                      fontFamily: latin, fontWeight: FontWeight.w700, fontSize: mini ? 17 : 24, color: color, height: 1.2)),
              Text(m?.shortMeaning ?? '連接字母', style: text.bodySmall),
            ],
          ),
        ),
        Positioned(
          top: mini ? -5 : -7,
          left: 10,
          right: 10,
          height: mini ? 5 : 7,
          child: CustomPaint(painter: _StudsPainter(color, mini ? 14 : 20)),
        ),
      ],
    );
    return Semantics(
      button: onTap != null,
      label: '${typeNames[type]} ${part.text}，${m?.meaning ?? '連接字母'}',
      excludeSemantics: true,
      child: Opacity(
        opacity: used ? .25 : 1,
        child: Padding(
          padding: EdgeInsets.only(top: mini ? 5 : 7),
          child: InkWell(onTap: used ? null : onTap, borderRadius: BorderRadius.circular(6), child: block),
        ),
      ),
    );
  }
}

class _StudsPainter extends CustomPainter {
  _StudsPainter(this.color, this.pitch);
  final Color color;
  final double pitch;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final n = (size.width / pitch).floor().clamp(1, 20);
    final start = (size.width - (n - 1) * pitch) / 2;
    for (var i = 0; i < n; i++) {
      canvas.drawCircle(Offset(start + i * pitch, size.height), size.height * .8, paint);
    }
  }

  @override
  bool shouldRepaint(_StudsPainter old) => old.color != color || old.pitch != pitch;
}

/// A word's blocks. They start pressed together and slide apart, which is the app's signature motion.
class LegoRow extends StatelessWidget {
  const LegoRow({super.key, required this.parts, this.mini = false, this.onTapPart});

  final List<WordPart> parts;
  final bool mini;
  final void Function(WordPart part)? onTapPart;

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.of(context).disableAnimations;
    final gap = mini ? 6.0 : 10.0;
    return TweenAnimationBuilder<double>(
      key: ValueKey(parts.map((p) => p.text).join()),
      tween: Tween(begin: still ? gap : 0, end: gap),
      duration: const Duration(milliseconds: 550),
      curve: Curves.easeOutBack,
      builder: (context, g, _) => Wrap(
        spacing: g.clamp(0, 20),
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.end,
        children: [
          for (final p in parts)
            LegoBlock(part: p, mini: mini, onTap: onTapPart == null || p.id == null ? null : () => onTapPart!(p)),
        ],
      ),
    );
  }
}

/// The word with each part in its block colour.
class ColoredWord extends StatelessWidget {
  const ColoredWord({super.key, required this.word, this.size = 18, this.highlight});

  final Word word;
  final double size;
  final String? highlight;

  @override
  Widget build(BuildContext context) {
    final lex = AppScope.of(context).lexicon;
    return Text.rich(
      TextSpan(children: [
        for (final p in word.parts)
          TextSpan(
            text: p.text,
            style: TextStyle(
              color: morphemeColor(context, lex.morphemes[p.id]?.type ?? MorphemeType.link),
              decoration: p.id == highlight ? TextDecoration.underline : null,
              decorationThickness: 2,
            ),
          ),
      ]),
      style: TextStyle(fontFamily: latin, fontWeight: FontWeight.w700, fontSize: size),
    );
  }
}

class TypeChip extends StatelessWidget {
  const TypeChip(this.type, {super.key});
  final MorphemeType type;

  @override
  Widget build(BuildContext context) {
    final c = morphemeColor(context, type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: tint(context, c, .16), borderRadius: BorderRadius.circular(5)),
      child: Text(typeNames[type]!, style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }
}
