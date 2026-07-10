import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../engine/achievements.dart';
import '../engine/strategy.dart';
import '../engine/variants.dart';
import '../services/purchases_service.dart';
import '../services/sound_service.dart';
import '../state/achievements_provider.dart';
import '../state/app_providers.dart';
import '../state/appearance_provider.dart';
import '../state/auth_provider.dart';
import '../services/analytics.dart';
import '../services/firestore_sync.dart' show ReferralRedeemOutcome;
import '../state/game_provider.dart';
import '../state/referral_provider.dart';
import '../state/settings_provider.dart';
import '../state/stats_provider.dart';
import '../state/store_provider.dart';
import 'auth_screen.dart';
import 'screens/learn_page.dart';
import 'screens/play_page.dart';
import 'screens/shop_page.dart';
import 'screens/stats_page.dart';
import '../engine/cards.dart' as bj;
import 'theme/appearance.dart';
import 'widgets/chip_widget.dart';
import 'widgets/game_button.dart';
import 'widgets/playing_card.dart';

const _navTitles = ['Play', 'Learn', 'Stats', 'Account'];
const _navIcons = [
  Icons.casino_outlined,
  Icons.menu_book_outlined,
  Icons.insights_outlined,
  Icons.account_circle_outlined,
];
const _navIconsSelected = [
  Icons.casino,
  Icons.menu_book,
  Icons.insights,
  Icons.account_circle,
];

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(appearanceProvider);
    final tab = ref.watch(navTabProvider);
    void select(int i) => ref.read(navTabProvider.notifier).select(i);

    ref.listen(achievementCelebrationProvider, (_, unlocked) {
      if (unlocked.isEmpty) return;
      // Read the live appearance at fire time so the toast matches the theme the
      // user currently has selected (not whatever was active when registered).
      final theme = ref.read(appearanceProvider);
      successHaptic();
      final messenger = ScaffoldMessenger.of(context);
      final width = _snackWidth(context);
      for (final a in unlocked) {
        messenger.showSnackBar(_achievementSnackBar(theme, a,
            width: width,
            onShare: () =>
                showAchievementShareCard(context, theme: theme, achievement: a)));
      }
      ref.read(achievementCelebrationProvider.notifier).consume();
    });

    // A "positive moment" (strong session, hot streak) invites a share.
    ref.listen(shareInviteProvider, (_, invite) {
      if (invite == null) return;
      final theme = ref.read(appearanceProvider);
      ScaffoldMessenger.of(context).showSnackBar(_shareInviteSnackBar(
        theme,
        invite,
        width: _snackWidth(context),
        onShare: () => showResultShareCard(
          context,
          theme: theme,
          accuracy: invite.accuracy,
          totalHands: invite.totalHands,
          bestStreak: invite.bestStreak,
        ),
      ));
      ref.read(shareInviteProvider.notifier).consume();
    });

    // A friend redeemed the user's code → celebrate the card back they unlocked.
    ref.listen(referralRewardProvider, (_, name) {
      if (name == null) return;
      final theme = ref.read(appearanceProvider);
      successHaptic();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        duration: const Duration(seconds: 5),
        width: _snackWidth(context),
        backgroundColor: theme.feltDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: theme.gold.withValues(alpha: 0.6)),
        ),
        content: Text('🎉 A friend joined — you unlocked the $name card back!',
            style: const TextStyle(
                color: AppTokens.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600)),
      ));
      ref.read(referralRewardProvider.notifier).consume();
    });

    ref.listen(entitlementsProvider, (_, _) {
      ref.read(achievementsProvider.notifier).evaluate();
    });

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 600;
        return Scaffold(
          backgroundColor: theme.feltDark,
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                _Header(
                  theme: theme,
                  tab: tab,
                  showNav: wide,
                  onSelectTab: select,
                ),
                Expanded(
                  child: IndexedStack(
                    index: tab,
                    // Play stays full-bleed (immersive felt table); the list
                    // pages are capped so they don't stretch on wide desktop.
                    children: const [
                      PlayPage(),
                      _CappedBody(child: LearnPage()),
                      _CappedBody(child: StatsPage()),
                      _CappedBody(child: AccountPage()),
                    ],
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar:
              wide ? null : _BottomNav(theme: theme, tab: tab, onSelect: select),
        );
      },
    );
  }
}

/// Caps floating snackbars so they don't stretch the full width of a desktop
/// web window; stays near-full-width on phones.
double _snackWidth(BuildContext context) {
  final w = MediaQuery.of(context).size.width;
  return w < 512 ? w - 32 : 480;
}

