import 'package:flutter/material.dart';

import '../../engine/cards.dart' as bj;
import '../theme/appearance.dart';

class PlayingCardView extends StatelessWidget {
  final bj.Card card;
  final AppearanceTheme theme;
  final double width;

  const PlayingCardView({
    super.key,
    required this.card,
    required this.theme,
    this.width = 72,
  });

  double get _height => width * (100 / 72);

  bool get _isRed => card.suit == '♥' || card.suit == '♦';

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppTokens.radiusCard);
    if (card.faceDown) {
      return Container(
        width: width,
        height: _height,
        decoration: BoxDecoration(
          color: theme.cardBackColor,
          borderRadius: radius,
          boxShadow: _shadow,
          border: Border.all(color: const Color(0x33000000)),
        ),
        clipBehavior: Clip.antiAlias,
        child: card.faceDown && theme.cardBackPattern == CardBackPattern.diagonalHatch
            ? CustomPaint(painter: _HatchPainter())
            : null,
      );
    }

    final color = _isRed ? theme.cardRed : theme.cardBlack;
    final rankFont = width * 0.19;
    final suitFont = width * 0.15;
    final centerFont = width * 0.40;

    return Container(
      width: width,
      height: _height,
      decoration: BoxDecoration(
        color: theme.cardFace,
        borderRadius: radius,
        boxShadow: _shadow,
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
            child: Text(card.suit, style: TextStyle(fontSize: centerFont, color: color, height: 1)),
          ),
        ],
      ),
    );
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

class _HatchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x14FFFFFF)
      ..strokeWidth = 2;
    const step = 8.0;
    for (double d = -size.height; d < size.width; d += step) {
      canvas.drawLine(Offset(d, 0), Offset(d + size.height, size.height), paint);
      canvas.drawLine(
          Offset(d, size.height), Offset(d + size.height, 0), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
