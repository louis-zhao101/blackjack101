import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart' show Offering, Package, PackageType;

import '../../engine/cards.dart' as bj;
import '../../services/purchases_service.dart';
import '../../state/appearance_provider.dart';
import '../../state/auth_provider.dart';
import '../../state/store_provider.dart';
import '../theme/appearance.dart';
import '../widgets/chip_widget.dart';
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

  Future<void> _subscribe() async {
    final package = _selected;
    if (package == null || _purchasing) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _purchasing = true);
    try {
      final uid = ref.read(authServiceProvider).currentUser?.uid;
      if (uid != null) await PurchasesService.logIn(uid);
      final nowPro = await PurchasesService.purchasePackage(package);
      if (nowPro) {
        await ref.read(proStatusProvider.notifier).refresh();
        if (!mounted) return;
        await _showSuccessDialog();
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

  String _ctaLabel(Package p) => p.packageType == PackageType.lifetime
      ? 'Unlock Lifetime · ${p.storeProduct.priceString}'
      : 'Subscribe · ${p.storeProduct.priceString}';

  Future<void> _showSuccessDialog() {
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
            Text("You're Pro!",
                style: TextStyle(
                    color: theme.goldLight, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Every theme and Pro feature is unlocked.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTokens.textSecondary, fontSize: 14, height: 1.4)),
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
    final isPremium = ref.watch(entitlementsProvider).isPremium;
    final packages = _offering == null ? const <Package>[] : _ordered(_offering!);

    return Scaffold(
      backgroundColor: theme.feltDark,
      appBar: _shopAppBar(theme, isPremium ? 'Pro' : 'Go Pro'),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          children: [
            if (isPremium)
              _ProActiveCard(theme: theme)
            else if (_loading)
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
                  selected: _selected?.identifier == p.identifier,
                  onTap: () => setState(() => _selected = p),
                ),
              const SizedBox(height: 4),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _purchasing || _selected == null ? null : _subscribe,
                  child: _purchasing
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(_ctaLabel(_selected!)),
                ),
              ),
            ],
            const SizedBox(height: 20),
            _ShopSection(
              title: isPremium ? "What's included" : 'Everything in Pro',
              child: Column(
                children: [
                  for (final (icon, title, sub) in _proFeatures)
                    _FeatureRow(theme: theme, icon: icon, title: title, subtitle: sub),
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
                  if (!_purchasesMobileOnly && ref.watch(proStatusProvider).isPro)
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
  final VoidCallback onTap;
  const _PackageTile({
    required this.theme,
    required this.package,
    required this.monthlyRef,
    required this.selected,
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
      onTap: withHaptic(onTap),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? theme.gold.withValues(alpha: 0.12) : const Color(0x14FFFFFF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? theme.gold : const Color(0x18FFFFFF),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                color: selected ? theme.goldLight : AppTokens.textSecondary, size: 22),
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
                      if (isAnnual) ...[
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
                    color: theme.goldLight, fontSize: 16, fontWeight: FontWeight.bold)),
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
          const SizedBox(width: 10),
          const Expanded(
            child: Text('Blackjack Pro is active',
                style: TextStyle(
                    color: AppTokens.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
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
                AppSegmentedTabs(
                    labels: _labels, current: _tab, onSelect: (i) => setState(() => _tab = i)),
                const SizedBox(height: 16),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  child: Column(
                    key: ValueKey(_tab),
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: _rowsForTab(theme),
                  ),
                ),
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
        final freeChips = chipStyleById(kFreeChipStyleId);
        return [
          _CosmeticRow(
            kind: CosmeticKind.chipStyle,
            cosmeticId: freeChips.id,
            name: freeChips.name,
            swatch: _chipSwatch(theme, freeChips),
            isActive: ref.watch(chipStyleProvider).id == freeChips.id,
            onUse: () => ref.read(chipStyleProvider.notifier).setChipStyle(freeChips.id),
          ),
          for (final p in chipStyleProducts)
            _CosmeticRow(
              kind: p.kind,
              cosmeticId: p.cosmeticId,
              name: p.name,
              swatch: _chipSwatch(theme, chipStyleById(p.cosmeticId)),
              isActive: ref.watch(chipStyleProvider).id == p.cosmeticId,
              onUse: () => ref.read(chipStyleProvider.notifier).setChipStyle(p.cosmeticId),
            ),
        ];
    }
  }
}

/// Segmented Themes / Cards / Chips selector shared by the shop tabs.
/// Segmented control (Themes / Cards / Chips, etc.) with a gold selection pill
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

Future<void> _buy(BuildContext context, WidgetRef ref, StoreProduct product) async {
  if (_purchasesMobileOnly) {
    _notifyMobileOnly(context);
    return;
  }
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

/// Subtle status line shown under a cosmetic's name (e.g. "Owned", "Free").
Widget _cosmeticTag(String label, AppearanceTheme t) => Text(label,
    style: TextStyle(
      color: t.gold.withValues(alpha: 0.75),
      fontSize: 11.5,
      fontWeight: FontWeight.w600,
    ));

/// "Owned" line shown once a cosmetic is unlocked. Shared with the Customize list.
Widget ownedTag(AppearanceTheme t) => _cosmeticTag('Owned', t);

/// Opens a large preview of a card back or chip style with an equip/unlock
/// action. Card backs and chips are detail-rich, so seeing them full size
/// before selecting matters more than for whole-table themes. Shared by the
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
    if (kind == CosmeticKind.chipStyle) {
      final previewTheme = theme.copyWith(chipStyle: chipStyleById(cosmeticId));
      isActive = ref.watch(chipStyleProvider).id == cosmeticId;
      equip = () => ref.read(chipStyleProvider.notifier).setChipStyle(cosmeticId);
      preview = Wrap(
        spacing: 16,
        runSpacing: 16,
        alignment: WrapAlignment.center,
        children: [
          for (final amount in const [5, 25, 100, 500])
            PokerChipFace(amount: amount, theme: previewTheme, size: 62),
        ],
      );
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
        child: Text(product == null ? 'Locked' : 'Unlock · ${product.priceLabel}'),
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
              gradient: theme.feltGradient,
              borderRadius: BorderRadius.circular(AppTokens.radiusLg),
              border: Border.all(color: theme.feltBorder),
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
              child: Text('Go Pro',
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
      onTap: withHaptic(() => openGoPro(context)),
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

/// One purchasable cosmetic row (theme, card back, or chip style). [isActive]
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
    // A free default (Classic Green, Royal Blue, Classic chips) has no product.
    final product = productForCosmeticId(cosmeticId);

    // Cards and chips open a full-size preview on tap (where they're equipped
    // or bought); themes apply instantly since the whole table is the preview.
    final previewable = kind == CosmeticKind.cardBack || kind == CosmeticKind.chipStyle;
    final VoidCallback? onTap = previewable
        ? () => showCosmeticPreview(context, kind: kind, cosmeticId: cosmeticId, name: name)
        : unlocked
            ? (isActive ? null : onUse)
            : (ent.busy || product == null ? null : () => _buy(context, ref, product));

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
        child: Text(product?.priceLabel ?? '',
            style: TextStyle(
                color: active.feltDark, fontWeight: FontWeight.bold, fontSize: 14)),
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: withHaptic(onTap),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(name,
                      style: const TextStyle(
                          color: AppTokens.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  if (product == null) ...[
                    const SizedBox(height: 4),
                    _cosmeticTag('Free', active),
                  ] else if (unlocked) ...[
                    const SizedBox(height: 4),
                    ownedTag(active),
                  ],
                ],
              ),
            ),
            SizedBox(width: 84, child: Align(alignment: Alignment.centerRight, child: trailing)),
          ],
        ),
      ),
    );
  }
}
