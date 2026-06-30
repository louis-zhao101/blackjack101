import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/cards.dart' as bj;
import '../../state/appearance_provider.dart';
import '../../state/store_provider.dart';
import '../theme/appearance.dart';
import '../widgets/chip_widget.dart';
import '../widgets/playing_card.dart';

/// Opens the Pro upsell (lifetime unlock + feature list) — for feature gates.
Future<void> openGoPro(BuildContext context) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(fullscreenDialog: true, builder: (_) => const GoProScreen()),
  );
}

/// Opens the cosmetics shop (themes à la carte) — for cosmetic gates.
Future<void> openShop(BuildContext context) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(fullscreenDialog: true, builder: (_) => const ShopScreen()),
  );
}

/// What Pro unlocks across the app — shown as a checklist on the Go Pro page.
const List<(IconData, String, String)> _proFeatures = [
  (Icons.palette_outlined, 'All table themes', 'Every design — current and future'),
  (Icons.history, 'Unlimited stats history', 'Keep every session, not just the last few'),
  (Icons.show_chart, 'Accuracy trends', 'See how you improve over time'),
  (Icons.lightbulb_outline, 'Mistake explanations', 'The "why" behind every wrong play'),
  (Icons.trending_up, 'All difficulty tiers', 'Practice Medium and Challenging hands'),
  (Icons.block_flipped, 'No ads, ever', 'A clean, focused trainer'),
];

PreferredSizeWidget _shopAppBar(AppearanceTheme theme, String title) => AppBar(
      backgroundColor: theme.feltDark,
      surfaceTintColor: Colors.transparent,
      foregroundColor: AppTokens.textPrimary,
      elevation: 0,
      title: Text(title, style: TextStyle(color: theme.gold, fontWeight: FontWeight.bold)),
    );

Future<void> _restore(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  await ref.read(entitlementsProvider.notifier).restore();
  messenger.showSnackBar(const SnackBar(content: Text('Purchases restored')));
}

// ---------------------------------------------------------------------------
// Go Pro — the feature upsell
// ---------------------------------------------------------------------------

class GoProScreen extends ConsumerWidget {
  const GoProScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(appearanceProvider);
    final ent = ref.watch(entitlementsProvider);

