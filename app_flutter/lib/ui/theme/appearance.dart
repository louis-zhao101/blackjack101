import 'package:flutter/material.dart';

/// Card-back visual style. Add new patterns here as more skins are introduced.
enum CardBackPattern { diagonalHatch, solid, grid, dots }

/// All user-customizable table visuals live here. Swapping skins (table felt,
/// card back, chips, accents) later is just selecting a different
/// [AppearanceTheme] — no widget changes. See [appearancePresets].
@immutable
class AppearanceTheme {
  final String id;
  final String name;

  // Table felt — radial gradient from center outward.
  final Color feltLight;
  final Color felt;
  final Color feltDark;
  final Color feltBorder;

  // Gold accents.
  final Color gold;
  final Color goldLight;
  final Color goldDark;

  // Card faces.
  final Color cardFace;
  final Color cardRed;
  final Color cardBlack;

  // Card back.
  final Color cardBackColor;
  final CardBackPattern cardBackPattern;
  final Color cardBackAccent;
  final String? cardBackAsset;

  // Card-face deck (null = procedural default faces drawn by PlayingCardView).
  final CardDeck? deck;

  const AppearanceTheme({
    required this.id,
    required this.name,
    required this.feltLight,
    required this.felt,
    required this.feltDark,
    required this.feltBorder,
    required this.gold,
    required this.goldLight,
    required this.goldDark,
    required this.cardFace,
    required this.cardRed,
    required this.cardBlack,
    required this.cardBackColor,
    required this.cardBackPattern,
    this.cardBackAccent = const Color(0x14FFFFFF),
    this.cardBackAsset,
    this.deck,
  });

  /// Overlays a [CardBack] and/or card [deck] cosmetic onto this table theme.
  /// Card backs and decks are sold independently of the felt, so the active
  /// look is the selected table theme composed with the chosen cosmetics.
  AppearanceTheme copyWith({CardBack? cardBack, CardDeck? deck}) =>
      AppearanceTheme(
        id: id,
        name: name,
        feltLight: feltLight,
        felt: felt,
        feltDark: feltDark,
        feltBorder: feltBorder,
        gold: gold,
        goldLight: goldLight,
        goldDark: goldDark,
        cardFace: cardFace,
        cardRed: cardRed,
        cardBlack: cardBlack,
        cardBackColor: cardBack?.color ?? cardBackColor,
        cardBackPattern: cardBack?.pattern ?? cardBackPattern,
        cardBackAccent: cardBack?.accent ?? cardBackAccent,
        cardBackAsset: cardBack != null ? cardBack.asset : cardBackAsset,
        deck: deck ?? this.deck,
      );

  Gradient get feltGradient => RadialGradient(
        center: const Alignment(0, -0.2),
        radius: 1.1,
        colors: [feltLight, felt, feltDark],
        stops: const [0.0, 0.5, 1.0],
      );

}

/// Default skin — matches the current blackjack101-web site tokens.
const AppearanceTheme classicGreen = AppearanceTheme(
  id: 'classic-green',
  name: 'Classic Green',
  feltLight: Color(0xFF245F40),
  felt: Color(0xFF1A4731),
  feltDark: Color(0xFF122E20),
  feltBorder: Color(0xFF2D7A53),
  gold: Color(0xFFD4A843),
  goldLight: Color(0xFFF0C84A),
  goldDark: Color(0xFFB8862A),
  cardFace: Color(0xFFFFFEF9),
  cardRed: Color(0xFFC0392B),
  cardBlack: Color(0xFF1A1A1A),
  cardBackColor: Color(0xFF1E40AF),
  cardBackPattern: CardBackPattern.diagonalHatch,
);

const AppearanceTheme midnightBlue = AppearanceTheme(
  id: 'midnight-blue',
  name: 'Midnight Blue',
  feltLight: Color(0xFF1E3A5F),
  felt: Color(0xFF14263F),
  feltDark: Color(0xFF0B1626),
  feltBorder: Color(0xFF2B5C8A),
  gold: Color(0xFFC9A24B),
  goldLight: Color(0xFFE8C766),
  goldDark: Color(0xFF9C7B2E),
  cardFace: Color(0xFFFDFCF7),
  cardRed: Color(0xFFC0392B),
  cardBlack: Color(0xFF1A1A1A),
  cardBackColor: Color(0xFF7C1D1D),
  cardBackPattern: CardBackPattern.diagonalHatch,
);

