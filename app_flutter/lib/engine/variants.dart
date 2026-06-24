enum BlackjackPayout { threeToTwo, sixToFive, oneToOne }

String blackjackPayoutId(BlackjackPayout p) {
  switch (p) {
    case BlackjackPayout.threeToTwo:
      return '3:2';
    case BlackjackPayout.sixToFive:
      return '6:5';
    case BlackjackPayout.oneToOne:
      return '1:1';
  }
}

BlackjackPayout blackjackPayoutFromId(String id) {
  switch (id) {
    case '6:5':
      return BlackjackPayout.sixToFive;
    case '1:1':
      return BlackjackPayout.oneToOne;
    default:
      return BlackjackPayout.threeToTwo;
  }
}

enum Surrender { none, late, early }

class RuleSet {
  final String id;
  final String name;
  final int numDecks;
  final bool dealerHitsSoft17;
  final bool doubleAfterSplit;
  final bool resplitAces;
  final Surrender surrender;
  final BlackjackPayout blackjackPays;
  final int maxSplits;

  const RuleSet({
    required this.id,
    required this.name,
    required this.numDecks,
    required this.dealerHitsSoft17,
    required this.doubleAfterSplit,
    required this.resplitAces,
    required this.surrender,
    required this.blackjackPays,
    required this.maxSplits,
  });

  RuleSet copyWith({
    String? id,
    String? name,
    int? numDecks,
    bool? dealerHitsSoft17,
    bool? doubleAfterSplit,
    bool? resplitAces,
    Surrender? surrender,
    BlackjackPayout? blackjackPays,
    int? maxSplits,
  }) =>
      RuleSet(
        id: id ?? this.id,
        name: name ?? this.name,
        numDecks: numDecks ?? this.numDecks,
        dealerHitsSoft17: dealerHitsSoft17 ?? this.dealerHitsSoft17,
        doubleAfterSplit: doubleAfterSplit ?? this.doubleAfterSplit,
        resplitAces: resplitAces ?? this.resplitAces,
        surrender: surrender ?? this.surrender,
        blackjackPays: blackjackPays ?? this.blackjackPays,
        maxSplits: maxSplits ?? this.maxSplits,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'numDecks': numDecks,
        'dealerHitsSoft17': dealerHitsSoft17,
        'doubleAfterSplit': doubleAfterSplit,
        'resplitAces': resplitAces,
        'surrender': surrender.name,
        'blackjackPays': blackjackPayoutId(blackjackPays),
        'maxSplits': maxSplits,
      };

  factory RuleSet.fromJson(Map<String, dynamic> j) => RuleSet(
        id: j['id'] as String,
        name: j['name'] as String,
        numDecks: (j['numDecks'] as num).toInt(),
        dealerHitsSoft17: j['dealerHitsSoft17'] as bool,
        doubleAfterSplit: j['doubleAfterSplit'] as bool,
        resplitAces: j['resplitAces'] as bool,
        // v0→v1 migration: legacy 'late' default becomes 'none'
        surrender: (j['surrender'] as String) == 'late'
            ? Surrender.none
            : Surrender.values.byName(j['surrender'] as String),
        blackjackPays: blackjackPayoutFromId(j['blackjackPays'] as String),
        maxSplits: (j['maxSplits'] as num).toInt(),
      );
}

const RuleSet vegasStrip = RuleSet(
  id: 'vegas-strip',
  name: 'Vegas Strip',
  numDecks: 6,
  dealerHitsSoft17: false,
  doubleAfterSplit: true,
  resplitAces: true,
  surrender: Surrender.none,
  blackjackPays: BlackjackPayout.threeToTwo,
  maxSplits: 3,
);

const RuleSet vegasStripH17 = RuleSet(
  id: 'vegas-strip-h17',
  name: 'Vegas Strip H17',
  numDecks: 6,
  dealerHitsSoft17: true,
  doubleAfterSplit: true,
  resplitAces: true,
  surrender: Surrender.none,
  blackjackPays: BlackjackPayout.threeToTwo,
  maxSplits: 3,
);

const RuleSet atlanticCity = RuleSet(
  id: 'atlantic-city',
  name: 'Atlantic City',
  numDecks: 8,
  dealerHitsSoft17: false,
  doubleAfterSplit: true,
  resplitAces: false,
  surrender: Surrender.late,
  blackjackPays: BlackjackPayout.threeToTwo,
  maxSplits: 3,
);

const RuleSet singleDeck = RuleSet(
  id: 'single-deck',
  name: 'Single Deck',
  numDecks: 1,
  dealerHitsSoft17: true,
  doubleAfterSplit: false,
  resplitAces: false,
  surrender: Surrender.none,
  blackjackPays: BlackjackPayout.sixToFive,
  maxSplits: 1,
);

const List<RuleSet> rulePresets = [vegasStrip, vegasStripH17, atlanticCity, singleDeck];

String ruleSetDescription(RuleSet r) {
  return [
    '${r.numDecks} deck${r.numDecks > 1 ? 's' : ''}',
    r.dealerHitsSoft17 ? 'Dealer hits soft 17' : 'Dealer stands on soft 17',
    r.doubleAfterSplit ? 'Double after split allowed' : 'No double after split',
    if (r.resplitAces) 'Re-split aces allowed',
    if (r.surrender == Surrender.late) 'Late surrender',
    'Blackjack pays ${blackjackPayoutId(r.blackjackPays)}',
  ].join('\n');
}

double blackjackPayoutMultiplier(BlackjackPayout payout) {
  switch (payout) {
    case BlackjackPayout.threeToTwo:
      return 1.5;
    case BlackjackPayout.sixToFive:
      return 1.2;
    case BlackjackPayout.oneToOne:
      return 1.0;
  }
}
