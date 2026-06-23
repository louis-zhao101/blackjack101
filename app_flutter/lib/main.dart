import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';
import 'state/app_providers.dart';
import 'state/auth_provider.dart';
import 'state/game_provider.dart';
import 'state/stats_provider.dart';
import 'ui/auth_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const BlackjackApp(),
    ),
  );
}

class BlackjackApp extends StatelessWidget {
  const BlackjackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Blackjack 101',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1a4731),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}

/// Routes between the signed-in app and the phone sign-in flow, and runs the
/// login/logout data sync (mirrors App.tsx). The signed-in view is a
/// placeholder until Phase 4 brings the real game UI.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(authStateProvider, (prev, next) {
      final user = next.value;
      if (user != null && prev?.value?.uid != user.uid) {
        _onLogin(ref, user.uid);
      }
    });

    final auth = ref.watch(authStateProvider);
    return auth.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Auth error: $e'))),
      data: (user) => user == null ? const AuthScreen() : _SignedInPlaceholder(user),
    );
  }

  Future<void> _onLogin(WidgetRef ref, String uid) async {
    final sync = ref.read(firestoreSyncProvider);
    final data = await sync.loadUserData(uid);

    if (data.sessions.isNotEmpty) {
      ref.read(statsProvider.notifier).loadFromCloud(data.sessions);
    } else {
      final local = ref.read(statsProvider);
      for (final s in [
        ...local.sessions,
        if (local.currentSession != null) local.currentSession!,
      ]) {
        sync.upsertSession(uid, s);
      }
    }

    if (data.bankroll != null) {
      ref.read(gameProvider.notifier).loadBankroll(data.bankroll!);
    } else {
      sync.upsertProfile(uid, ref.read(gameProvider).game.bankroll);
    }
  }
}

class _SignedInPlaceholder extends ConsumerWidget {
  final User user;
  const _SignedInPlaceholder(this.user);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(statsProvider);
    final game = ref.watch(gameProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Blackjack 101'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(phoneAuthControllerProvider.notifier).signOut(),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, size: 48, color: Colors.greenAccent),
            const SizedBox(height: 12),
            Text('Signed in as ${user.phoneNumber ?? user.uid}'),
            const SizedBox(height: 8),
            Text('Bankroll: \$${game.game.bankroll}'),
            Text('Sessions: ${stats.sessions.length}'
                '${stats.currentSession != null ? ' (+1 live)' : ''}'),
            const SizedBox(height: 8),
            const Text('Phase 4 will render the game here.'),
          ],
        ),
      ),
    );
  }
}