const AppearanceTheme crimson = AppearanceTheme(
  id: 'crimson',
  name: 'Crimson',
  feltLight: Color(0xFF6E1F22),
  felt: Color(0xFF4A1416),
  feltDark: Color(0xFF2A0B0C),
  feltBorder: Color(0xFF8A2D31),
  gold: Color(0xFFD4A843),
  goldLight: Color(0xFFF0C84A),
  goldDark: Color(0xFFB8862A),
  cardFace: Color(0xFFFFFEF9),
  cardRed: Color(0xFFC0392B),
  cardBlack: Color(0xFF1A1A1A),
  cardBackColor: Color(0xFF14263F),
  cardBackPattern: CardBackPattern.diagonalHatch,
);

const AppearanceTheme obsidian = AppearanceTheme(
  id: 'obsidian',
  name: 'Obsidian',
  feltLight: Color(0xFF2C2C32),
  felt: Color(0xFF1C1C21),
  feltDark: Color(0xFF101013),
  feltBorder: Color(0xFF3D3D45),
  gold: Color(0xFFD4A843),
  goldLight: Color(0xFFF0C84A),
  goldDark: Color(0xFFB8862A),
  cardFace: Color(0xFFFFFEF9),
  cardRed: Color(0xFFC0392B),
  cardBlack: Color(0xFF1A1A1A),
  cardBackColor: Color(0xFF2E2E36),
  cardBackPattern: CardBackPattern.solid,
);

const AppearanceTheme slate = AppearanceTheme(
  id: 'slate',
  name: 'Slate',
  feltLight: Color(0xFF3A4657),
  felt: Color(0xFF28313E),
  feltDark: Color(0xFF171C24),
  feltBorder: Color(0xFF4E5D72),
  gold: Color(0xFFD4A843),
  goldLight: Color(0xFFF0C84A),
  goldDark: Color(0xFFB8862A),
  cardFace: Color(0xFFFFFEF9),
  cardRed: Color(0xFFC0392B),
  cardBlack: Color(0xFF1A1A1A),
  cardBackColor: Color(0xFF2A3340),
  cardBackPattern: CardBackPattern.diagonalHatch,
);

const List<AppearanceTheme> appearancePresets = [
  classicGreen,
  midnightBlue,
  crimson,
  obsidian,
  slate,
];

AppearanceTheme appearanceById(String id) =>
    appearancePresets.firstWhere((t) => t.id == id, orElse: () => classicGreen);

// ---------------------------------------------------------------------------
// Card backs — sold independently of the table felt.
// ---------------------------------------------------------------------------

@immutable
class CardBack {
  final String id;
  final String name;
  final Color color;
  final Color accent;
  final CardBackPattern pattern;

  /// Optional SVG asset path. When set, the face-down card renders this vector
  /// art (cover-fit, clipped to the card) instead of the procedural pattern.
  final String? asset;

  const CardBack({
    required this.id,
    required this.name,
    required this.color,
    required this.pattern,
    this.accent = const Color(0x14FFFFFF),
    this.asset,
  });
}

// Image-based backs. The PNG art is full-bleed with its own pre-rounded
// transparent corners; [color] is the edge tint shown in the corner sliver
// behind the rounded clip while the asset loads.
const CardBack cardBackRoyalBlue = CardBack(
  id: 'back-royal-blue',
  name: 'Royal Blue',
  color: Color(0xFF1C39A8),
  pattern: CardBackPattern.solid,
  asset: 'assets/card_backs/royal_blue.png',
);
const CardBack cardBackCoral = CardBack(
  id: 'back-coral',
  name: 'Coral Club',
  color: Color(0xFFEC6A52),
  pattern: CardBackPattern.solid,
  asset: 'assets/card_backs/coral_club.png',
);
const CardBack cardBackRose = CardBack(
  id: 'back-rose',
  name: 'Rose',
  color: Color(0xFFD98C95),
  pattern: CardBackPattern.solid,
  asset: 'assets/card_backs/rose.png',
);
const CardBack cardBackBlackGold = CardBack(
  id: 'back-black-gold',
  name: 'Black & Gold',
  color: Color(0xFF12100C),
  pattern: CardBackPattern.solid,
  asset: 'assets/card_backs/black_gold.png',
);
const CardBack cardBackEmerald = CardBack(
  id: 'back-emerald',
  name: 'Emerald',
  color: Color(0xFF0F5132),
  pattern: CardBackPattern.solid,
  asset: 'assets/card_backs/emerald.png',
);
const CardBack cardBackSapphire = CardBack(
  id: 'back-sapphire',
  name: 'Sapphire',
  color: Color(0xFF1B2B4A),
  pattern: CardBackPattern.solid,
  asset: 'assets/card_backs/sapphire.png',
);
const CardBack cardBackJade = CardBack(
  id: 'back-jade',
  name: 'Jade',
  color: Color(0xFF14532D),
  pattern: CardBackPattern.solid,
  asset: 'assets/card_backs/jade.png',
);
const CardBack cardBackGarnet = CardBack(
  id: 'back-garnet',
  name: 'Garnet',
  color: Color(0xFF6E1414),
  pattern: CardBackPattern.solid,
  asset: 'assets/card_backs/garnet.png',
);
const CardBack cardBackPlatinum = CardBack(
  id: 'back-platinum',
  name: 'Platinum',
  color: Color(0xFF3A3A40),
  pattern: CardBackPattern.solid,
  asset: 'assets/card_backs/platinum.png',
);