    return Scaffold(
      backgroundColor: theme.feltDark,
      appBar: _shopAppBar(theme, ent.isPremium ? 'Pro' : 'Go Pro'),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          children: [
            _LifetimeCard(
                theme: theme, product: lifetimeProduct, owned: ent.isPremium, busy: ent.busy),
            const SizedBox(height: 20),
            _ShopSection(
              title: ent.isPremium ? "What's included" : 'Everything in Pro',
              child: Column(
                children: [
                  for (final (icon, title, sub) in _proFeatures)
                    _FeatureRow(theme: theme, icon: icon, title: title, subtitle: sub),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: TextButton(
                onPressed: ent.busy ? null : () => _restore(context, ref),
                child: const Text('Restore purchases'),
              ),
            ),
            const _PolicyNote(),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shop — cosmetics only
// ---------------------------------------------------------------------------

class ShopScreen extends ConsumerStatefulWidget {
  const ShopScreen({super.key});

  @override
  ConsumerState<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends ConsumerState<ShopScreen> {
  int _tab = 0;
  static const _labels = ['Themes', 'Cards', 'Chips'];

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(appearanceProvider);
    final ent = ref.watch(entitlementsProvider);

    return Scaffold(
      backgroundColor: theme.feltDark,
      appBar: _shopAppBar(theme, 'Shop'),
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 48),
              children: [
                _GoProBanner(theme: theme, isPremium: ent.isPremium),
                const SizedBox(height: 18),
                _ShopTabs(
                    labels: _labels, current: _tab, onSelect: (i) => setState(() => _tab = i)),
                const SizedBox(height: 16),
                ..._rowsForTab(theme),
                const SizedBox(height: 8),
                const _PolicyNote(),
              ],
            ),
            Positioned(
              right: 8,
              bottom: 6,
              child: TextButton.icon(
                onPressed: ent.busy ? null : () => _restore(context, ref),
                icon: const Icon(Icons.restore, size: 15),
                label: const Text('Restore'),
                style: TextButton.styleFrom(
                  foregroundColor: theme.gold,
                  backgroundColor: theme.feltDark.withValues(alpha: 0.85),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _rowsForTab(AppearanceTheme theme) {
    switch (_tab) {
      case 0:
        return [
          for (final p in themeProducts)
            _CosmeticRow(
              product: p,
              swatch: _swatch(appearanceById(p.cosmeticId), size: 40),
              isActive: theme.id == p.cosmeticId,
              onUse: () => ref.read(tableThemeProvider.notifier).setPreset(p.cosmeticId),
            ),
        ];
      case 1:
        return [
          for (final p in cardBackProducts)
            _CosmeticRow(
              product: p,
              swatch: _cardBackSwatch(theme, cardBackById(p.cosmeticId)),
              isActive: ref.watch(cardBackProvider).id == p.cosmeticId,
              onUse: () => ref.read(cardBackProvider.notifier).setCardBack(p.cosmeticId),
            ),
        ];
      default:
        return [
          for (final p in chipStyleProducts)
            _CosmeticRow(
              product: p,
              swatch: _chipSwatch(theme, chipStyleById(p.cosmeticId)),
              isActive: ref.watch(chipStyleProvider).id == p.cosmeticId,
              onUse: () => ref.read(chipStyleProvider.notifier).setChipStyle(p.cosmeticId),
            ),
        ];
    }
  }
}

/// Segmented Themes / Cards / Chips selector shared by the shop tabs.
class _ShopTabs extends ConsumerWidget {
  final List<String> labels;
  final int current;
  final ValueChanged<int> onSelect;
  const _ShopTabs({required this.labels, required this.current, required this.onSelect});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(appearanceProvider);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0x14FFFFFF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onSelect(i),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: current == i ? theme.gold : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    labels[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: current == i ? theme.feltDark : AppTokens.textSecondary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PolicyNote extends StatelessWidget {
  const _PolicyNote();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Text(
        'One-time purchases. Cosmetic and training features only — '
        'no ads and no real-money gambling.',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppTokens.textSecondary, fontSize: 11.5, height: 1.4),
      ),
    );
  }
}

Future<void> _buy(BuildContext context, WidgetRef ref, StoreProduct product) async {
  final messenger = ScaffoldMessenger.of(context);
  final result = await ref.read(entitlementsProvider.notifier).purchase(product);
  if (result == PurchaseResult.success) {
    _applyCosmetic(ref, product);
    messenger.showSnackBar(SnackBar(
        content: Text(
            product.isLifetime ? 'Pro unlocked — all themes!' : '${product.name} unlocked')));
  } else if (result == PurchaseResult.error) {
    messenger.showSnackBar(const SnackBar(content: Text('Purchase failed. Please try again.')));
  }
}

/// Selects/equips the cosmetic a product unlocks (no-op for the lifetime pack).
void _applyCosmetic(WidgetRef ref, StoreProduct product) {
  switch (product.kind) {
    case CosmeticKind.lifetime:
      break;
    case CosmeticKind.theme:
      ref.read(tableThemeProvider.notifier).setPreset(product.cosmeticId);
    case CosmeticKind.cardBack:
      ref.read(cardBackProvider.notifier).setCardBack(product.cosmeticId);
    case CosmeticKind.chipStyle:
      ref.read(chipStyleProvider.notifier).setChipStyle(product.cosmeticId);
  }
}

Widget _swatch(AppearanceTheme t, {double size = 40}) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: t.feltGradient,
        shape: BoxShape.circle,
        border: Border.all(color: t.gold, width: 2),
      ),
    );

/// Mini face-down card rendered with [back] over the active felt — shop swatch.
Widget _cardBackSwatch(AppearanceTheme active, CardBack back) => PlayingCardView(
      card: const bj.Card(rank: 'A', suit: '♠', faceDown: true),
      theme: active.copyWith(cardBack: back),
      width: 30,
    );

/// Mini $25 chip rendered with [style] — shop swatch.
Widget _chipSwatch(AppearanceTheme active, ChipStyle style) => PokerChipFace(
      amount: 25,
      theme: active.copyWith(chipStyle: style),
      size: 40,
      showLabel: false,
    );

/// Compact Pro cross-sell shown atop the cosmetics shop.
class _GoProBanner extends StatelessWidget {
  final AppearanceTheme theme;
  final bool isPremium;
  const _GoProBanner({required this.theme, required this.isPremium});

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [theme.gold.withValues(alpha: 0.20), theme.gold.withValues(alpha: 0.05)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.gold.withValues(alpha: 0.55), width: 1.1),
      ),
      child: Row(
        children: [
          Icon(Icons.workspace_premium, color: theme.goldLight, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isPremium ? 'Pro active' : 'Get everything with Pro',
                    style: const TextStyle(
                        color: AppTokens.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(
                    isPremium
                        ? 'All themes unlocked'
                        : 'All themes + every Pro feature',
                    style: const TextStyle(color: AppTokens.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          if (isPremium)
            Icon(Icons.check_circle, color: theme.goldLight, size: 20)
          else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration:
                  BoxDecoration(color: theme.gold, borderRadius: BorderRadius.circular(10)),
              child: Text(lifetimeProduct.priceLabel,
                  style: TextStyle(
                      color: theme.feltDark, fontWeight: FontWeight.bold, fontSize: 13)),
            ),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right, color: AppTokens.textSecondary, size: 20),
          ],
        ],
      ),
    );
    if (isPremium) return content;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => openGoPro(context),
      child: content,
    );
  }
}

class _ShopSection extends StatelessWidget {
  final String title;
  final Widget child;
  const _ShopSection({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      decoration: BoxDecoration(
        color: const Color(0x14FFFFFF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 4),
            child: Text(title,
                style: const TextStyle(
                    color: AppTokens.textPrimary, fontSize: 15, fontWeight: FontWeight.bold)),
          ),
          child,
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final AppearanceTheme theme;
  final IconData icon;
  final String title;
  final String subtitle;
  const _FeatureRow(
      {required this.theme, required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle, color: theme.goldLight, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: AppTokens.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(color: AppTokens.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(icon, color: AppTokens.textSecondary, size: 18),
        ],
      ),
    );
  }
}

class _LifetimeCard extends ConsumerWidget {
  final AppearanceTheme theme;
  final StoreProduct product;
  final bool owned;
  final bool busy;
  const _LifetimeCard(
      {required this.theme, required this.product, required this.owned, required this.busy});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final individualTotal = (themeProducts.length * 1.99).toStringAsFixed(2);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [theme.gold.withValues(alpha: 0.22), theme.gold.withValues(alpha: 0.05)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.gold.withValues(alpha: 0.6), width: 1.3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.workspace_premium, color: theme.goldLight, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(product.name,
                    style: const TextStyle(
                        color: AppTokens.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.bold)),
              ),
              if (!owned)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration:
                      BoxDecoration(color: theme.gold, borderRadius: BorderRadius.circular(8)),
                  child: Text('BEST VALUE',
                      style: TextStyle(
                          color: theme.feltDark,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
              'Unlock every theme and Pro feature — current and future — with one purchase.',
              style: TextStyle(color: AppTokens.textSecondary, fontSize: 12.5, height: 1.4)),
          if (!owned) ...[
            const SizedBox(height: 6),
            Text('Buying all ${themeProducts.length} themes separately costs \$$individualTotal.',
                style: TextStyle(
                    color: theme.goldLight, fontSize: 11.5, fontWeight: FontWeight.w600)),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: owned
                ? Container(
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: theme.gold.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: theme.gold),
                    ),
                    child: Text('✓ Pro unlocked',
                        style: TextStyle(color: theme.goldLight, fontWeight: FontWeight.bold)),
                  )
                : FilledButton(
                    onPressed: busy ? null : () => _buy(context, ref, product),
                    child: Text('Go Pro — ${product.priceLabel}'),
                  ),
          ),
        ],
      ),
    );
  }
}

