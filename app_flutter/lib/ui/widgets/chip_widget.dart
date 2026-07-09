import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/appearance.dart';
import 'game_button.dart';

/// The realistic poker-chip visual (body, edge spots, center inlay). Reused by
/// the betting [ChipWidget] and the corner bet stack.
class PokerChipFace extends StatelessWidget {
  final int amount;
  final AppearanceTheme theme;
  final double size;
  final bool showLabel;

  const PokerChipFace({
    super.key,
    required this.amount,
    required this.theme,
    required this.size,
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    final (inner, _) = theme.chipColor(amount);
    final isBlack = amount >= 500;
    final lightBody = inner.computeLuminance() > 0.55;
    // Gold detailing for dark high-value chips, onyx for pale chips (so the rim
    // and rings read), cream for everything else.
    final accent = isBlack
        ? theme.goldLight
        : (lightBody ? const Color(0xFF3A3A40) : const Color(0xFFF2EAD8));
    final labelColor = isBlack
        ? theme.goldLight
        : (lightBody ? const Color(0xFF2A2A2A) : Colors.white);

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        // The value is painted (not an overlaid centered Text) so it can be
        // centered on the digits' cap height. A Text box centers on the font's
        // ascent+descent, which leaves digits sitting slightly off since they
        // have no descender.
        painter: _ChipPainter(
          body: inner,
          accent: accent,
          label: showLabel ? '$amount' : null,
          labelColor: labelColor,
          labelShadow: lightBody ? const Color(0x33FFFFFF) : const Color(0x99000000),
          labelSize: size * 0.26,
        ),
      ),
    );
  }
}

class ChipWidget extends StatelessWidget {
  final int amount;
  final AppearanceTheme theme;
  final VoidCallback? onTap;
  final double size;

  const ChipWidget({
    super.key,
    required this.amount,
    required this.theme,
    this.onTap,
    this.size = 54,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.35 : 1,
      child: TappableScale(
        onPressed: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: Color(0x80000000), blurRadius: 6, offset: Offset(0, 3)),
            ],
          ),
          child: PokerChipFace(amount: amount, theme: theme, size: size),
        ),
      ),
    );
  }
}

/// A compact sideways fan of the four denomination chips (each showing its
/// value), overlapping left-to-right. Used as the chip-style thumbnail in the
/// shop and customize sheet so the whole set is visible at a glance. [theme]
/// must already have the previewed [ChipStyle] applied.
class ChipStripPreview extends StatelessWidget {
  final AppearanceTheme theme;
  final double size;
  const ChipStripPreview({super.key, required this.theme, this.size = 30});

  static const _denoms = [5, 25, 100, 500];

  /// Horizontal advance per chip — a tight overlap. Each chip's leading edge and
  /// value read; the next chip may cover the trailing digit(s) of wider values.
  double get _step => size * 0.56;

  /// Total footprint, so callers can size the slot that holds the strip.
  double get width => size + (_denoms.length - 1) * _step;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < _denoms.length; i++)
            Positioned(
              left: i * _step,
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: Color(0x55000000), blurRadius: 2.5, offset: Offset(1, 1)),
                  ],
                ),
                child: PokerChipFace(amount: _denoms[i], theme: theme, size: size),
              ),
            ),
        ],
      ),
    );
  }
}

/// Flat, detailed poker-chip: a solid body with a cream notched rim, concentric
/// rings, a ring of dots/diamonds, and a clean center inlay. No glossy gradient.
class _ChipPainter extends CustomPainter {
  final Color body;
  final Color accent;
  final String? label;
  final Color labelColor;
  final Color labelShadow;
  final double labelSize;
  _ChipPainter({
    required this.body,
    required this.accent,
    this.label,
    this.labelColor = const Color(0xFF000000),
    this.labelShadow = const Color(0x99000000),
    this.labelSize = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    final bodyPaint = Paint()..color = body;
    final accentPaint = Paint()..color = accent;

    // Cream base — shows through the notches to form the toothed edge.
    canvas.drawCircle(c, r, accentPaint);

    // Toothed rim: body-colored teeth reaching the edge, cream gaps between.
    const teeth = 16;
    final bodyR = r * 0.87;
    final toothMid = (bodyR + r) / 2;
    final toothPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r - bodyR
      ..strokeCap = StrokeCap.butt
      ..color = body;
    final step = 2 * pi / teeth;
    final toothSweep = step * 0.56;
    for (var i = 0; i < teeth; i++) {
      final start = step * i - toothSweep / 2;
      canvas.drawArc(
          Rect.fromCircle(center: c, radius: toothMid), start, toothSweep, false, toothPaint);
    }

    // Solid body disc.
    canvas.drawCircle(c, bodyR, bodyPaint);

    // Thin cream ring just inside the rim.
    canvas.drawCircle(
      c,
      r * 0.80,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.035
        ..color = accent,
    );

    // Decorative band: alternating dots and diamonds.
    final markR = r * 0.66;
    const marks = 8;
    final mstep = 2 * pi / marks;
    for (var i = 0; i < marks; i++) {
      final a = -pi / 2 + mstep * i;
      final p = c + Offset(cos(a), sin(a)) * markR;
      if (i.isEven) {
        canvas.drawCircle(p, r * 0.024, accentPaint);
      } else {
        _diamond(canvas, p, r * 0.034, accentPaint);
      }
    }

    // Center inlay disc (the printed face the value sits on).
    canvas.drawCircle(c, r * 0.52, bodyPaint);

    // Subtle dark outline for definition against light backgrounds.
    canvas.drawCircle(
      c,
      r - 0.75,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0x22000000),
    );

    // Value, painted last so it sits above the inlay. Centered on the digits'
    // cap height (≈0.70 em) instead of the font's line box, so it reads
    // dead-centered regardless of the platform font's ascent/descent metrics.
    if (label != null) {
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: labelColor,
            fontWeight: FontWeight.bold,
            fontSize: labelSize,
            shadows: [Shadow(color: labelShadow, blurRadius: 2, offset: const Offset(0, 1))],
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout();
      final baseline = tp.computeDistanceToActualBaseline(TextBaseline.alphabetic);
      tp.paint(canvas, Offset(c.dx - tp.width / 2, c.dy - baseline + labelSize * 0.35));
    }
  }

  void _diamond(Canvas canvas, Offset p, double s, Paint paint) {
    final path = Path()
      ..moveTo(p.dx, p.dy - s)
      ..lineTo(p.dx + s, p.dy)
      ..lineTo(p.dx, p.dy + s)
      ..lineTo(p.dx - s, p.dy)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ChipPainter old) =>
      old.body != body ||
      old.accent != accent ||
      old.label != label ||
      old.labelColor != labelColor ||
      old.labelSize != labelSize;
}