// Backs that pair with the premium face decks.
const CardBack cardBackIlluminated = CardBack(
  id: 'back-illuminated',
  name: 'Illuminated',
  color: Color(0xFF16203F),
  pattern: CardBackPattern.solid,
  asset: 'assets/card_backs/illuminated_back.png',
);
const CardBack cardBackUkiyoe = CardBack(
  id: 'back-ukiyoe',
  name: 'Ukiyo-e',
  color: Color(0xFF1B2B4A),
  pattern: CardBackPattern.solid,
  asset: 'assets/card_backs/ukiyoe_back.jpg',
);
const CardBack cardBackGreek = CardBack(
  id: 'back-greek',
  name: 'Greek Vase',
  color: Color(0xFF1A1613),
  pattern: CardBackPattern.solid,
  asset: 'assets/card_backs/greek_back.png',
);
const CardBack cardBackEgyptian = CardBack(
  id: 'back-egyptian',
  name: 'Egyptian',
  color: Color(0xFFB83E14),
  pattern: CardBackPattern.solid,
  asset: 'assets/card_backs/egyptian_back.png',
);
const CardBack cardBackGyotaku = CardBack(
  id: 'back-gyotaku',
  name: 'Gyotaku',
  color: Color(0xFFE8DEC5),
  pattern: CardBackPattern.solid,
  asset: 'assets/card_backs/gyotaku_back.png',
);
const CardBack cardBackTarot = CardBack(
  id: 'back-tarot',
  name: 'Tarot',
  color: Color(0xFF0A2233),
  pattern: CardBackPattern.solid,
  asset: 'assets/card_backs/tarot_back.png',
);
const CardBack cardBackAudubon = CardBack(
  id: 'back-audubon',
  name: 'Audubon',
  color: Color(0xFF743716),
  pattern: CardBackPattern.solid,
  asset: 'assets/card_backs/audubon_back.png',
);
const List<CardBack> cardBackPresets = [
  cardBackRoyalBlue,
  cardBackCoral,
  cardBackRose,
  cardBackBlackGold,
  cardBackEmerald,
  cardBackSapphire,
  cardBackJade,
  cardBackGarnet,
  cardBackPlatinum,
  cardBackIlluminated,
  cardBackUkiyoe,
  cardBackGreek,
  cardBackEgyptian,
  cardBackGyotaku,
  cardBackTarot,
  cardBackAudubon,
];

const String kFreeCardBackId = 'back-royal-blue';

CardBack cardBackById(String id) =>
    cardBackPresets.firstWhere((b) => b.id == id, orElse: () => cardBackRoyalBlue);

// ---------------------------------------------------------------------------
// Card-face decks — the full 52-card face art, sold as one premium item. The
// default deck draws faces procedurally; a premium deck supplies image assets.
// ---------------------------------------------------------------------------

@immutable
class CardDeck {
  final String id;
  final String name;

  /// Directory of face images named `<suit>_<rank>.jpg`. Null means the faces
  /// are drawn procedurally by [PlayingCardView] (the free Classic deck).
  final String? faceDir;

  const CardDeck({required this.id, required this.name, this.faceDir});

  static const _suitName = {'♥': 'hearts', '♦': 'diamonds', '♠': 'spades', '♣': 'clubs'};

  /// Asset path for a specific card's face, or null to fall back to procedural
  /// drawing (free deck, or an unmapped suit).
  String? faceAsset(String rank, String suit) {
    final dir = faceDir;
    final s = _suitName[suit];
    return (dir == null || s == null) ? null : '$dir/${s}_$rank.jpg';
  }
}

