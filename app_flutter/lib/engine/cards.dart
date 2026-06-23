import 'dart:math';

/// Ranks: '2'..'10', 'J', 'Q', 'K', 'A'. Kept as strings to mirror the
/// original TypeScript engine and to feed the strategy lookup tables directly.
const List<String> ranks = ['2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K', 'A'];
const List<String> suits = ['♠', '♥', '♦', '♣'];

class Card {
  final String rank;
  final String suit;
  final bool faceDown;

  const Card({required this.rank, required this.suit, this.faceDown = false});

  Card copyWith({String? rank, String? suit, bool? faceDown}) => Card(
        rank: rank ?? this.rank,
        suit: suit ?? this.suit,
        faceDown: faceDown ?? this.faceDown,
      );

  @override
  String toString() => '$rank$suit${faceDown ? '(down)' : ''}';
}

class HandValue {
  final int total;
  final bool soft;
  const HandValue(this.total, this.soft);
}

int rankValue(String rank) {
  if (rank == 'A') return 11;
  if (rank == 'J' || rank == 'Q' || rank == 'K') return 10;
  return int.parse(rank);
}

HandValue handValue(List<Card> cards) {
  final visible = cards.where((c) => !c.faceDown);
  int total = 0;
  int aces = 0;

  for (final card in visible) {
    if (card.rank == 'A') {
      aces++;
      total += 11;
    } else {
      total += rankValue(card.rank);
    }
  }

  while (total > 21 && aces > 0) {
    total -= 10;
    aces--;
  }

  return HandValue(total, aces > 0 && total <= 21);
}

bool isBust(List<Card> cards) => handValue(cards).total > 21;

bool isBlackjack(List<Card> cards) {
  if (cards.length != 2) return false;
  return handValue(cards).total == 21;
}

List<Card> createDeck(int numDecks) {
  final deck = <Card>[];
  for (var d = 0; d < numDecks; d++) {
    for (final suit in suits) {
      for (final rank in ranks) {
        deck.add(Card(rank: rank, suit: suit, faceDown: false));
      }
    }
  }
  return deck;
}

List<Card> shuffle(List<Card> deck, [Random? rng]) {
  final r = rng ?? Random();
  final d = List<Card>.from(deck);
  for (var i = d.length - 1; i > 0; i--) {
    final j = r.nextInt(i + 1);
    final tmp = d[i];
    d[i] = d[j];
    d[j] = tmp;
  }
  return d;
}

class DealResult {
  final Card card;
  final List<Card> remaining;
  const DealResult(this.card, this.remaining);
}

DealResult dealCard(List<Card> deck, [bool faceDown = false]) {
  if (deck.isEmpty) throw StateError('Deck is empty');
  final card = deck[0].copyWith(faceDown: faceDown);
  return DealResult(card, deck.sublist(1));
}
