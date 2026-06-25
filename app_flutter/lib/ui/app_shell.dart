import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../engine/variants.dart';
import '../state/app_providers.dart';
import '../state/appearance_provider.dart';
import '../state/auth_provider.dart';
import '../state/game_provider.dart';
import '../state/settings_provider.dart';
import '../state/stats_provider.dart';
import 'auth_screen.dart';
import 'screens/learn_page.dart';
import 'screens/play_page.dart';
import 'screens/stats_page.dart';
import 'theme/appearance.dart';
import 'widgets/game_button.dart';

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
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(appearanceProvider);

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
                  tab: _tab,
                  showNav: wide,
                  onSelectTab: (i) => setState(() => _tab = i),
                ),
                Expanded(
                  child: IndexedStack(
                    index: _tab,
                    children: const [PlayPage(), LearnPage(), StatsPage(), AccountPage()],
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar:
              wide ? null : _BottomNav(theme: theme, tab: _tab, onSelect: (i) => setState(() => _tab = i)),
        );
      },
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
                  child: Text(
                    '♠ Blackjack 101 ♥',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: theme.gold, fontSize: 17, fontWeight: FontWeight.bold),
                  ),
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
        ],
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
    return NavigationBarTheme(
      data: NavigationBarThemeData(
        backgroundColor: theme.feltDark,
        indicatorColor: theme.gold.withValues(alpha: 0.22),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected) ? FontWeight.bold : FontWeight.normal,
            color: states.contains(WidgetState.selected) ? theme.gold : AppTokens.textSecondary,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? theme.gold : AppTokens.textSecondary,
          ),
        ),
      ),
      child: NavigationBar(
        height: 64,
        selectedIndex: tab,
        onDestinationSelected: (i) {
          selectionHaptic();
          onSelect(i);
        },
        destinations: [
          for (var i = 0; i < _navTitles.length; i++)
            NavigationDestination(
              icon: Icon(_navIcons[i]),
              selectedIcon: Icon(_navIconsSelected[i]),
              label: _navTitles[i],
            ),
        ],
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
    final signedIn = ref.watch(authStateProvider).value != null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        const _ProfileCard(),
        const SizedBox(height: 20),
        _SectionCard(
          title: 'General',
          children: [
            _SettingRow(
              icon: Icons.palette_outlined,
              title: 'Table theme',
              subtitle: theme.name,
              onTap: () => _showSheet(context, title: 'Table theme', child: const _SkinSheet()),
            ),
            _SettingRow(
              icon: Icons.casino_outlined,
              title: 'Game mode',
              subtitle: settings.ruleSet.name,
              onTap: () => _showSheet(context, title: 'Game mode', child: const _RuleSetSheet()),
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
          ],
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Data',
          children: [
            _SettingRow(
              icon: Icons.delete_sweep_outlined,
              title: 'Clear stats history',
              subtitle: 'Remove all saved sessions',
              onTap: () => _confirm(
                context,
                title: 'Clear all session history?',
                message: 'This removes all saved sessions. This cannot be undone.',
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
      ],
    );
  }
}

class _ProfileCard extends ConsumerWidget {
  const _ProfileCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(appearanceProvider);
    final user = ref.watch(authStateProvider).value;
    final phone = user?.phoneNumber ?? '';
    final signedIn = user != null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: theme.gold.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.person, color: theme.gold, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(signedIn ? 'Signed in' : 'Guest',
                    style: const TextStyle(
                        color: AppTokens.textPrimary, fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(
                  signedIn
                      ? (phone.isNotEmpty ? phone : 'Synced to cloud')
                      : 'Sign in to save & view stats',
                  style: const TextStyle(color: AppTokens.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: withHaptic(() => signedIn
                ? ref.read(phoneAuthControllerProvider.notifier).signOut()
                : showSignInSheet(context)),
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: _tileBg,
                shape: BoxShape.circle,
                border: Border.all(color: theme.feltBorder),
              ),
              child: Icon(signedIn ? Icons.logout : Icons.login,
                  color: AppTokens.textPrimary, size: 20),
            ),
          ),
        ],
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
  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;
  final AppearanceTheme theme;
  const _SheetOption({
    this.leading,
    required this.title,
    this.subtitle,
    required this.selected,
    required this.onTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: withHaptic(onTap),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? theme.gold.withValues(alpha: 0.12) : _cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? theme.gold : const Color(0x18FFFFFF),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 14)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          color: selected ? theme.goldLight : AppTokens.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.bold)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(subtitle!,
                        style: const TextStyle(
                            color: AppTokens.textSecondary, fontSize: 12, height: 1.4)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(selected ? Icons.check_circle : Icons.circle_outlined,
                color: selected ? theme.gold : AppTokens.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }
}

class _SkinSheet extends ConsumerWidget {
  const _SkinSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(appearanceProvider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final p in appearancePresets)
          _SheetOption(
            theme: theme,
            selected: p.id == theme.id,
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
            onTap: () {
              ref.read(appearanceProvider.notifier).setPreset(p.id);
              Navigator.pop(context);
            },
          ),
      ],
    );
  }
}

class _RuleSetSheet extends ConsumerWidget {
  const _RuleSetSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(appearanceProvider);
    final selectedId = ref.watch(settingsProvider).ruleSet.id;
    final locked = ref.watch(gameProvider).hasDealtInSession;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final r in rulePresets)
          _SheetOption(
            theme: theme,
            selected: r.id == selectedId,
            title: r.name,
            subtitle: ruleSetDescription(r),
            onTap: () => _select(context, ref, r, selectedId, locked),
          ),
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

class _BankrollSheet extends ConsumerStatefulWidget {
  const _BankrollSheet();

  @override
  ConsumerState<_BankrollSheet> createState() => _BankrollSheetState();
}

class _BankrollSheetState extends ConsumerState<_BankrollSheet> {
  late final TextEditingController _ctrl =
      TextEditingController(text: '${ref.read(settingsProvider).startingBankroll}');

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _save() {
    final fallback = ref.read(settingsProvider).startingBankroll;
    final parsed = int.tryParse(_ctrl.text.trim()) ?? fallback;
    ref.read(settingsProvider.notifier).setStartingBankroll(parsed.clamp(1, 1000000).toInt());
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(appearanceProvider);
    final start = ref.watch(settingsProvider).startingBankroll;
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
        const SizedBox(height: 16),
        FilledButton(
          onPressed: withHaptic(_save),
          child: const Text('Save starting bankroll'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: withHaptic(() {
            ref.read(gameProvider.notifier).resetBankroll();
            Navigator.pop(context);
          }),
          style: OutlinedButton.styleFrom(side: BorderSide(color: theme.feltBorder)),
          child: Text('Reset balance to \$$start'),
        ),
      ],
    );
  }
}