SnackBar _shareInviteSnackBar(
  AppearanceTheme theme,
  ShareInvite invite, {
  required VoidCallback onShare,
  required double width,
}) {
  return SnackBar(
    duration: const Duration(seconds: 5),
    width: width,
    backgroundColor: theme.feltDark,
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: BorderSide(color: theme.gold.withValues(alpha: 0.6)),
    ),
    content: Text(invite.message,
        style: const TextStyle(
            color: AppTokens.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600)),
    action: SnackBarAction(
        label: 'Share', textColor: theme.goldLight, onPressed: onShare),
  );
}

SnackBar _achievementSnackBar(
  AppearanceTheme theme,
  Achievement a, {
  required VoidCallback onShare,
  required double width,
}) {
  return SnackBar(
    duration: const Duration(seconds: 4),
    width: width,
    backgroundColor: theme.feltDark,
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: BorderSide(color: theme.gold.withValues(alpha: 0.6)),
    ),
    action: SnackBarAction(
        label: 'Share', textColor: theme.goldLight, onPressed: onShare),
    content: Row(
      children: [
        Text(a.emoji,
            style: const TextStyle(fontSize: 26, color: AppTokens.textPrimary)),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Achievement unlocked',
                  style: TextStyle(
                      color: theme.goldLight,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5)),
              const SizedBox(height: 2),
              Text(a.title,
                  style: const TextStyle(
                      color: AppTokens.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ],
    ),
  );
}

/// Caps a page's content width and centres it, so list-style pages don't
/// stretch edge-to-edge on wide desktop windows. The scaffold fills the gutters.
class _CappedBody extends StatelessWidget {
  final Widget child;
  const _CappedBody({required this.child});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: child,
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final AppearanceTheme theme;
  final int tab;
  final bool showNav;
  final ValueChanged<int> onSelectTab;

  const _Header({
    required this.theme,
    required this.tab,
    required this.showNav,
    required this.onSelectTab,
  });

  @override
  Widget build(BuildContext context) {
    final brand = Text(
      '♠ Blackjack 101 ♥',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(color: theme.gold, fontSize: 17, fontWeight: FontWeight.bold),
    );
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: theme.feltDark,
        border: Border(bottom: BorderSide(color: theme.feltBorder)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Flexible(
                  // On web the wordmark doubles as a home link back to the
                  // marketing landing page; on mobile it's just the title.
                  child: kIsWeb
                      ? Consumer(
                          builder: (context, ref, _) => MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () =>
                                  ref.read(landingSeenProvider.notifier).exit(),
                              child: brand,
                            ),
                          ),
                        )
                      : brand,
                ),
                if (showNav) ...[
                  const SizedBox(width: 12),
                  for (var i = 0; i < _navTitles.length; i++)
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: withHaptic(() => onSelectTab(i)),
                      child: Text(
                        _navTitles[i],
                        style: TextStyle(
                          color: i == tab ? theme.gold : AppTokens.textSecondary,
                          fontWeight: i == tab ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
          _SyncIndicator(theme: theme),
        ],
      ),
    );
  }
}