/// One purchasable cosmetic row (theme, card back, or chip style). [isActive]
/// and [onUse] are supplied by the caller so the same row serves all kinds.
class _CosmeticRow extends ConsumerWidget {
  final StoreProduct product;
  final Widget swatch;
  final bool isActive;
  final VoidCallback onUse;
  const _CosmeticRow({
    required this.product,
    required this.swatch,
    required this.isActive,
    required this.onUse,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(appearanceProvider);
    final ent = ref.watch(entitlementsProvider);
    final unlocked = ent.isCosmeticUnlocked(product.cosmeticId);

    // The whole row is tappable: select an owned cosmetic, or buy a locked one.
    final VoidCallback? onTap = unlocked
        ? (isActive ? null : onUse)
        : (ent.busy ? null : () => _buy(context, ref, product));

    Widget trailing;
    if (unlocked) {
      // Radio-style indicator: filled check when in use, empty circle otherwise.
      trailing = AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        transitionBuilder: (child, anim) =>
            ScaleTransition(scale: anim, child: FadeTransition(opacity: anim, child: child)),
        child: Icon(
          isActive ? Icons.check_circle : Icons.circle_outlined,
          key: ValueKey(isActive),
          color: isActive ? active.goldLight : AppTokens.textSecondary,
          size: 24,
        ),
      );
    } else {
      trailing = Container(
        width: 76,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active.gold,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(product.priceLabel,
            style: TextStyle(
                color: active.feltDark, fontWeight: FontWeight.bold, fontSize: 14)),
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isActive ? active.gold.withValues(alpha: 0.10) : const Color(0x14FFFFFF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isActive ? active.gold : const Color(0x18FFFFFF),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            SizedBox(width: 44, child: Center(child: swatch)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(product.name,
                  style: const TextStyle(
                      color: AppTokens.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
            ),
            SizedBox(width: 84, child: Align(alignment: Alignment.centerRight, child: trailing)),
          ],
        ),
      ),
    );
  }
}
