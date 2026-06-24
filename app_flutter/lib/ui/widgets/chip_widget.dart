import 'package:flutter/material.dart';

import '../theme/appearance.dart';

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
    final (inner, outer) = theme.chipColor(amount);
    final isBlack = amount >= 500;
    return Opacity(
      opacity: onTap == null ? 0.35 : 1,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [inner, outer]),
            border: Border.all(
              color: isBlack ? theme.gold : const Color(0x40FFFFFF),
              width: 3,
              style: BorderStyle.solid,
            ),
            boxShadow: const [
              BoxShadow(color: Color(0x80000000), blurRadius: 8, offset: Offset(0, 3)),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            '$amount',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
              shadows: [Shadow(color: Color(0x80000000), blurRadius: 2, offset: Offset(0, 1))],
            ),
          ),
        ),
      ),
    );
  }
}