/// Shows only when a background write to Firestore has exhausted its retries.
/// Tapping it re-attempts the queued writes so nothing is silently lost.
class _SyncIndicator extends ConsumerWidget {
  final AppearanceTheme theme;
  const _SyncIndicator({required this.theme});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(syncQueueProvider);
    const color = Color(0xFFFC8181);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: status.phase != SyncPhase.failed
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Material(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppTokens.radius),
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppTokens.radius),
                  onTap: () {
                    selectionHaptic();
                    ref.read(syncQueueProvider.notifier).retry();
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.cloud_off_outlined, size: 15, color: color),
                        SizedBox(width: 5),
                        Text(
                          'Sync failed',
                          style: TextStyle(
                            color: color,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(Icons.refresh, size: 14, color: color),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final AppearanceTheme theme;
  final int tab;
  final ValueChanged<int> onSelect;
  const _BottomNav({required this.theme, required this.tab, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Container(
      color: theme.feltDark,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SizedBox(
        height: 64,
        child: Row(
          children: [
            for (var i = 0; i < _navTitles.length; i++)
              Expanded(
                child: _NavItem(
                  theme: theme,
                  selected: i == tab,
                  icon: _navIcons[i],
                  selectedIcon: _navIconsSelected[i],
                  label: _navTitles[i],
                  onTap: () {
                    selectionHaptic();
                    onSelect(i);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// One bottom-nav destination. The pill fades in, the icon pops + cross-fades
/// between outlined and filled, and the label eases its colour/weight when
/// selection changes.
class _NavItem extends StatelessWidget {
  final AppearanceTheme theme;
  final bool selected;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final VoidCallback onTap;
  const _NavItem({
    required this.theme,
    required this.selected,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.onTap,
  });

  static const _dur = Duration(milliseconds: 260);

  @override
  Widget build(BuildContext context) {
    final color = selected ? theme.gold : AppTokens.textSecondary;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: _dur,
              curve: Curves.easeOut,
              width: 58,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? theme.gold.withValues(alpha: 0.20) : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: AnimatedSwitcher(
                duration: _dur,
                switchInCurve: Curves.easeOutBack,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, anim) => ScaleTransition(
                  scale: Tween(begin: 0.7, end: 1.0).animate(anim),
                  child: FadeTransition(opacity: anim, child: child),
                ),
                child: Icon(
                  selected ? selectedIcon : icon,
                  key: ValueKey(selected),
                  color: color,
                  size: 24,
                ),
              ),
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: _dur,
              curve: Curves.easeOut,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                color: color,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Account / settings ---------------------------------------------------

const _cardBg = Color(0x14FFFFFF);
const _tileBg = Color(0x24FFFFFF);

void _confirm(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  required VoidCallback onConfirm,
}) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
            onPressed: withHaptic(() => Navigator.pop(context)),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: withHaptic(() {
            Navigator.pop(context);
            onConfirm();
          }),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
}

Future<void> _showSheet(BuildContext context, {required String title, required Widget child}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _SheetShell(title: title, child: child),
  );
}

Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  final uid = ref.read(authServiceProvider).currentUser?.uid;
  if (uid == null) return;
  try {
    await ref.read(firestoreSyncProvider).deleteUserData(uid);
    await ref.read(authServiceProvider).deleteAccount();
    ref.read(statsProvider.notifier).clearHistory();
    ref.read(phoneAuthControllerProvider.notifier).reset();
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.toString())));
  }
}

/// Account + Settings hub, laid out as simple grouped cards.
class AccountPage extends ConsumerWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(appearanceProvider);
    final settings = ref.watch(settingsProvider);
    final bankroll = ref.watch(gameProvider).game.bankroll;
    final user = ref.watch(authStateProvider).value;
    final signedIn = user != null;
    final phone = user?.phoneNumber ?? '';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        _SectionCard(
          title: 'Account',
          children: [
            _SettingRow(
              icon: signedIn ? Icons.logout : Icons.login,
              title: signedIn ? 'Sign out' : 'Sign in',
              subtitle: signedIn
                  ? (phone.isNotEmpty ? phone : 'Synced to cloud')
                  : 'Save & view your stats',
              onTap: signedIn
                  ? () => _confirm(
                        context,
                        title: 'Sign out?',
                        message:
                            'You can sign back in anytime. Your saved stats stay in the cloud.',
                        confirmLabel: 'Sign out',
                        onConfirm: () =>
                            ref.read(phoneAuthControllerProvider.notifier).signOut(),
                      )
                  : () => showSignInSheet(context),
            ),
            if (signedIn)
              _SettingRow(
                icon: Icons.card_giftcard_outlined,
                title: 'Invite friends',
                subtitle: ref.watch(entitlementsProvider).hasUnlockableCardBack
                    ? 'Share your code — unlock free card backs'
                    : 'Share your code with friends',
                onTap: () => _showSheet(context,
                    title: 'Invite friends', child: const _InviteFriendsSheet()),
              ),
          ],
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'General',
          children: [
            _SettingRow(
              icon: Icons.workspace_premium_outlined,
              title: ref.watch(entitlementsProvider).isPremium ? 'Pro' : 'Go Pro',
              subtitle: ref.watch(entitlementsProvider).isPremium
                  ? 'Everything unlocked'
                  : 'Unlock everything for $kLifetimePrice',
              onTap: () => openGoPro(context),
            ),
            // Pro unlocks every cosmetic, so the à la carte Shop is redundant —
            // Pro users equip everything straight from Customize.
            if (!ref.watch(entitlementsProvider).isPremium)
              _SettingRow(
                icon: Icons.storefront_outlined,
                title: 'Shop',
                subtitle: 'Table themes & cosmetics',
                onTap: () => openShop(context),
              ),
            _SettingRow(
              icon: Icons.palette_outlined,
              title: 'Customize',
              subtitle: 'Table, cards & chips',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                    fullscreenDialog: true, builder: (_) => const _CustomizeScreen()),
              ),
            ),
            _SettingRow(
              icon: Icons.casino_outlined,
              title: 'Game mode',
              subtitle: settings.ruleSet.name,
              onTap: () => _showSheet(context, title: 'Game mode', child: const _RuleSetSheet()),
            ),
            _SettingRow(
              icon: Icons.trending_up,
              title: 'Difficulty',
              subtitle: difficultyLabel(settings.difficulty),
              onTap: () =>
                  _showSheet(context, title: 'Difficulty', child: const _DifficultySheet()),
            ),
            _SettingRow(
              icon: Icons.account_balance_wallet_outlined,
              title: 'Bankroll',
              subtitle: 'Start \$${settings.startingBankroll}  ·  Now \$$bankroll',
              onTap: () => _showSheet(context, title: 'Bankroll', child: const _BankrollSheet()),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Preferences',
          children: [
            _SettingRow(
              icon: Icons.vibration,
              title: 'Haptic feedback',
              subtitle: 'Vibrate on taps & actions',
              trailing: Switch(
                value: settings.hapticsEnabled,
                activeThumbColor: theme.gold,
                onChanged: (v) {
                  ref.read(settingsProvider.notifier).setHaptics(v);
                  if (v) selectionHaptic();
                },
              ),
            ),
            _SettingRow(
              icon: Icons.volume_up_outlined,
              title: 'Sound effects',
              subtitle: 'Cards, chips & outcome sounds',
              trailing: Switch(
                value: settings.soundEnabled,
                activeThumbColor: theme.gold,
                onChanged: (v) {
                  ref.read(settingsProvider.notifier).setSound(v);
                  if (v) SoundService.instance.chipPlace();
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Data',
          children: [
            _SettingRow(
              icon: Icons.delete_sweep_outlined,
              title: 'Clear stats history',
              subtitle: 'Remove sessions & strategy accuracy',
              onTap: () => _confirm(
                context,
                title: 'Clear stats history?',
                message:
                    'This removes all saved sessions and your strategy accuracy. Practice '
                    'drills and earned achievements are kept. This cannot be undone.',
                confirmLabel: 'Clear',
                onConfirm: () => ref.read(statsProvider.notifier).clearHistory(),
              ),
            ),
            if (signedIn)
              _SettingRow(
                icon: Icons.person_off_outlined,
                title: 'Delete account',
                subtitle: 'Delete account & cloud data',
                danger: true,
                onTap: () => _confirm(
                  context,
                  title: 'Delete account?',
                  message:
                      'This permanently deletes your account and all stats saved to the cloud. This cannot be undone.',
                  confirmLabel: 'Delete',
                  onConfirm: () => _deleteAccount(context, ref),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'About',
          children: [
            if (kIsWeb)
              _SettingRow(
                icon: Icons.home_outlined,
                title: 'Landing page',
                subtitle: 'Return to the Blackjack 101 home page',
                onTap: () => ref.read(landingSeenProvider.notifier).exit(),
              ),
            _SettingRow(
              icon: Icons.privacy_tip_outlined,
              title: 'Privacy Policy',
              subtitle: 'How your data is handled',
              onTap: () => openPrivacyPolicy(),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // TODO: remove (or gate behind kDebugMode) before App Store release.
        _SectionCard(
          title: 'Developer',
          children: [
            _SettingRow(
              icon: Icons.bug_report_outlined,
              title: 'Reset purchases',
              subtitle: ref.watch(entitlementsProvider).isPremium
                  ? 'Pro active — tap to lock everything again'
                  : 'No purchases to reset',
              onTap: () => _confirm(
                context,
                title: 'Reset purchases?',
                message:
                    'Locks Pro and clears unlocked themes so you can re-test the locked states. '
                    'Signs out of RevenueCat locally — your real purchase is not deleted and '
                    'returns when you sign in again.',
                confirmLabel: 'Reset',
                onConfirm: () async {
                  ref.read(entitlementsProvider.notifier).resetForDebug();
                  await PurchasesService.debugResetIdentity();
                  await ref.read(proStatusProvider.notifier).refresh();
                },
              ),
            ),
            _SettingRow(
              icon: Icons.restart_alt,
              title: 'Reset onboarding',
              subtitle: 'Relaunch the first-run intro and re-arm review prompts',
              onTap: () {
                ref.read(reviewPromptProvider.notifier).reset();
                ref.read(onboardingSeenProvider.notifier).reset();
              },
            ),
            _SettingRow(
              icon: Icons.emoji_events_outlined,
              title: 'Reset achievements',
              subtitle: 'Lock every badge again to re-test unlocks',
              onTap: () => _confirm(
                context,
                title: 'Reset achievements?',
                message:
                    'Locks every earned badge so unlock toasts can fire again. '
                    'The next qualifying hand re-earns them.',
                confirmLabel: 'Reset',
                onConfirm: () => ref.read(achievementsProvider.notifier).reset(),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Two-sided referral detail, shown in a modal sheet from the Account list:
/// the user's invite code (share/copy), how many friends have joined, and —
/// until they've redeemed one — an entry to enter a friend's code. Rewards (a
/// free card back each side) are granted by [ReferralController].
class _InviteFriendsSheet extends ConsumerStatefulWidget {
  const _InviteFriendsSheet();

  @override
  ConsumerState<_InviteFriendsSheet> createState() => _InviteFriendsSheetState();
}

class _InviteFriendsSheetState extends ConsumerState<_InviteFriendsSheet> {
  bool _copied = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(referralProvider.notifier).refresh());
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(appearanceProvider);
    final r = ref.watch(referralProvider);
    final canUnlock = ref.watch(entitlementsProvider).hasUnlockableCardBack;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          canUnlock
              ? 'Share your code. Your friend unlocks a free card back when they '
                  'redeem it — and you unlock one on your first invite.'
              : 'Share your code. Your friend unlocks a free card back when they '
                  'redeem it. (You already own every card back.)',
          style: const TextStyle(
              color: AppTokens.textSecondary, fontSize: 13, height: 1.45),
        ),
        const SizedBox(height: 18),
        if (r.code == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
                child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2))),
          )
        else ...[
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _copy(r.code!),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: _tileBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.feltBorder),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(r.code!,
                        style: TextStyle(
                            color: theme.goldLight,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 3)),
                  ),
                  Icon(_copied ? Icons.check_rounded : Icons.copy,
                      size: 18,
                      color: _copied
                          ? const Color(0xFF6EE7B7)
                          : AppTokens.textSecondary),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => _share(r.code!),
              child: const Text('Share invite'),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(Icons.people_outline, size: 16, color: theme.goldLight),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  r.referralCount == 0
                      ? 'No friends have joined yet'
                      : '${r.referralCount} friend${r.referralCount == 1 ? '' : 's'} joined',
                  style: const TextStyle(
                      color: AppTokens.textSecondary, fontSize: 13),
                ),
              ),
            ],
          ),
          if (!r.hasRedeemed) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _showRedeem,
                child: const Text('Have an invite code?'),
              ),
            ),
          ],
        ],
      ],
    );
  }

  void _copy(String code) {
    selectionHaptic();
    Analytics.inviteCodeCopied();
    Clipboard.setData(ClipboardData(text: code));
    // The sheet covers a snackbar, so confirm the copy inline. It stays checked
    // for the life of the sheet (state resets when it's reopened).
    setState(() => _copied = true);
  }

  Future<void> _share(String code) async {
    final link = '$kAppShareUrl/?ref=$code';
    final message = 'Learn blackjack strategy with me on Blackjack 101 🃏 '
        'Use my invite code $code or tap $link';
    Analytics.inviteShared();
    try {
      await Share.share(message);
    } catch (_) {
      // Desktop browsers often lack the Web Share sheet — copy instead so the
      // button always does something.
      await Clipboard.setData(ClipboardData(text: message));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        width: _snackWidth(context),
        behavior: SnackBarBehavior.floating,
        content: const Text('Invite link copied to clipboard'),
      ));
    }
  }

  void _showRedeem() {
    final ctrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: const Text('Enter invite code'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(hintText: 'e.g. AB3K9P'),
        ),
        actions: [
          TextButton(
              onPressed: withHaptic(() => Navigator.pop(dctx)),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: withHaptic(() {
              final code = ctrl.text.trim();
              Navigator.pop(dctx);
              if (code.isNotEmpty) _redeem(code);
            }),
            child: const Text('Redeem'),
          ),
        ],
      ),
    );
  }

  Future<void> _redeem(String code) async {
    final res = await ref.read(referralProvider.notifier).redeem(code);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(_redeemMessage(res.outcome, res.rewarded))));
  }

  String _redeemMessage(ReferralRedeemOutcome o, bool rewarded) => switch (o) {
        ReferralRedeemOutcome.success => rewarded
            ? 'Code redeemed — a free card back is unlocked! 🃏'
            : 'Invite code redeemed — thanks for joining! 🃏',
        ReferralRedeemOutcome.invalid => "That code doesn't exist.",
        ReferralRedeemOutcome.ownCode => "You can't redeem your own code.",
        ReferralRedeemOutcome.already => "You've already redeemed an invite code.",
        ReferralRedeemOutcome.error => 'Something went wrong — try again.',
      };
}

