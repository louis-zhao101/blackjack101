import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/appearance_provider.dart';
import '../state/auth_provider.dart';
import 'screens/learn_page.dart';
import 'screens/play_page.dart';
import 'screens/stats_page.dart';
import 'theme/appearance.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _tab = 0;
  static const _titles = ['Play', 'Learn', 'Stats'];

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(appearanceProvider);
    final phone = ref.watch(authServiceProvider).currentUser?.phoneNumber ?? '';

    return Scaffold(
      backgroundColor: theme.feltDark,
      body: SafeArea(
        child: Column(
          children: [
            _Header(
              theme: theme,
              tab: _tab,
              titles: _titles,
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
    );
  }
}

class _Header extends StatelessWidget {
  final AppearanceTheme theme;
  final int tab;
  final List<String> titles;
  final String phone;
  final ValueChanged<int> onSelectTab;
  final ValueChanged<String> onSelectSkin;
  final VoidCallback onSignOut;

  const _Header({
    required this.theme,
    required this.tab,
    required this.titles,
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
          Text('♠ Blackjack 101 ♥',
              style: TextStyle(
                  color: theme.gold, fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(width: 16),
          for (var i = 0; i < titles.length; i++)
            TextButton(
              onPressed: () => onSelectTab(i),
              child: Text(
                titles[i],
                style: TextStyle(
                  color: i == tab ? theme.gold : AppTokens.textSecondary,
                  fontWeight: i == tab ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          const Spacer(),
          PopupMenuButton<String>(
            tooltip: 'Table skin',
            icon: Icon(Icons.palette, color: AppTokens.textSecondary),
            onSelected: onSelectSkin,
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
            icon: Icon(Icons.account_circle, color: AppTokens.textSecondary),
            onSelected: (v) {
              if (v == 'signout') onSignOut();
            },
            itemBuilder: (_) => [
              if (phone.isNotEmpty)
                PopupMenuItem(enabled: false, child: Text(phone)),
              const PopupMenuItem(value: 'signout', child: Text('Sign out')),
            ],
          ),
        ],
      ),
    );
  }
}
