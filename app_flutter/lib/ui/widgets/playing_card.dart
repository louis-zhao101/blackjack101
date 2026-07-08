import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../engine/cards.dart' as bj;
import '../theme/appearance.dart';

class PlayingCardView extends StatelessWidget {
  final bj.Card card;
  final AppearanceTheme theme;
  final double width;
  final bool showShadow;

  const PlayingCardView({
    super.key,
    required this.card,
    required this.theme,
    this.width = 72,
    this.showShadow = true,
  });

  double get _height => width * (100 / 72);

  bool get _isRed => card.suit == '♥' || card.suit == '♦';

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppTokens.radiusCard);
    if (card.faceDown) {
      final asset = theme.cardBackAsset;
      // Image backs carry their own art (border + pre-rounded transparent
      // corners), so we clip the image to a proportional radius and paint
      // nothing behind it — the corners reveal the felt, not a fill color.
      if (asset != null) {
        final cardRadius = BorderRadius.circular(width * 0.06);
        return Container(
          width: width,
          height: _height,
          decoration: BoxDecoration(borderRadius: cardRadius, boxShadow: showShadow ? _shadow : null),
          child: ClipRRect(
            borderRadius: cardRadius,
            child: asset.endsWith('.svg')
                ? SvgPicture.asset(asset, fit: BoxFit.cover, width: width, height: _height)
                : Image.asset(asset, fit: BoxFit.cover, width: width, height: _height),
          ),
        );
      }
      return Container(
        width: width,
        height: _height,
        decoration: BoxDecoration(
          color: theme.cardBackColor,
          borderRadius: radius,
          boxShadow: showShadow ? _shadow : null,
          border: Border.all(color: const Color(0x33000000)),
        ),
        clipBehavior: Clip.antiAlias,
        child: theme.cardBackPattern == CardBackPattern.solid
            ? null
            : CustomPaint(
                painter: _CardBackPainter(theme.cardBackPattern, theme.cardBackAccent)),
      );
    }

    final color = _isRed ? theme.cardRed : theme.cardBlack;
    final rankFont = width * 0.19;
    final suitFont = width * 0.15;
    final centerFont = width * 0.40;

    Widget proceduralFace() => Container(
          width: width,
          height: _height,
          decoration: BoxDecoration(
            color: theme.cardFace,
            borderRadius: radius,
            boxShadow: showShadow ? _shadow : null,
            border: Border.all(color: const Color(0xFFCCCCCC)),
          ),
          child: Stack(
            children: [
              Positioned(
                top: 4,
                left: 5,
                child: _corner(color, rankFont, suitFont),
              ),
              Positioned(
                bottom: 4,
                right: 5,
                child: Transform.rotate(
                  angle: 3.14159,
                  child: _corner(color, rankFont, suitFont),
                ),
              ),
              Center(
                child:
                    Text(card.suit, style: TextStyle(fontSize: centerFont, color: color, height: 1)),
              ),
            ],
          ),
        );

    // A premium deck supplies full face art; the free deck draws faces above.
    // The art already carries its own border/index/pips, so we just clip it to a
    // proportional radius. Any missing asset falls back to the procedural face.
    final faceAsset = theme.deck?.faceAsset(card.rank, card.suit);
    if (faceAsset != null) {
      final cardRadius = BorderRadius.circular(width * 0.06);
      return Container(
        width: width,
        height: _height,
        decoration: BoxDecoration(
          borderRadius: cardRadius,
          boxShadow: showShadow ? _shadow : null,
        ),
        child: ClipRRect(
          borderRadius: cardRadius,
          child: Image.asset(
            faceAsset,
            fit: BoxFit.cover,
            width: width,
            height: _height,
            errorBuilder: (_, _, _) => proceduralFace(),
          ),
        ),
      );
    }
    return proceduralFace();
  }

  Widget _corner(Color color, double rankFont, double suitFont) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(card.rank,
              style: TextStyle(
                  fontSize: rankFont, fontWeight: FontWeight.bold, color: color, height: 1)),
          Text(card.suit, style: TextStyle(fontSize: suitFont, color: color, height: 1)),
        ],
      );

  static const _shadow = [
    BoxShadow(color: Color(0x66000000), blurRadius: 8, offset: Offset(0, 2)),
    BoxShadow(color: Color(0x40000000), blurRadius: 2, offset: Offset(0, 1)),
  ];
}

class _CardBackPainter extends CustomPainter {
  final CardBackPattern pattern;
  final Color accent;
  _CardBackPainter(this.pattern, this.accent);

  @override
  void paint(Canvas canvas, Size size) {
    switch (pattern) {
      case CardBackPattern.solid:
        return;
      case CardBackPattern.diagonalHatch:
        _hatch(canvas, size, both: true);
      case CardBackPattern.grid:
        _grid(canvas, size);
      case CardBackPattern.dots:
        _dots(canvas, size);
    }
  }

  void _hatch(Canvas canvas, Size size, {required bool both}) {
    final paint = Paint()
      ..color = accent
      ..strokeWidth = 2;
    const step = 8.0;
    for (double d = -size.height; d < size.width; d += step) {
      canvas.drawLine(Offset(d, 0), Offset(d + size.height, size.height), paint);
      if (both) {
        canvas.drawLine(Offset(d, size.height), Offset(d + size.height, 0), paint);
      }
    }
  }

  void _grid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = accent
      ..strokeWidth = 1.4;
    const step = 7.0;
    for (double x = step; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = step; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  void _dots(Canvas canvas, Size size) {
    final paint = Paint()..color = accent;
    const step = 8.0;
    for (double y = step / 2; y < size.height; y += step) {
      for (double x = step / 2; x < size.width; x += step) {
        canvas.drawCircle(Offset(x, y), 1.4, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CardBackPainter old) =>
      old.pattern != pattern || old.accent != accent;
}