/// Opens the Invite Friends detail sheet. Public so cosmetic surfaces (Shop,
/// Customize) can hook into the referral program right where players browse the
/// card backs an invite can unlock.
void openInviteFriends(BuildContext context) =>
    _showSheet(context, title: 'Invite friends', child: const _InviteFriendsSheet());

/// Tappable banner promoting the referral program, for cosmetic screens. Hidden
/// for guests (no code yet) and Pro users (who already own every card back).
class InviteFriendsBanner extends ConsumerWidget {
  const InviteFriendsBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(authStateProvider).value != null;
    final ent = ref.watch(entitlementsProvider);
    // Only pitch the reward where it's real — hide once every back is owned.
    if (!signedIn || !ent.hasUnlockableCardBack) return const SizedBox.shrink();
    final theme = ref.watch(appearanceProvider);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: theme.gold.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            selectionHaptic();
            openInviteFriends(context);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: theme.gold.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.card_giftcard_outlined,
                      size: 20, color: theme.goldLight),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Invite friends',
                          style: TextStyle(
                              color: theme.goldLight,
                              fontSize: 14,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      const Text('Unlock a free card back when they join',
                          style: TextStyle(
                              color: AppTokens.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, size: 20, color: theme.goldLight),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _SectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 14, 8),
      decoration: BoxDecoration(
        color: _cardBg,
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
          ...children,
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool danger;
  const _SettingRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final fg = danger ? const Color(0xFFFC8181) : AppTokens.textPrimary;
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _tileBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: fg),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(color: fg, fontSize: 14, fontWeight: FontWeight.w600)),
                if (subtitle != null) ...[
                  const SizedBox(height: 1),
                  Text(subtitle!,
                      style: const TextStyle(color: AppTokens.textSecondary, fontSize: 12)),
                ],
              ],
            ),
          ),
          trailing ?? const Icon(Icons.chevron_right, color: AppTokens.textSecondary, size: 20),
        ],
      ),
    );
    if (onTap == null) return row;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: withHaptic(onTap),
      child: row,
    );
  }
}

