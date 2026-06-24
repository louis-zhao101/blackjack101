import 'package:flutter/material.dart';

/// Card-back visual style. Add new patterns here as more skins are introduced.
enum CardBackPattern { diagonalHatch, solid }

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

  // Chips by denomination → (gradient inner, gradient outer).
  final Map<int, (Color, Color)> chipColors;

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
    required this.chipColors,
  });

  Gradient get feltGradient => RadialGradient(
        center: const Alignment(0, -0.2),
        radius: 1.1,
        colors: [feltLight, felt, feltDark],
        stops: const [0.0, 0.5, 1.0],
      );

  /// Chip color pair for a denomination, falling back to the 500 chip.
  (Color, Color) chipColor(int amount) =>
      chipColors[amount] ?? chipColors[500] ?? (cardBlack, feltDark);
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
  chipColors: {
    5: (Color(0xFFE74C3C), Color(0xFFC0392B)),
    25: (Color(0xFF3498DB), Color(0xFF2980B9)),
    100: (Color(0xFF2ECC71), Color(0xFF27AE60)),
    500: (Color(0xFF2C2C2C), Color(0xFF1A1A1A)),
  },
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
  chipColors: {
    5: (Color(0xFFE74C3C), Color(0xFFC0392B)),
    25: (Color(0xFF5DADE2), Color(0xFF2E86C1)),
    100: (Color(0xFF58D68D), Color(0xFF239B56)),
    500: (Color(0xFF2C2C2C), Color(0xFF0E0E0E)),
  },
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
  chipColors: {
    5: (Color(0xFFE74C3C), Color(0xFFC0392B)),
    25: (Color(0xFF3498DB), Color(0xFF2980B9)),
    100: (Color(0xFF2ECC71), Color(0xFF27AE60)),
    500: (Color(0xFF2C2C2C), Color(0xFF1A1A1A)),
  },
);

const List<AppearanceTheme> appearancePresets = [classicGreen, midnightBlue, crimson];

AppearanceTheme appearanceById(String id) =>
    appearancePresets.firstWhere((t) => t.id == id, orElse: () => classicGreen);

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
