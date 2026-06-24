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
    final (inner, outer) = theme.chipColor(amount);
    final isBlack = amount >= 500;
    final edge = isBlack ? theme.gold : const Color(0xF0FFFFFF);
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _ChipPainter(inner: inner, outer: outer, edge: edge),
        child: showLabel
            ? Center(
                child: Text(
                  '$amount',
                  style: TextStyle(
                    color: isBlack ? theme.goldLight : Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: size * 0.26,
                    shadows: const [
                      Shadow(color: Color(0x99000000), blurRadius: 2, offset: Offset(0, 1)),
                    ],
                  ),
                ),
              )
            : null,
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

class _ChipPainter extends CustomPainter {
  final Color inner;
  final Color outer;
  final Color edge;
  _ChipPainter({required this.inner, required this.outer, required this.edge});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    // Chip body with a top-left highlight for a slight 3D feel.
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.3),
          radius: 1.0,
          colors: [Color.lerp(inner, Colors.white, 0.18)!, outer],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );

    // Edge spots — 6 light segments around the rim.
    const n = 6;
    final spotWidth = r * 0.22;
    final spotR = r - spotWidth / 2 - r * 0.04;
    final spotPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = spotWidth
      ..strokeCap = StrokeCap.butt
      ..color = edge;
    final sweep = (2 * pi / n) * 0.5;
    for (var i = 0; i < n; i++) {
      final start = (2 * pi / n) * i - sweep / 2;
      canvas.drawArc(
          Rect.fromCircle(center: c, radius: spotR), start, sweep, false, spotPaint);
    }

    // Thin dark outline for definition.
    canvas.drawCircle(
      c,
      r - 0.75,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = const Color(0x33000000),
    );

    // Center inlay disc + ring (the printed "label" the value sits on).
    final faceR = r * 0.6;
    canvas.drawCircle(
      c,
      faceR,
      Paint()
        ..shader = RadialGradient(
          colors: [Color.lerp(inner, Colors.white, 0.1)!, outer],
        ).createShader(Rect.fromCircle(center: c, radius: faceR)),
    );
    canvas.drawCircle(
      c,
      faceR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.045
        ..color = edge.withValues(alpha: 0.9),
    );
  }

  @override
  bool shouldRepaint(covariant _ChipPainter old) =>
      old.inner != inner || old.outer != outer || old.edge != edge;
}