class _SheetShell extends ConsumerWidget {
  final String title;
  final Widget child;
  const _SheetShell({required this.title, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(appearanceProvider);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        decoration: BoxDecoration(
          color: theme.feltDark,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(
            top: BorderSide(color: theme.feltBorder),
            left: BorderSide(color: theme.feltBorder),
            right: BorderSide(color: theme.feltBorder),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTokens.textSecondary.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.only(left: 2, bottom: 12),
                  child: Text(title,
                      style: const TextStyle(
                          color: AppTokens.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                Flexible(child: SingleChildScrollView(child: child)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SheetOption extends StatelessWidget {
  final Widget? leading;
  final double leadingWidth;
  final String title;
  final String? subtitle;
  final IconData? subtitleIcon;
  final bool owned;
  final bool selected;
  final VoidCallback onTap;
  final AppearanceTheme theme;
  const _SheetOption({
    this.leading,
    this.leadingWidth = 40,
    required this.title,
    this.subtitle,
    this.subtitleIcon,
    this.owned = false,
    required this.selected,
    required this.onTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: withHaptic(onTap),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? theme.gold.withValues(alpha: 0.12) : _cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? theme.gold : const Color(0x18FFFFFF),
            width: 1.5,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (leading != null) ...[
              SizedBox(width: leadingWidth, height: 40, child: Center(child: leading!)),
              const SizedBox(width: 14),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          color: selected ? theme.goldLight : AppTokens.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.bold)),
                  if (owned) ...[
                    const SizedBox(height: 5),
                    ownedTag(theme),
                  ] else if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (subtitleIcon != null) ...[
                          Icon(subtitleIcon,
                              size: 13, color: AppTokens.textSecondary),
                          const SizedBox(width: 5),
                        ],
                        Flexible(
                          child: Text(subtitle!,
                              style: const TextStyle(
                                  color: AppTokens.textSecondary,
                                  fontSize: 12,
                                  height: 1.4)),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, anim) =>
                  ScaleTransition(scale: anim, child: FadeTransition(opacity: anim, child: child)),
              child: Icon(selected ? Icons.check_circle : Icons.circle_outlined,
                  key: ValueKey(selected),
                  color: selected ? theme.gold : AppTokens.textSecondary,
                  size: 20),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-screen cosmetics customizer, switching between Table / Cards / Chips.
class _CustomizeScreen extends StatefulWidget {
  const _CustomizeScreen();

  @override
  State<_CustomizeScreen> createState() => _CustomizeScreenState();
}

class _CustomizeScreenState extends State<_CustomizeScreen> {
  int _tab = 0;
  int _dir = 1; // +1 moving to a later tab, -1 earlier — drives slide direction.
  static const _labels = ['Table', 'Cards', 'Chips', 'Decks'];

  @override
  Widget build(BuildContext context) {
    return Consumer(builder: (context, ref, _) {
      final theme = ref.watch(appearanceProvider);
      final bottomInset = MediaQuery.of(context).padding.bottom;
      return Scaffold(
        backgroundColor: theme.feltDark,
        appBar: AppBar(
          backgroundColor: theme.feltDark,
          surfaceTintColor: Colors.transparent,
          foregroundColor: AppTokens.textPrimary,
          elevation: 0,
          title: Text('Customize',
              style: TextStyle(color: theme.gold, fontWeight: FontWeight.bold)),
        ),
        body: SafeArea(
          top: false,
          bottom: false,
          child: ListView(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 40 + bottomInset),
            children: [
              const InviteFriendsBanner(),
              AppSegmentedTabs(
                labels: _labels,
                current: _tab,
                onSelect: (i) => setState(() {
                  _dir = i > _tab ? 1 : -1;
                  _tab = i;
                }),
              ),
              const SizedBox(height: 16),
              SlideTabSwitcher(
                tabIndex: _tab,
                dir: _dir,
                child: _tab == 0
                    ? const _SkinSheet()
                    : _tab == 1
                        ? const _CardBackSheet()
                        : _tab == 2
                            ? const _ChipStyleSheet()
                            : const _DeckSheet(),
              ),
            ],
          ),
        ),
      );
    });
  }
}

class _SkinSheet extends ConsumerWidget {
  const _SkinSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(appearanceProvider);
    final ent = ref.watch(entitlementsProvider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final p in appearancePresets)
          () {
            final unlocked = ent.isCosmeticUnlocked(p.id);
            final price = productForCosmeticId(p.id)?.priceLabel;
            return _SheetOption(
              theme: theme,
              selected: p.id == ref.watch(tableThemeProvider).id,
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: p.felt,
                  shape: BoxShape.circle,
                  border: Border.all(color: p.gold, width: 2),
                ),
              ),
              title: p.name,
              owned: unlocked && productForCosmeticId(p.id) != null,
              subtitle: unlocked ? null : 'Locked${price != null ? ' · $price' : ''}',
              subtitleIcon: unlocked ? null : Icons.lock_outline,
              onTap: () => showCosmeticPreview(context,
                  kind: CosmeticKind.theme, cosmeticId: p.id, name: p.name),
            );
          }(),
      ],
    );
  }
}

class _CardBackSheet extends ConsumerWidget {
  const _CardBackSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(appearanceProvider);
    final ent = ref.watch(entitlementsProvider);
    final selectedId = ref.watch(cardBackProvider).id;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final b in cardBackPresets)
          () {
            final unlocked = ent.isCosmeticUnlocked(b.id);
            final price = productForCosmeticId(b.id)?.priceLabel;
            return _SheetOption(
              theme: theme,
              selected: b.id == selectedId,
              leading: PlayingCardView(
                card: const bj.Card(rank: 'A', suit: '♠', faceDown: true),
                theme: theme.copyWith(cardBack: b),
                width: 28,
              ),
              title: b.name,
              owned: unlocked && productForCosmeticId(b.id) != null,
              subtitle: unlocked ? null : 'Locked${price != null ? ' · $price' : ''}',
              subtitleIcon: unlocked ? null : Icons.lock_outline,
              onTap: () => showCosmeticPreview(context,
                  kind: CosmeticKind.cardBack, cosmeticId: b.id, name: b.name),
            );
          }(),
      ],
    );
  }
}