const CardDeck cardDeckClassic = CardDeck(id: 'deck-classic', name: 'Classic');
const CardDeck cardDeckIlluminated = CardDeck(
  id: 'deck-illuminated',
  name: 'Illuminated',
  faceDir: 'assets/card_faces/illuminated',
);
const CardDeck cardDeckUkiyoe = CardDeck(
  id: 'deck-ukiyoe',
  name: 'Ukiyo-e',
  faceDir: 'assets/card_faces/ukiyo-e',
);
const CardDeck cardDeckGreek = CardDeck(
  id: 'deck-greek',
  name: 'Greek Vase',
  faceDir: 'assets/card_faces/greek',
);
const CardDeck cardDeckEgyptian = CardDeck(
  id: 'deck-egyptian',
  name: 'Egyptian',
  faceDir: 'assets/card_faces/egyptian',
);
const CardDeck cardDeckGyotaku = CardDeck(
  id: 'deck-gyotaku',
  name: 'Gyotaku',
  faceDir: 'assets/card_faces/gyotaku',
);
const CardDeck cardDeckTarot = CardDeck(
  id: 'deck-tarot',
  name: 'Tarot',
  faceDir: 'assets/card_faces/tarot',
);
const CardDeck cardDeckAudubon = CardDeck(
  id: 'deck-audubon',
  name: 'Audubon Birds',
  faceDir: 'assets/card_faces/audubon',
);
const List<CardDeck> cardDeckPresets = [
  cardDeckClassic,
  cardDeckIlluminated,
  cardDeckUkiyoe,
  cardDeckGreek,
  cardDeckEgyptian,
  cardDeckGyotaku,
  cardDeckTarot,
  cardDeckAudubon,
];

const String kFreeCardDeckId = 'deck-classic';

CardDeck cardDeckById(String id) =>
    cardDeckPresets.firstWhere((d) => d.id == id, orElse: () => cardDeckClassic);

/// Builds a [ThemeData] from the active skin so Material surfaces — dialogs,
/// popup menus, buttons, text fields — all match the table. Rebuilt whenever
/// the skin changes.
ThemeData appThemeData(AppearanceTheme a) {
  final scheme = ColorScheme.fromSeed(
    seedColor: a.felt,
    brightness: Brightness.dark,
  ).copyWith(
    primary: a.gold,
    onPrimary: a.feltDark,
    secondary: a.goldLight,
    surface: a.feltDark,
    onSurface: AppTokens.textPrimary,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: a.feltDark,
    dividerColor: const Color(0x22FFFFFF),
    dialogTheme: DialogThemeData(
      backgroundColor: a.felt,
      surfaceTintColor: Colors.transparent,
      elevation: 12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        side: BorderSide(color: a.feltBorder),
      ),
      titleTextStyle:
          TextStyle(color: a.goldLight, fontSize: 18, fontWeight: FontWeight.bold),
      contentTextStyle:
          const TextStyle(color: AppTokens.textPrimary, fontSize: 14, height: 1.45),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: a.felt,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTokens.radius),
        side: BorderSide(color: a.feltBorder),
      ),
      textStyle: const TextStyle(color: AppTokens.textPrimary, fontSize: 14),
    ),
    textButtonTheme:
        TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: a.gold)),
    filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
            backgroundColor: a.gold, foregroundColor: a.feltDark)),
    outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
            foregroundColor: AppTokens.textPrimary,
            side: BorderSide(color: a.feltBorder, width: 1.5))),
    inputDecorationTheme: InputDecorationTheme(
      labelStyle: const TextStyle(color: AppTokens.textSecondary),
      hintStyle: TextStyle(color: AppTokens.textSecondary.withValues(alpha: 0.6)),
      prefixStyle: const TextStyle(color: AppTokens.textPrimary),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTokens.radius),
        borderSide: BorderSide(color: a.feltBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTokens.radius),
        borderSide: BorderSide(color: a.gold, width: 2),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: a.feltDark,
      selectedColor: a.gold.withValues(alpha: 0.22),
      side: BorderSide(color: a.feltBorder),
      labelStyle: const TextStyle(color: AppTokens.textPrimary),
      secondaryLabelStyle: TextStyle(color: a.goldLight),
    ),
  );
}

/// Fixed (non-skinned) design tokens shared across themes.
class AppTokens {
  static const textPrimary = Color(0xFFF5F0E8);
  static const textSecondary = Color(0xFFB0A890);
  static const radius = 8.0;
  static const radiusLg = 12.0;
  static const radiusCard = 6.0;

  static const badgeWin = (Color(0x4027AE60), Color(0xFF6EE7B7), Color(0xFF27AE60));
  static const badgeBlackjack = (Color(0x4DD4A843), Color(0xFFF0C84A), Color(0xFFD4A843));
  static const badgePush = (Color(0x4D64748B), Color(0xFF94A3B8), Color(0xFF64748B));
  static const badgeLose = (Color(0x40C0392B), Color(0xFFFC8181), Color(0xFFC0392B));
  static const badgeSurrender = (Color(0x407C3AED), Color(0xFFC4B5FD), Color(0xFF7C3AED));
}
