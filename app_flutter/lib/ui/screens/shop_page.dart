import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart' show Offering, Package, PackageType;

import '../../engine/cards.dart' as bj;
import '../../services/purchases_service.dart';
import '../../state/appearance_provider.dart';
import '../../state/auth_provider.dart';
import '../../state/store_provider.dart';
import '../app_shell.dart' show InviteFriendsBanner, cosmeticGrid, CosmeticTile;
import '../auth_screen.dart' show showSignInSheet;
import '../theme/appearance.dart';
import '../widgets/game_button.dart';
import '../widgets/playing_card.dart';

/// Opens the custom Go Pro paywall — a themed selector over the current
/// RevenueCat Offering (Monthly / Yearly / Lifetime). The CustomerInfo listener
/// drives entitlement state, so no manual refresh is needed after a purchase.
/// Real purchases only run on iOS/Android (RevenueCat). The web build is a
/// companion — rather than fake a purchase through the local dev backend, we
/// point people to the mobile app.
bool get _purchasesMobileOnly => kIsWeb;

void _notifyMobileOnly(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
    content: Text('Purchases are available in the Blackjack 101 mobile app.'),
  ));
}

Future<void> openGoPro(BuildContext context) {
  if (_purchasesMobileOnly) {
    _notifyMobileOnly(context);
    return Future<void>.value();
  }
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

/// Training features every plan includes (monthly, annual, and lifetime) —
/// shown as a checklist on the Go Pro page. Cosmetics are NOT here: they're
/// lifetime-only and called out separately.
const List<(IconData, String, String)> _proFeatures = [
  (Icons.school_outlined, 'All lessons & drills', 'The full learn-to-play path plus Test Yourself'),
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
  if (_purchasesMobileOnly) {
    _notifyMobileOnly(context);
    return;
  }
  final messenger = ScaffoldMessenger.of(context);
  await ref.read(entitlementsProvider.notifier).restore();
  messenger.showSnackBar(const SnackBar(content: Text('Purchases restored')));
}

// ---------------------------------------------------------------------------
// Go Pro — the feature upsell
// ---------------------------------------------------------------------------

class GoProScreen extends ConsumerStatefulWidget {
  const GoProScreen({super.key});

  @override
  ConsumerState<GoProScreen> createState() => _GoProScreenState();
}

class _GoProScreenState extends ConsumerState<GoProScreen> {
  Offering? _offering;
  bool _loading = true;
  Package? _selected;
  bool _purchasing = false;

  /// True once the user taps a tile — until then the selection is derived so it
  /// never defaults to a plan the user already owns.
  bool _touched = false;

  @override
  void initState() {
    super.initState();
    _loadOffering();
  }

  Future<void> _loadOffering() async {
    final offering = await PurchasesService.currentOffering();
    if (!mounted) return;
    final packages = offering == null ? const <Package>[] : _ordered(offering);
    setState(() {
      _offering = offering;
      _selected = packages.isEmpty ? null : packages.first;
      _loading = false;
    });
  }

  /// Yearly first (the value anchor), then Monthly, then Lifetime — skipping any
  /// the Offering doesn't include.
  List<Package> _ordered(Offering o) => [
        if (o.annual != null) o.annual!,
        if (o.monthly != null) o.monthly!,
        if (o.lifetime != null) o.lifetime!,
      ];

  Future<void> _subscribe(Package package) async {
    if (_purchasing) return;
    if (!await _ensureSignedIn(context, ref)) return;
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _purchasing = true);
    try {
      final uid = ref.read(authServiceProvider).currentUser?.uid;
      if (uid != null) await PurchasesService.logIn(uid);
      final nowPro = await PurchasesService.purchasePackage(package);
      if (nowPro) {
        await ref.read(proStatusProvider.notifier).refresh();
        if (!mounted) return;
        await _showSuccessDialog(isLifetime: package.packageType == PackageType.lifetime);
        if (mounted) Navigator.of(context).pop();
        return;
      }
    } catch (e) {
      if (!PurchasesService.isCancellation(e)) {
        messenger.showSnackBar(
            const SnackBar(content: Text('Purchase failed. Please try again.')));
      }
    }
    if (mounted) setState(() => _purchasing = false);
  }

  static String _planLabel(Package p) => switch (p.packageType) {
        PackageType.monthly => 'Monthly',
        PackageType.annual => 'Yearly',
        PackageType.lifetime => 'Lifetime',
        _ => p.storeProduct.title,
      };

  /// The plan to preselect: never the one the user already owns. For an existing
  /// subscriber, favor the lifetime upgrade (the only way to get cosmetics).
  Package? _defaultSelection(List<Package> pkgs, String? activeId, bool isPro) {
    final selectable = pkgs.where((p) => p.storeProduct.identifier != activeId).toList();
    if (selectable.isEmpty) return null;
    if (isPro) {
      for (final p in selectable) {
        if (p.packageType == PackageType.lifetime) return p;
      }
    }
    return selectable.first;
  }

  /// The CTA wording, given the selected plan and whether the user is already a
  /// subscriber (upgrading/switching) vs. a first-time buyer.
  String _ctaLabel(Package p, bool isSubscriber) {
    final price = p.storeProduct.priceString;
    if (p.packageType == PackageType.lifetime) {
      return isSubscriber ? 'Upgrade to Lifetime · $price' : 'Unlock Lifetime · $price';
    }
    return isSubscriber ? 'Switch to ${_planLabel(p)} · $price' : 'Subscribe · $price';
  }

  Future<void> _showSuccessDialog({required bool isLifetime}) {
    final theme = ref.read(appearanceProvider);
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.gold.withValues(alpha: 0.14),
                border: Border.all(color: theme.gold, width: 1.5),
              ),
              child: Icon(Icons.workspace_premium, color: theme.goldLight, size: 38),
            ),
            const SizedBox(height: 18),
            Text(isLifetime ? "You're Lifetime!" : "You're Pro!",
                style: TextStyle(
                    color: theme.goldLight, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
                isLifetime
                    ? 'Every Pro feature and cosmetic is unlocked.'
                    : 'Every Pro training feature is unlocked.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTokens.textSecondary, fontSize: 14, height: 1.4)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(dialogCtx).pop(),
                child: const Text('Start playing'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(appearanceProvider);
    final proStatus = ref.watch(proStatusProvider);
    // isPremium == owns lifetime (all cosmetics). isSubscriber == Pro via a
    // subscription only (training, no cosmetics yet).
    final isPremium = ref.watch(entitlementsProvider).isPremium;
    final hasLifetime = proStatus.hasAllAccess;
    final isSubscriber = proStatus.isPro && !hasLifetime;
    final activeId = proStatus.activeProductId;
    final packages = _offering == null ? const <Package>[] : _ordered(_offering!);
    final bottomInset = MediaQuery.of(context).padding.bottom;

    // Never preselect the plan the user already owns.
    final selected = (_touched &&
            _selected != null &&
            _selected!.storeProduct.identifier != activeId)
        ? _selected
        : _defaultSelection(packages, activeId, proStatus.isPro);

    return Scaffold(
      backgroundColor: theme.feltDark,
      appBar: _shopAppBar(theme, proStatus.isPro ? 'Pro' : 'Go Pro'),
      body: SafeArea(
        top: false,
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 40 + bottomInset),
          children: [
            if (hasLifetime)
              _ProActiveCard(theme: theme)
            else ...[
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (packages.isEmpty)
                _PaywallUnavailable(theme: theme)
              else ...[
                for (final p in packages)
                  _PackageTile(
                    theme: theme,
                    package: p,
                    monthlyRef: _offering!.monthly,
                    isCurrent: p.storeProduct.identifier == activeId,
                    selected: p.storeProduct.identifier != activeId &&
                        selected?.identifier == p.identifier,
                    onTap: p.storeProduct.identifier == activeId
                        ? null
                        : () => setState(() {
                              _selected = p;
                              _touched = true;
                            }),
                  ),
                const SizedBox(height: 4),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed:
                        _purchasing || selected == null ? null : () => _subscribe(selected),
                    child: _purchasing
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(selected == null
                            ? 'You have every plan'
                            : _ctaLabel(selected, isSubscriber)),
                  ),
                ),
              ],
            ],
            const SizedBox(height: 20),
            _ShopSection(
              title: isPremium ? "What's included" : 'Everything in Pro',
              child: Column(
                children: [
                  for (final (icon, title, sub) in _proFeatures)
                    _FeatureRow(theme: theme, icon: icon, title: title, subtitle: sub),
                  _FeatureRow(
                    theme: theme,
                    icon: Icons.palette_outlined,
                    title: 'All cosmetics',
                    subtitle: 'Every theme, card back & deck',
                    lifetimeOnly: !isPremium,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Wrap(
                alignment: WrapAlignment.center,
                children: [
                  TextButton(
                    onPressed: _purchasing ? null : withHaptic(() => _restore(context, ref)),
                    child: const Text('Restore purchases'),
                  ),
                  if (!_purchasesMobileOnly && isSubscriber)
                    TextButton(
                      onPressed: withHaptic(PurchasesService.presentCustomerCenter),
                      child: const Text('Manage subscription'),
                    ),
                ],
              ),
            ),
            const _PolicyNote(oneTime: false),
          ],
        ),
      ),
    );
  }
}