class _ChipStyleSheet extends ConsumerWidget {
  const _ChipStyleSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(appearanceProvider);
    final ent = ref.watch(entitlementsProvider);
    final selectedId = ref.watch(chipStyleProvider).id;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final c in chipStylePresets)
          () {
            final unlocked = ent.isCosmeticUnlocked(c.id);
            final price = productForCosmeticId(c.id)?.priceLabel;
            return _SheetOption(
              theme: theme,
              selected: c.id == selectedId,
              leadingWidth: 84,
              leading: ChipStripPreview(theme: theme.copyWith(chipStyle: c), size: 30),
              title: c.name,
              owned: unlocked && productForCosmeticId(c.id) != null,
              subtitle: unlocked ? null : 'Locked${price != null ? ' · $price' : ''}',
              subtitleIcon: unlocked ? null : Icons.lock_outline,
              onTap: () => showCosmeticPreview(context,
                  kind: CosmeticKind.chipStyle, cosmeticId: c.id, name: c.name),
            );
          }(),
      ],
    );
  }
}

class _DeckSheet extends ConsumerWidget {
  const _DeckSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(appearanceProvider);
    final ent = ref.watch(entitlementsProvider);
    final selectedId = ref.watch(cardDeckProvider).id;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final d in cardDeckPresets)
          () {
            final unlocked = ent.isCosmeticUnlocked(d.id);
            final price = productForCosmeticId(d.id)?.priceLabel;
            return _SheetOption(
              theme: theme,
              selected: d.id == selectedId,
              leading: PlayingCardView(
                card: const bj.Card(rank: 'A', suit: '♠'),
                theme: theme.copyWith(deck: d),
                width: 28,
                showShadow: false,
              ),
              title: d.name,
              owned: unlocked && productForCosmeticId(d.id) != null,
              subtitle: unlocked ? null : 'Locked${price != null ? ' · $price' : ''}',
              subtitleIcon: unlocked ? null : Icons.lock_outline,
              onTap: () => showCosmeticPreview(context,
                  kind: CosmeticKind.deck, cosmeticId: d.id, name: d.name),
            );
          }(),
      ],
    );
  }
}

