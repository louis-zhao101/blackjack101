import 'package:flutter/material.dart';

import '../../engine/cards.dart' as bj;
import '../../engine/engine.dart' show HandResult;
import '../theme/appearance.dart';
import 'playing_card.dart';

class BlackjackHandView extends StatelessWidget {
  final List<bj.Card> cards;
  final AppearanceTheme theme;
  final bool isActive;
  final HandResult? result;
  final double cardWidth;
  final bool showTotal;
  final bool showResult;

  const BlackjackHandView({
    super.key,
    required this.cards,
    required this.theme,
    this.isActive = false,
    this.result,
    this.cardWidth = 72,
    this.showTotal = true,
    this.showResult = true,
  });

  @override
  Widget build(BuildContext context) {
    final overlap = cardWidth * 0.17;
    final cardHeight = cardWidth * (100 / 72);
    final stackWidth =
        cards.isEmpty ? cardWidth : cardWidth + (cards.length - 1) * (cardWidth - overlap);
    final hv = bj.handValue(cards);
    final hasHidden = cards.any((c) => c.faceDown);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isActive)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: theme.gold,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('Your Turn',
                  style: TextStyle(
                      color: theme.feltDark, fontSize: 11, fontWeight: FontWeight.bold)),
            )
          else if (showResult && result != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ResultBadge(result: result!),
            ),
          SizedBox(
            width: stackWidth,
            height: cardHeight,
            child: Stack(
              children: [
                for (var i = 0; i < cards.length; i++)
                  Positioned(
                    key: ValueKey(i),
                    left: i * (cardWidth - overlap),
                    child: _DealtCard(
                      // Stagger the first two cards (the initial deal / split);
                      // later cards (hit, double) animate in immediately.
                      delayMs: i < 2 ? i * 110 : 0,
                      // Replays the entrance when the card at this slot changes
                      // (e.g. Deal Again). Ignores faceDown so revealing the
                      // dealer hole card doesn't re-trigger it.
                      cardId: '${cards[i].rank}${cards[i].suit}',
                      child:
                          PlayingCardView(card: cards[i], theme: theme, width: cardWidth),
                    ),
                  ),
              ],
            ),
          ),
          if (showTotal && cards.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              hasHidden ? '${hv.total}' : (hv.soft && hv.total != 21 ? 'Soft ${hv.total}' : '${hv.total}'),
              style: const TextStyle(
                  color: AppTokens.textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ],
        ],
      ),
    );
  }
}

/// Plays a one-shot slide-down + fade entrance for a freshly dealt card,
/// after an optional [delayMs] so a batch of cards appears sequentially.
class _DealtCard extends StatefulWidget {
  final Widget child;
  final int delayMs;
  final String cardId;
  const _DealtCard({required this.child, required this.delayMs, required this.cardId});

  @override
  State<_DealtCard> createState() => _DealtCardState();
}

class _DealtCardState extends State<_DealtCard> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 260));

  void _play() {
    if (widget.delayMs <= 0) {
      _c.forward(from: 0);
    } else {
      _c.value = 0;
      Future.delayed(Duration(milliseconds: widget.delayMs), () {
        if (mounted) _c.forward(from: 0);
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _play();
  }

  @override
  void didUpdateWidget(_DealtCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cardId != widget.cardId) _play();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) {
        final t = Curves.easeOutCubic.transform(_c.value);
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(offset: Offset(0, (1 - t) * -26), child: child),
        );
      },
    );
  }
}

class ResultBadge extends StatelessWidget {
  final HandResult result;
  const ResultBadge({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final (label, colors) = switch (result) {
      HandResult.win => ('Win', AppTokens.badgeWin),
      HandResult.blackjack => ('Blackjack', AppTokens.badgeBlackjack),
      HandResult.push => ('Push', AppTokens.badgePush),
      HandResult.lose => ('Lose', AppTokens.badgeLose),
      HandResult.surrender => ('Surrender', AppTokens.badgeSurrender),
    };
    final (bg, fg, border) = colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
            color: fg, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
      ),
    );
  }
}
