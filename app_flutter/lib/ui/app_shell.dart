import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/appearance_provider.dart';
import '../state/auth_provider.dart';
import 'screens/learn_page.dart';
import 'screens/play_page.dart';
import 'screens/stats_page.dart';
import 'theme/appearance.dart';
import 'widgets/game_button.dart';

const _navTitles = ['Play', 'Learn', 'Stats'];
const _navIcons = [Icons.casino_outlined, Icons.menu_book_outlined, Icons.insights_outlined];
const _navIconsSelected = [Icons.casino, Icons.menu_book, Icons.insights];

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
    final phone = ref.watch(authServiceProvider).currentUser?.phoneNumber ?? '';

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
                  phone: phone,
                  onSelectTab: (i) => setState(() => _tab = i),
                  onSelectSkin: (id) => ref.read(appearanceProvider.notifier).setPreset(id),
                  onSignOut: () => ref.read(phoneAuthControllerProvider.notifier).signOut(),
                ),
                Expanded(
                  child: IndexedStack(
                    index: _tab,
                    children: const [PlayPage(), LearnPage(), StatsPage()],
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
  final String phone;
  final ValueChanged<int> onSelectTab;
  final ValueChanged<String> onSelectSkin;
  final VoidCallback onSignOut;

  const _Header({
    required this.theme,
    required this.tab,
    required this.showNav,
    required this.phone,
    required this.onSelectTab,
    required this.onSelectSkin,
    required this.onSignOut,
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
          Flexible(
            child: Text(
              '♠ Blackjack 101 ♥',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: theme.gold, fontSize: 17, fontWeight: FontWeight.bold),
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
          const Spacer(),
          PopupMenuButton<String>(
            tooltip: 'Table skin',
            icon: const Icon(Icons.palette_outlined, color: AppTokens.textSecondary),
            onSelected: (id) {
              HapticFeedback.selectionClick();
              onSelectSkin(id);
            },
            itemBuilder: (_) => [
              for (final p in appearancePresets)
                PopupMenuItem(
                  value: p.id,
                  child: Row(
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: p.felt,
                          shape: BoxShape.circle,
                          border: Border.all(color: p.gold),
                        ),
                      ),
                      Text(p.name),
                    ],
                  ),
                ),
            ],
          ),
          PopupMenuButton<String>(
            tooltip: 'Account',
            icon: const Icon(Icons.account_circle_outlined, color: AppTokens.textSecondary),
            onSelected: (v) {
              HapticFeedback.selectionClick();
              if (v == 'signout') onSignOut();
            },
            itemBuilder: (_) => [
              if (phone.isNotEmpty) PopupMenuItem(enabled: false, child: Text(phone)),
              const PopupMenuItem(value: 'signout', child: Text('Sign out')),
            ],
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
          HapticFeedback.selectionClick();
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