class _RuleSetSheet extends ConsumerWidget {
  const _RuleSetSheet();

  static const String _freeRuleSetId = 'vegas-strip';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(appearanceProvider);
    final selectedId = ref.watch(settingsProvider).ruleSet.id;
    final locked = ref.watch(gameProvider).hasDealtInSession;
    final isPremium = ref.watch(entitlementsProvider).isPremium;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final r in rulePresets)
          () {
            final premiumLocked = r.id != _freeRuleSetId && !isPremium;
            return _SheetOption(
              theme: theme,
              selected: r.id == selectedId,
              title: r.name,
              subtitle: premiumLocked
                  ? '${ruleSetDescription(r)}  ·  Pro'
                  : ruleSetDescription(r),
              subtitleIcon: premiumLocked ? Icons.lock_outline : null,
              onTap: premiumLocked
                  ? () => openGoPro(context)
                  : () => _select(context, ref, r, selectedId, locked),
            );
          }(),
      ],
    );
  }

  void _select(BuildContext context, WidgetRef ref, RuleSet r, String selectedId, bool locked) {
    if (r.id == selectedId) {
      Navigator.pop(context);
      return;
    }
    if (locked) {
      _confirm(
        context,
        title: 'Switch game mode?',
        message: 'Switching to ${r.name} starts a new session and resets the current hand.',
        confirmLabel: 'Switch',
        onConfirm: () {
          ref.read(settingsProvider.notifier).setRuleSet(r);
          ref.read(gameProvider.notifier).newSession();
          Navigator.pop(context);
        },
      );
    } else {
      ref.read(settingsProvider.notifier).setRuleSet(r);
      Navigator.pop(context);
    }
  }
}