/// One selectable subscription tier in the Go Pro paywall. Price and title come
/// live from the RevenueCat [Package]; annual shows a computed savings hint.
class _PackageTile extends StatelessWidget {
  final AppearanceTheme theme;
  final Package package;
  final Package? monthlyRef;
  final bool selected;

  /// The plan the user is already on — shown with a "CURRENT" tag and not
  /// selectable (onTap is null).
  final bool isCurrent;
  final VoidCallback? onTap;
  const _PackageTile({
    required this.theme,
    required this.package,
    required this.monthlyRef,
    required this.selected,
    this.isCurrent = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final type = package.packageType;
    final isAnnual = type == PackageType.annual;
    final title = switch (type) {
      PackageType.monthly => 'Monthly',
      PackageType.annual => 'Yearly',
      PackageType.lifetime => 'Lifetime',
      _ => package.storeProduct.title,
    };
    final sub = switch (type) {
      PackageType.monthly => 'Billed monthly',
      PackageType.annual => _savingsHint() ?? 'Billed yearly',
      PackageType.lifetime => 'One-time — yours forever',
      _ => '',
    };
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap == null ? null : withHaptic(onTap!),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: isCurrent
              ? theme.gold.withValues(alpha: 0.06)
              : (selected ? theme.gold.withValues(alpha: 0.12) : const Color(0x14FFFFFF)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isCurrent
                ? theme.gold.withValues(alpha: 0.5)
                : (selected ? theme.gold : const Color(0x18FFFFFF)),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
                isCurrent
                    ? Icons.check_circle
                    : (selected ? Icons.radio_button_checked : Icons.radio_button_unchecked),
                color: isCurrent || selected ? theme.goldLight : AppTokens.textSecondary,
                size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(title,
                          style: const TextStyle(
                              color: AppTokens.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.bold)),
                      if (isCurrent) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                              color: theme.gold.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(7),
                              border: Border.all(color: theme.gold, width: 1)),
                          child: Text('CURRENT',
                              style: TextStyle(
                                  color: theme.gold,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5)),
                        ),
                      ] else if (isAnnual) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                              color: theme.gold, borderRadius: BorderRadius.circular(7)),
                          child: Text('BEST VALUE',
                              style: TextStyle(
                                  color: theme.feltDark,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(sub, style: const TextStyle(color: AppTokens.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(package.storeProduct.priceString,
                style: TextStyle(
                    color: isCurrent ? AppTokens.textSecondary : theme.goldLight,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  String? _savingsHint() {
    final monthly = monthlyRef;
    if (monthly == null) return null;
    final yearlyIfMonthly = monthly.storeProduct.price * 12;
    final annual = package.storeProduct.price;
    if (yearlyIfMonthly <= 0 || annual >= yearlyIfMonthly) return null;
    final pct = ((1 - annual / yearlyIfMonthly) * 100).round();
    return 'Billed yearly · save $pct%';
  }
}

class _ProActiveCard extends StatelessWidget {
  final AppearanceTheme theme;
  const _ProActiveCard({required this.theme});

  @override
  Widget build(BuildContext context) {
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
      child: Row(
        children: [
          Icon(Icons.workspace_premium, color: theme.goldLight, size: 22),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Lifetime unlocked',
                    style: TextStyle(
                        color: AppTokens.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                SizedBox(height: 2),
                Text('Every Pro feature and cosmetic — yours forever',
                    style: TextStyle(color: AppTokens.textSecondary, fontSize: 12.5)),
              ],
            ),
          ),
          Icon(Icons.check_circle, color: theme.goldLight, size: 22),
        ],
      ),
    );
  }
}

class _PaywallUnavailable extends StatelessWidget {
  final AppearanceTheme theme;
  const _PaywallUnavailable({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0x14FFFFFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.feltBorder),
      ),
      child: const Text(
        'Pro isn’t available to purchase here yet. Open the app on your phone to subscribe.',
        style: TextStyle(color: AppTokens.textSecondary, fontSize: 13, height: 1.4),
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
  int _dir = 1; // +1 moving to a later tab, -1 earlier — drives slide direction.
  static const _labels = ['Themes', 'Cards', 'Decks'];

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(appearanceProvider);
    final ent = ref.watch(entitlementsProvider);
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: theme.feltDark,
      appBar: _shopAppBar(theme, 'Shop'),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Stack(
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 712),
                child: ListView(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 48 + bottomInset),
              children: [
                _GoProBanner(theme: theme, isPremium: ent.isPremium),
                const SizedBox(height: 12),
                const InviteFriendsBanner(),
                _BundlesSection(theme: theme),
                const SizedBox(height: 18),
                AppSegmentedTabs(
                    labels: _labels,
                    current: _tab,
                    onSelect: (i) => setState(() {
                          _dir = i > _tab ? 1 : -1;
                          _tab = i;
                        })),
                const SizedBox(height: 16),
                SlideTabSwitcher(
                  tabIndex: _tab,
                  dir: _dir,
                  child: cosmeticGrid(_rowsForTab(theme)),
                ),
                const SizedBox(height: 8),
                const _PolicyNote(),
              ],
            ),
              ),
            ),
            Positioned(
              right: 8,
              bottom: 6 + bottomInset,
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
    // The free default heads each list so players can always switch back to it.
    switch (_tab) {
      case 0:
        return [
          _CosmeticRow(
            kind: CosmeticKind.theme,
            cosmeticId: classicGreen.id,
            name: classicGreen.name,
            swatch: _swatch(classicGreen, size: 40),
            isActive: theme.id == classicGreen.id,
            onUse: () => ref.read(tableThemeProvider.notifier).setPreset(classicGreen.id),
          ),
          for (final p in themeProducts)
            _CosmeticRow(
              kind: p.kind,
              cosmeticId: p.cosmeticId,
              name: p.name,
              swatch: _swatch(appearanceById(p.cosmeticId), size: 40),
              isActive: theme.id == p.cosmeticId,
              onUse: () => ref.read(tableThemeProvider.notifier).setPreset(p.cosmeticId),
            ),
        ];
      case 1:
        final freeBack = cardBackById(kFreeCardBackId);
        return [
          _CosmeticRow(
            kind: CosmeticKind.cardBack,
            cosmeticId: freeBack.id,
            name: freeBack.name,
            swatch: _cardBackSwatch(theme, freeBack),
            isActive: ref.watch(cardBackProvider).id == freeBack.id,
            onUse: () => ref.read(cardBackProvider.notifier).setCardBack(freeBack.id),
          ),
          for (final p in cardBackProducts)
            _CosmeticRow(
              kind: p.kind,
              cosmeticId: p.cosmeticId,
              name: p.name,
              swatch: _cardBackSwatch(theme, cardBackById(p.cosmeticId)),
              isActive: ref.watch(cardBackProvider).id == p.cosmeticId,
              onUse: () => ref.read(cardBackProvider.notifier).setCardBack(p.cosmeticId),
            ),
        ];
      default:
        final freeDeck = cardDeckById(kFreeCardDeckId);
        return [
          _CosmeticRow(
            kind: CosmeticKind.deck,
            cosmeticId: freeDeck.id,
            name: freeDeck.name,
            swatch: _deckSwatch(theme, freeDeck),
            isActive: ref.watch(cardDeckProvider).id == freeDeck.id,
            onUse: () => ref.read(cardDeckProvider.notifier).setCardDeck(freeDeck.id),
          ),
          for (final p in deckProducts)
            _CosmeticRow(
              kind: p.kind,
              cosmeticId: p.cosmeticId,
              name: p.name,
              swatch: _deckSwatch(theme, cardDeckById(p.cosmeticId)),
              isActive: ref.watch(cardDeckProvider).id == p.cosmeticId,
              onUse: () => ref.read(cardDeckProvider.notifier).setCardDeck(p.cosmeticId),
            ),
        ];
    }
  }
}

