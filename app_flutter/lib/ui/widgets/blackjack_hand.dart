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

  const BlackjackHandView({
    super.key,
    required this.cards,
    required this.theme,
    this.isActive = false,
    this.result,
    this.cardWidth = 72,
    this.showTotal = true,
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: isActive
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(AppTokens.radiusLg),
              boxShadow: [BoxShadow(color: theme.gold.withValues(alpha: 0.45), blurRadius: 18)],
              color: theme.gold.withValues(alpha: 0.06),
            )
          : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isActive)
            Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: theme.gold,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('Your Turn',
                  style: TextStyle(
                      color: theme.feltDark, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          SizedBox(
            width: stackWidth,
            height: cardHeight,
            child: Stack(
              children: [
                for (var i = 0; i < cards.length; i++)
                  Positioned(
                    left: i * (cardWidth - overlap),
                    child: PlayingCardView(card: cards[i], theme: theme, width: cardWidth),
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
          if (result != null) ...[
            const SizedBox(height: 6),
            _ResultBadge(result: result!),
          ],
        ],
      ),
    );
  }
}

class _ResultBadge extends StatelessWidget {
  final HandResult result;
  const _ResultBadge({required this.result});

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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
            color: fg, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5),
      ),
    );
  }
}
