import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../theme/appearance.dart';
import 'chip_widget.dart';

const _denoms = [500, 100, 25, 5];
const _chipSize = 34.0;
const _vOffset = 2.0; // vertical gap between stacked chips
const _maxPerStack = 8; // cap visible discs so a stack can't grow off-screen

double _stackHeight(int count) {
  final shown = count > _maxPerStack ? _maxPerStack : count;
  return _chipSize + (shown - 1) * _vOffset;
}

/// Where the chips travel when a hand settles: toward the player on a win
/// (the bet is paid out) or toward the dealer on a loss (the bet is swept).
enum ChipSettle { toPlayer, toDealer }

/// Visual representation of the current bet as stacks of poker chips, one
/// vertical stack per denomination (chips of the same value offset upward to
/// look physically stacked). When [settle] is set (hand complete) the whole
/// stack slides and fades toward the player or dealer.
class BetChipStack extends StatefulWidget {
  final int amount;
  final AppearanceTheme theme;
  final ChipSettle? settle;
  const BetChipStack({
    super.key,
    required this.amount,
    required this.theme,
    this.settle,
  });

  @override
  State<BetChipStack> createState() => _BetChipStackState();
}

class _BetChipStackState extends State<BetChipStack>
    with TickerProviderStateMixin {
  late final AnimationController _settleCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );
  // Quick pop-in when the chips reappear for a fresh hand (rests at 1 = shown).
  late final AnimationController _appearCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
    value: 1,
  );

  @override
  void initState() {
    super.initState();
    if (widget.settle != null) _settleCtrl.value = 1;
  }

  @override
  void didUpdateWidget(BetChipStack old) {
    super.didUpdateWidget(old);
    if (widget.settle != null && old.settle == null) {
      _settleCtrl.forward(from: 0);
    } else if (widget.settle == null && old.settle != null) {
      _settleCtrl.value = 0;
      _appearCtrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _settleCtrl.dispose();
    _appearCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.amount <= 0) return const SizedBox.shrink();

    final stacks = <({int denom, int count})>[];
    var rem = widget.amount;
    for (final d in _denoms) {
      final c = rem ~/ d;
      if (c > 0) {
        stacks.add((denom: d, count: c));
        rem -= c * d;
      }
    }

    // Lay the denomination stacks out in a 2-column grid (growing up/left from
    // the bottom-right corner) rather than one long row, so the bet doesn't run
    // under the cards. Each stack is positioned by denomination-keyed
    // AnimatedPositioned so that when a stack appears/disappears the others
    // slide to their new cells instead of snapping.
    const gap = 6.0;
    const colW = _chipSize + gap;
    const vGap = 10.0;

    var maxH = _chipSize;
    for (final s in stacks) {
      final h = _stackHeight(s.count);
      if (h > maxH) maxH = h;
    }
    final pitch = maxH + vGap;
    final cols = stacks.length >= 2 ? 2 : 1;
    final rows = (stacks.length + 1) ~/ 2;

    final grid = SizedBox(
      width: cols * _chipSize + (cols - 1) * gap,
      height: (rows - 1) * pitch + maxH,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < stacks.length; i++)
            AnimatedPositioned(
              key: ValueKey(stacks[i].denom),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              right: cols == 1 ? 0 : (1 - (i % 2)) * colW,
              bottom: (i ~/ 2) * pitch,
              child: _DenomStack(
                denom: stacks[i].denom,
                count: stacks[i].count,
                theme: widget.theme,
              ),
            ),
        ],
      ),
    );

    return AnimatedBuilder(
      animation: Listenable.merge([_settleCtrl, _appearCtrl]),
      child: grid,
      builder: (context, child) {
        final t = Curves.easeIn.transform(_settleCtrl.value);
        // +y travels down toward the player, -y up toward the dealer.
        final dy = switch (widget.settle) {
          ChipSettle.toPlayer => 120.0 * t,
          ChipSettle.toDealer => -150.0 * t,
          null => 0.0,
        };
        final a = Curves.easeOut.transform(_appearCtrl.value);
        return Opacity(
          opacity: ((1 - t * 1.6) * a).clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, dy),
            child: Transform.scale(
              scale: 0.6 + 0.4 * a,
              alignment: Alignment.bottomRight,
              child: child,
            ),
          ),
        );
      },
    );
  }
}

class _DenomStack extends StatefulWidget {
  final int denom;
  final int count;
  final AppearanceTheme theme;
  const _DenomStack({required this.denom, required this.count, required this.theme});

  @override
  State<_DenomStack> createState() => _DenomStackState();
}

class _DenomStackState extends State<_DenomStack>
    with SingleTickerProviderStateMixin {
  // Playful riffle of the top chip when this stack is tapped.
  late final AnimationController _wiggleCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );

  void _riffle() {
    HapticFeedback.lightImpact();
    _wiggleCtrl.forward(from: 0);
  }

  @override
  void dispose() {
    _wiggleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shown = widget.count > _maxPerStack ? _maxPerStack : widget.count;

    return GestureDetector(
      onTap: _riffle,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: _chipSize,
        height: _stackHeight(widget.count),
        child: Stack(
          children: [
            for (var i = 0; i < shown; i++)
              Positioned(
                key: ValueKey(i),
                bottom: i * _vOffset,
                child: _chip(i, shown),
              ),
          ],
        ),
      ),
    );
  }

  Widget _chip(int i, int shown) {
    final isTop = i == shown - 1;
    // Only the top chip shows its value; lower ones peek as edges.
    Widget chip = TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, (1 - t) * -18),
          child: child,
        ),
      ),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: Color(0x55000000), blurRadius: 3, offset: Offset(0, 2)),
          ],
        ),
        child: PokerChipFace(
          amount: widget.denom,
          theme: widget.theme,
          size: _chipSize,
          showLabel: isTop,
        ),
      ),
    );

    if (!isTop) return chip;

    // Top chip rocks and lifts with a decaying oscillation when tapped.
    return AnimatedBuilder(
      animation: _wiggleCtrl,
      child: chip,
      builder: (context, child) {
        final w = _wiggleCtrl.value;
        final decay = 1 - w;
        final angle = math.sin(w * math.pi * 5) * 0.18 * decay;
        final lift = math.sin(w * math.pi) * -3.0;
        return Transform.translate(
          offset: Offset(0, lift),
          child: Transform.rotate(
            angle: angle,
            alignment: Alignment.bottomCenter,
            child: child,
          ),
        );
      },
    );
  }
}