/// Segmented Themes / Cards / Decks selector shared by the shop tabs.
/// Segmented control (Themes / Cards / Decks, etc.) with a gold selection pill
/// that slides between segments. Shared by the shop and the Customize screen.
class AppSegmentedTabs extends ConsumerWidget {
  final List<String> labels;
  final int current;
  final ValueChanged<int> onSelect;
  const AppSegmentedTabs(
      {super.key, required this.labels, required this.current, required this.onSelect});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(appearanceProvider);
    final n = labels.length;
    final alignX = n <= 1 ? 0.0 : -1.0 + 2.0 * current / (n - 1);
    const height = 38.0;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0x14FFFFFF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            alignment: Alignment(alignX, 0),
            child: FractionallySizedBox(
              widthFactor: 1 / n,
              child: Container(
                height: height,
                decoration: BoxDecoration(
                  color: theme.gold,
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
            ),
          ),
          Row(
            children: [
              for (var i = 0; i < n; i++)
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: withHaptic(() => onSelect(i)),
                    child: SizedBox(
                      height: height,
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 260),
                          curve: Curves.easeOut,
                          style: TextStyle(
                            color: current == i ? theme.feltDark : AppTokens.textSecondary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                          child: Text(labels[i]),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PolicyNote extends StatelessWidget {
  /// The cosmetics shop sells à la carte one-time buys; the Pro page sells
  /// subscriptions, so it omits the "one-time" preamble.
  final bool oneTime;
  const _PolicyNote({this.oneTime = true});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Text(
        '${oneTime ? 'One-time purchases. ' : ''}Cosmetic and training features only — '
        'no ads and no real-money gambling.',
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppTokens.textSecondary, fontSize: 11.5, height: 1.4),
      ),
    );
  }
}

/// Purchases must tie to a signed-in account so entitlements sync across devices
/// and survive reinstall. Returns true if signed in, prompting the sign-in sheet
/// first if not (false if the user dismisses it without signing in).
Future<bool> _ensureSignedIn(BuildContext context, WidgetRef ref) async {
  if (ref.read(authServiceProvider).currentUser != null) return true;
  await showSignInSheet(context);
  return ref.read(authServiceProvider).currentUser != null;
}

Future<void> _buy(BuildContext context, WidgetRef ref, StoreProduct product) async {
  if (_purchasesMobileOnly) {
    _notifyMobileOnly(context);
    return;
  }
  if (!await _ensureSignedIn(context, ref)) return;
  if (!context.mounted) return;
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
    case CosmeticKind.deck:
      ref.read(cardDeckProvider.notifier).setCardDeck(product.cosmeticId);
    case CosmeticKind.bundle:
      for (final id in product.grants) {
        final granted = productById(id);
        if (granted != null) _applyCosmetic(ref, granted);
      }
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

/// Slides tab bodies horizontally like switching pages. Both the leaving and
/// entering pages are driven by one controller so they move together — the
/// leaving page exits one side while the entering page comes in from the other,
/// inside a single clip so they tile side-by-side (never overlapping) and
/// top-aligned so a shorter page isn't re-centered. [dir] is +1 moving to a later
/// tab, -1 to an earlier one. Shared by Shop & Customize.
class SlideTabSwitcher extends StatefulWidget {
  final int tabIndex;
  final int dir;
  final Widget child;
  const SlideTabSwitcher(
      {super.key, required this.tabIndex, required this.dir, required this.child});

  @override
  State<SlideTabSwitcher> createState() => _SlideTabSwitcherState();
}

class _SlideTabSwitcherState extends State<SlideTabSwitcher>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
    value: 1,
  );
  late final Animation<double> _t =
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);

