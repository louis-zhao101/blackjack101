import 'package:flutter/material.dart';

import '../theme/appearance.dart';

const _denoms = [500, 100, 25, 5];
const _chipSize = 34.0;
const _vOffset = 7.0; // vertical gap between stacked chips
const _maxPerStack = 8; // cap visible discs so a stack can't grow off-screen

/// Visual representation of the current bet as stacks of poker chips, one
/// vertical stack per denomination (chips of the same value offset upward to
/// look physically stacked).
class BetChipStack extends StatelessWidget {
  final int amount;
  final AppearanceTheme theme;
  const BetChipStack({super.key, required this.amount, required this.theme});

  @override
  Widget build(BuildContext context) {
    if (amount <= 0) return const SizedBox.shrink();

    final stacks = <({int denom, int count})>[];
    var rem = amount;
    for (final d in _denoms) {
      final c = rem ~/ d;
      if (c > 0) {
        stacks.add((denom: d, count: c));
        rem -= c * d;
      }
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final s in stacks)
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: _DenomStack(denom: s.denom, count: s.count, theme: theme),
          ),
      ],
    );
  }
}

class _DenomStack extends StatelessWidget {
  final int denom;
  final int count;
  final AppearanceTheme theme;
  const _DenomStack({required this.denom, required this.count, required this.theme});

  @override
  Widget build(BuildContext context) {
    final shown = count > _maxPerStack ? _maxPerStack : count;
    final (inner, outer) = theme.chipColor(denom);
    final isBlack = denom >= 500;

    return SizedBox(
      width: _chipSize,
      height: _chipSize + (shown - 1) * _vOffset,
      child: Stack(
        children: [
          for (var i = 0; i < shown; i++)
            Positioned(
              bottom: i * _vOffset,
              child: _chip(inner, outer, isBlack, isTop: i == shown - 1),
            ),
        ],
      ),
    );
  }

  Widget _chip(Color inner, Color outer, bool isBlack, {required bool isTop}) {
    return Container(
      width: _chipSize,
      height: _chipSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [inner, outer]),
        border: Border.all(color: isBlack ? theme.gold : const Color(0x55FFFFFF), width: 2),
        boxShadow: const [
          BoxShadow(color: Color(0x55000000), blurRadius: 3, offset: Offset(0, 2)),
        ],
      ),
      alignment: Alignment.center,
      // Only the top chip shows its value; lower ones just peek as edges.
      child: isTop
          ? Text(
              '$denom',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                shadows: [Shadow(color: Color(0x99000000), blurRadius: 2)],
              ),
            )
          : null,
    );
  }
}