class _DifficultySheet extends ConsumerWidget {
  const _DifficultySheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(appearanceProvider);
    final selected = ref.watch(settingsProvider).difficulty;
    final locked = ref.watch(gameProvider).hasDealtInSession;
    final isPremium = ref.watch(entitlementsProvider).isPremium;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final d in difficultyPresets)
          () {
            final premiumLocked = d != Difficulty.regular && !isPremium;
            return _SheetOption(
              theme: theme,
              selected: d == selected,
              title: difficultyLabel(d),
              subtitle: premiumLocked
                  ? '${difficultyDescription(d)}  ·  Pro'
                  : difficultyDescription(d),
              subtitleIcon: premiumLocked ? Icons.lock_outline : null,
              onTap: premiumLocked
                  ? () => openGoPro(context)
                  : () => _select(context, ref, d, selected, locked),
            );
          }(),
      ],
    );
  }

  void _select(
      BuildContext context, WidgetRef ref, Difficulty d, Difficulty selected, bool locked) {
    if (d == selected) {
      Navigator.pop(context);
      return;
    }
    if (locked) {
      _confirm(
        context,
        title: 'Switch difficulty?',
        message:
            'Switching to ${difficultyLabel(d)} starts a new session and resets the current hand.',
        confirmLabel: 'Switch',
        onConfirm: () {
          ref.read(settingsProvider.notifier).setDifficulty(d);
          ref.read(gameProvider.notifier).newSession();
          Navigator.pop(context);
        },
      );
    } else {
      ref.read(settingsProvider.notifier).setDifficulty(d);
      Navigator.pop(context);
    }
  }
}

class _BankrollSheet extends ConsumerStatefulWidget {
  const _BankrollSheet();

  @override
  ConsumerState<_BankrollSheet> createState() => _BankrollSheetState();
}

class _BankrollSheetState extends ConsumerState<_BankrollSheet> {
  late final TextEditingController _ctrl =
      TextEditingController(text: '${ref.read(settingsProvider).startingBankroll}');
  bool _applyNow = true;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _save() {
    final fallback = ref.read(settingsProvider).startingBankroll;
    final parsed = int.tryParse(_ctrl.text.trim()) ?? fallback;
    ref.read(settingsProvider.notifier).setStartingBankroll(parsed.clamp(1, 1000000).toInt());
    if (_applyNow) {
      ref.read(gameProvider.notifier).resetBankroll();
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Starting bankroll',
            style: TextStyle(color: AppTokens.textSecondary, fontSize: 13)),
        const SizedBox(height: 8),
        TextField(
          controller: _ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(prefixText: '\$ ', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          children: [
            for (final v in [500, 1000, 2500, 5000])
              ActionChip(label: Text('\$$v'), onPressed: () => _ctrl.text = '$v'),
          ],
        ),
        const SizedBox(height: 8),
        CheckboxListTile(
          value: _applyNow,
          onChanged: (v) => setState(() => _applyNow = v ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: const Text('Set my balance to this now',
              style: TextStyle(color: AppTokens.textPrimary, fontSize: 14)),
          subtitle: const Text('Otherwise this only changes future resets',
              style: TextStyle(color: AppTokens.textSecondary, fontSize: 12)),
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: withHaptic(_save),
          child: Text(_applyNow ? 'Save & reset balance' : 'Save starting bankroll'),
        ),
      ],
    );
  }
}