  Widget? _leaving; // the previous tab body, only present mid-transition
  int _dir = 1;

  @override
  void initState() {
    super.initState();
    _ctrl.addStatusListener((status) {
      if (status == AnimationStatus.completed && _leaving != null && mounted) {
        setState(() => _leaving = null);
      }
    });
  }

  @override
  void didUpdateWidget(covariant SlideTabSwitcher old) {
    super.didUpdateWidget(old);
    if (widget.tabIndex != old.tabIndex) {
      _leaving = old.child;
      _dir = widget.dir;
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Idle: render the page directly so its height flows naturally.
    if (_leaving == null) return widget.child;
    return ClipRect(
      child: AnimatedBuilder(
        animation: _t,
        builder: (context, _) {
          final t = _t.value;
          return Stack(
            alignment: Alignment.topCenter,
            children: [
              FractionalTranslation(
                translation: Offset(-_dir * t, 0),
                child: _leaving,
              ),
              FractionalTranslation(
                translation: Offset(_dir * (1 - t), 0),
                child: widget.child,
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Mini face-up Ace rendered with [deck] over the active felt — deck swatch.
Widget _deckSwatch(AppearanceTheme active, CardDeck deck) => PlayingCardView(
      card: const bj.Card(rank: 'A', suit: '♠'),
      theme: active.copyWith(deck: deck),
      width: 30,
      showShadow: false,
    );

/// Subtle status line shown under a cosmetic's name (e.g. "Owned", "Free").
Widget _cosmeticTag(String label, AppearanceTheme t) => Text(label,
    style: TextStyle(
      color: t.gold.withValues(alpha: 0.75),
      fontSize: 11.5,
      fontWeight: FontWeight.w600,
    ));

/// "Owned" line shown once a cosmetic is unlocked. Shared with the Customize list.
Widget ownedTag(AppearanceTheme t) => _cosmeticTag('Owned', t);

/// Opens a large preview of a card back or deck with an equip/unlock action.
/// Card backs and decks are detail-rich, so seeing them full size before
/// selecting matters more than for whole-table themes. Shared by the
/// shop and the Customize screen; [cosmeticId] may be a free default with no
/// [StoreProduct].
Future<void> showCosmeticPreview(
  BuildContext context, {
  required CosmeticKind kind,
  required String cosmeticId,
  required String name,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _CosmeticPreviewDialog(kind: kind, cosmeticId: cosmeticId, name: name),
  );
}

class _CosmeticPreviewDialog extends ConsumerWidget {
  final CosmeticKind kind;
  final String cosmeticId;
  final String name;
  const _CosmeticPreviewDialog(
      {required this.kind, required this.cosmeticId, required this.name});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(appearanceProvider);
    final ent = ref.watch(entitlementsProvider);
    final unlocked = ent.isCosmeticUnlocked(cosmeticId);
    final product = productForCosmeticId(cosmeticId);

    final bool isActive;
    final VoidCallback equip;
    final Widget preview;
    // The felt panel behind the preview normally uses the active theme; a theme
    // preview swaps it for the previewed theme so the felt itself is on show.
    AppearanceTheme panelTheme = theme;
    if (kind == CosmeticKind.theme) {
      final previewTheme = appearanceById(cosmeticId);
      panelTheme = previewTheme;
      isActive = theme.id == cosmeticId;
      equip = () => ref.read(tableThemeProvider.notifier).setPreset(cosmeticId);
      preview = _ThemePreview(theme: previewTheme);
    } else if (kind == CosmeticKind.deck) {
      isActive = ref.watch(cardDeckProvider).id == cosmeticId;
      equip = () => ref.read(cardDeckProvider.notifier).setCardDeck(cosmeticId);
      preview = _DeckPreviewCarousel(theme: theme, deck: cardDeckById(cosmeticId));
    } else {
      isActive = ref.watch(cardBackProvider).id == cosmeticId;
      equip = () => ref.read(cardBackProvider.notifier).setCardBack(cosmeticId);
      preview = PlayingCardView(
        card: const bj.Card(rank: 'A', suit: '♠', faceDown: true),
        theme: theme.copyWith(cardBack: cardBackById(cosmeticId)),
        width: 168,
      );
    }

    Widget action;
    if (isActive) {
      action = Container(
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: theme.gold.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.gold),
        ),
        child: Text('✓ In use',
            style: TextStyle(color: theme.goldLight, fontWeight: FontWeight.bold)),
      );
    } else if (unlocked) {
      action = FilledButton(
        onPressed: () {
          equip();
          Navigator.pop(context);
        },
        child: const Text('Use'),
      );
    } else {
      action = FilledButton(
        onPressed: ent.busy || product == null
            ? null
            : () async {
                await _buy(context, ref, product);
                if (context.mounted) Navigator.pop(context);
              },
        child: Text(product == null ? 'Locked' : 'Unlock · ${livePriceLabel(ref, product)}'),
      );
    }

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(24, 12, 10, 0),
      title: Row(
        children: [
          Expanded(child: Text(name)),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, size: 20),
            color: AppTokens.textSecondary,
            visualDensity: VisualDensity.compact,
            tooltip: 'Close',
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: panelTheme.feltGradient,
              borderRadius: BorderRadius.circular(AppTokens.radiusLg),
              border: Border.all(color: panelTheme.feltBorder),
            ),
            child: preview,
          ),
          const SizedBox(height: 18),
          SizedBox(width: double.infinity, child: action),
        ],
      ),
    );
  }
}

/// A mini table dressed in a theme: two dealt cards and a gold accent bar over
/// the theme's felt — so its felt, border, card, and gold colors are all
/// visible before applying or buying.
class _ThemePreview extends StatelessWidget {
  final AppearanceTheme theme;
  const _ThemePreview({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 100,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Transform.translate(
                offset: const Offset(-28, 0),
                child: Transform.rotate(
                  angle: -0.12,
                  child: PlayingCardView(
                      card: const bj.Card(rank: 'K', suit: '♠'), theme: theme, width: 66),
                ),
              ),
              Transform.translate(
                offset: const Offset(28, 0),
                child: Transform.rotate(
                  angle: 0.12,
                  child: PlayingCardView(
                      card: const bj.Card(rank: '7', suit: '♥'), theme: theme, width: 66),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Container(
          width: 132,
          height: 8,
          decoration:
              BoxDecoration(color: theme.gold, borderRadius: BorderRadius.circular(4)),
        ),
      ],
    );
  }
}

/// Swipeable/arrow-navigable preview of a card-face deck. Shows a curated set of
/// cards (aces, courts, numbers across suits) so the whole deck's character is
/// visible before buying. Drag horizontally or tap the arrows.
class _DeckPreviewCarousel extends StatefulWidget {
  final AppearanceTheme theme;
  final CardDeck deck;

  /// When set, the matching card back leads as the first preview page — used by
  /// the bundle preview so the deck and its back share one carousel.
  final CardBack? back;
  const _DeckPreviewCarousel({required this.theme, required this.deck, this.back});

  @override
  State<_DeckPreviewCarousel> createState() => _DeckPreviewCarouselState();
}

class _DeckPreviewCarouselState extends State<_DeckPreviewCarousel> {
  static const List<(String, String)> _cards = [
    ('A', '♠'), ('K', '♥'), ('Q', '♦'), ('J', '♣'),
    ('10', '♥'), ('7', '♠'), ('4', '♦'), ('2', '♣'),
  ];

  final _controller = PageController();
  int _index = 0;

  int get _pageCount => _cards.length + (widget.back != null ? 1 : 0);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _go(int delta) {
    final next = (_index + delta).clamp(0, _pageCount - 1);
    _controller.animateToPage(next,
        duration: const Duration(milliseconds: 260), curve: Curves.easeOutCubic);
  }

  Widget _page(int i) {
    final t = widget.theme;
    final back = widget.back;
    if (back != null && i == 0) {
      return PlayingCardView(
        card: const bj.Card(rank: 'A', suit: '♠', faceDown: true),
        theme: t.copyWith(cardBack: back),
        width: 150,
      );
    }
    final c = _cards[back != null ? i - 1 : i];
    return PlayingCardView(
      card: bj.Card(rank: c.$1, suit: c.$2),
      theme: t.copyWith(deck: widget.deck),
      width: 150,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    // Fixed width: a PageView (viewport) can't report an intrinsic width, and the
    // enclosing AlertDialog measures its content's intrinsic width — so the width
    // must resolve here, before the intrinsic pass reaches the PageView.
    return SizedBox(
      width: 260,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 240,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PageView.builder(
                  controller: _controller,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemCount: _pageCount,
                  itemBuilder: (_, i) => Center(child: _page(i)),
                ),
                Positioned(
                    left: -4, child: _arrow(Icons.chevron_left, _index > 0, () => _go(-1))),
                Positioned(
                    right: -4,
                    child:
                        _arrow(Icons.chevron_right, _index < _pageCount - 1, () => _go(1))),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < _pageCount; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  width: i == _index ? 20 : 7,
                  height: 7,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: i == _index ? t.goldLight : const Color(0x33FFFFFF),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _arrow(IconData icon, bool enabled, VoidCallback onTap) => IconButton(
        onPressed: enabled ? withHaptic(onTap) : null,
        icon: Icon(icon),
        iconSize: 34,
        color: widget.theme.goldLight,
        disabledColor: const Color(0x22FFFFFF),
        style: const ButtonStyle(
          overlayColor: WidgetStatePropertyAll(Colors.transparent),
        ),
      );
}

/// Compact Pro cross-sell shown atop the cosmetics shop.
class _GoProBanner extends StatelessWidget {
  final AppearanceTheme theme;
  final bool isPremium;
  const _GoProBanner({required this.theme, required this.isPremium});

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: theme.gold.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.gold.withValues(alpha: 0.55), width: 1.1),
      ),
      child: Row(
        children: [
          _CardFan(theme: theme),
          const SizedBox(width: 14),
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
                        ? 'All decks & themes unlocked'
                        : 'Every deck, back, theme & feature',
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
              child: Text('Go Pro',
                  style: TextStyle(
                      color: theme.feltDark, fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ],
        ],
      ),
    );
    if (isPremium) return content;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: withHaptic(() => openGoPro(context)),
      child: content,
    );
  }
}

/// Three premium face cards overlapping in a straight stack — the visual hook
/// for the Pro banner.
class _CardFan extends StatelessWidget {
  final AppearanceTheme theme;
  const _CardFan({required this.theme});

  static const _cards = [
    (cardDeckGreek, 'Q', '♦', -17.0),
    (cardDeckUkiyoe, 'K', '♠', 0.0),
    (cardDeckIlluminated, 'K', '♥', 17.0),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      height: 60,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          for (final c in _cards)
            Transform.translate(
              offset: Offset(c.$4, 0),
              child: PlayingCardView(
                card: bj.Card(rank: c.$2, suit: c.$3),
                theme: theme.copyWith(deck: c.$1),
                width: 42,
              ),
            ),
        ],
      ),
    );
  }
}

/// Signature face card shown in each bundle banner's mini preview.
const Map<String, (String, String)> _bundleSignature = {
  'bundle_illuminated': ('K', '♥'),
  'bundle_ukiyoe': ('K', '♠'),
  'bundle_greek': ('Q', '♦'),
  'bundle_egyptian': ('K', '♠'),
  'bundle_gyotaku': ('K', '♥'),
  'bundle_tarot': ('Q', '♦'),
  'bundle_audubon': ('A', '♥'),
};

CardBack _bundleBack(StoreProduct bundle) {
  for (final id in bundle.grants) {
    final p = productById(id);
    if (p != null && p.kind == CosmeticKind.cardBack) return cardBackById(p.cosmeticId);
  }
  return cardBackById(kFreeCardBackId);
}

double _priceValue(String label) =>
    double.tryParse(label.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;

/// The deck + matching-back bundle offers, shown as promo banners under the Pro
/// cross-sell. Hidden entirely for Pro members and for bundles already owned.
class _BundlesSection extends ConsumerWidget {
  final AppearanceTheme theme;
  const _BundlesSection({required this.theme});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ent = ref.watch(entitlementsProvider);
    if (ent.isPremium) return const SizedBox.shrink();
    final open = bundleProducts
        .where((b) => !(ent.ownsProduct(b.id) || b.grants.every(ent.owned.contains)))
        .toList();
    if (open.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text('Sets · deck + matching back',
                style: TextStyle(
                    color: AppTokens.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ),
          SizedBox(
            height: 152,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              clipBehavior: Clip.hardEdge,
              itemCount: open.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (_, i) => _BundleCard(theme: theme, bundle: open[i]),
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact set card for the horizontal "Sets" carousel: the deck's signature
/// face overlapping its matching back, the set name, and the discounted price.
class _BundleCard extends ConsumerWidget {
  final AppearanceTheme theme;
  final StoreProduct bundle;
  const _BundleCard({required this.theme, required this.bundle});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deck = cardDeckById(bundle.cosmeticId);
    final back = _bundleBack(bundle);
    final sig = _bundleSignature[bundle.id] ?? ('A', '♠');
    final original =
        bundle.grants.fold<double>(0, (s, id) => s + _priceValue(livePriceLabel(ref, productById(id)) ?? ''));

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: withHaptic(() => showBundlePreview(context, bundle)),
      child: Container(
        width: 148,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0x14FFFFFF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.gold.withValues(alpha: 0.35)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _BundlePreview(
                theme: theme, deck: deck, back: back, rank: sig.$1, suit: sig.$2),
            const SizedBox(height: 12),
            Text(bundle.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: AppTokens.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (original > 0) ...[
                  Text('\$${original.toStringAsFixed(2)}',
                      style: const TextStyle(
                          color: AppTokens.textSecondary,
                          fontSize: 11,
                          decoration: TextDecoration.lineThrough)),
                  const SizedBox(width: 5),
                ],
                Text(livePriceLabel(ref, bundle) ?? bundle.priceLabel,
                    style: TextStyle(
                        color: theme.goldLight,
                        fontSize: 13,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A deck's signature face card overlapping its matching card back.
class _BundlePreview extends StatelessWidget {
  final AppearanceTheme theme;
  final CardDeck deck;
  final CardBack back;
  final String rank;
  final String suit;
  const _BundlePreview(
      {required this.theme,
      required this.deck,
      required this.back,
      required this.rank,
      required this.suit});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 66,
      height: 58,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Transform.translate(
            offset: const Offset(-13, 0),
            child: PlayingCardView(
              card: const bj.Card(rank: 'A', suit: '♠', faceDown: true),
              theme: theme.copyWith(cardBack: back),
              width: 40,
            ),
          ),
          Transform.translate(
            offset: const Offset(13, 0),
            child: PlayingCardView(
              card: bj.Card(rank: rank, suit: suit),
              theme: theme.copyWith(deck: deck),
              width: 40,
            ),
          ),
        ],
      ),
    );
  }
}

/// Opens a full preview of a bundle: the swipeable deck faces plus its matching
/// card back, with a single action to unlock (or equip, if already owned).
Future<void> showBundlePreview(BuildContext context, StoreProduct bundle) {
  return showDialog<void>(
    context: context,
    builder: (_) => _BundlePreviewDialog(bundle: bundle),
  );
}

class _BundlePreviewDialog extends ConsumerWidget {
  final StoreProduct bundle;
  const _BundlePreviewDialog({required this.bundle});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(appearanceProvider);
    final ent = ref.watch(entitlementsProvider);
    final deck = cardDeckById(bundle.cosmeticId);
    final back = _bundleBack(bundle);
    final unlocked = ent.isPremium ||
        ent.ownsProduct(bundle.id) ||
        bundle.grants.every(ent.owned.contains);

    final Widget action = unlocked
        ? FilledButton(
            onPressed: () {
              _applyCosmetic(ref, bundle);
              Navigator.pop(context);
            },
            child: const Text('Use set'),
          )
        : FilledButton(
            onPressed: ent.busy
                ? null
                : () async {
                    await _buy(context, ref, bundle);
                    if (context.mounted) Navigator.pop(context);
                  },
            child: Text('Unlock · ${livePriceLabel(ref, bundle) ?? bundle.priceLabel}'),
          );

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(24, 12, 10, 0),
      title: Row(
        children: [
          Expanded(child: Text(bundle.name)),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, size: 20),
            color: AppTokens.textSecondary,
            visualDensity: VisualDensity.compact,
            tooltip: 'Close',
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
              decoration: BoxDecoration(
                gradient: theme.feltGradient,
                borderRadius: BorderRadius.circular(AppTokens.radiusLg),
                border: Border.all(color: theme.feltBorder),
              ),
              child: _DeckPreviewCarousel(theme: theme, deck: deck, back: back),
            ),
            const SizedBox(height: 18),
            SizedBox(width: double.infinity, child: action),
          ],
        ),
      ),
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

  /// When true, tags the row with a "Lifetime" pill (a perk subscriptions don't
  /// include).
  final bool lifetimeOnly;
  const _FeatureRow(
      {required this.theme,
      required this.icon,
      required this.title,
      required this.subtitle,
      this.lifetimeOnly = false});

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
                Row(
                  children: [
                    Flexible(
                      child: Text(title,
                          style: const TextStyle(
                              color: AppTokens.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                    ),
                    if (lifetimeOnly) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.gold.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: theme.gold, width: 1),
                        ),
                        child: Text('Lifetime',
                            style: TextStyle(
                                color: theme.gold,
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),
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

/// One purchasable cosmetic row (theme, card back, or deck). [isActive]
/// and [onUse] are supplied by the caller so the same row serves all kinds.
class _CosmeticRow extends ConsumerWidget {
  final CosmeticKind kind;
  final String cosmeticId;
  final String name;
  final Widget swatch;
  final bool isActive;
  final VoidCallback onUse;
  const _CosmeticRow({
    required this.kind,
    required this.cosmeticId,
    required this.name,
    required this.swatch,
    required this.isActive,
    required this.onUse,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(appearanceProvider);
    final ent = ref.watch(entitlementsProvider);
    final unlocked = ent.isCosmeticUnlocked(cosmeticId);
    // A free default (Classic Green, Royal Blue) has no product.
    final product = productForCosmeticId(cosmeticId);

    // Every cosmetic opens a full-size preview on tap, where it's equipped or
    // bought — themes included, shown as a mini table dressed in the theme.
    final previewable = kind == CosmeticKind.theme ||
        kind == CosmeticKind.cardBack ||
        kind == CosmeticKind.deck;
    final VoidCallback? onTap = previewable
        ? () => showCosmeticPreview(context, kind: kind, cosmeticId: cosmeticId, name: name)
        : unlocked
            ? (isActive ? null : onUse)
            : (ent.busy || product == null ? null : () => _buy(context, ref, product));

    return CosmeticTile(
      theme: active,
      preview: swatch,
      name: name,
      selected: isActive,
      priceLabel: unlocked ? null : livePriceLabel(ref, product),
      ownedLabel: product != null ? 'Owned' : 'Free',
      onTap: onTap,
    );
  }
}
