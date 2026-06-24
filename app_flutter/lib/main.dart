import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show kDebugMode, kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';
import 'state/app_providers.dart';
import 'state/auth_provider.dart';
import 'state/game_provider.dart';
import 'state/stats_provider.dart';
import 'ui/app_shell.dart';
import 'ui/auth_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Android emulators have no Play Integrity, so in debug let configured test
  // numbers bypass verification. iOS uses the reCAPTCHA fallback instead (the
  // disable flag doesn't attach a client identifier on iOS). No effect on
  // release or web builds.
  if (kDebugMode && !kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    await FirebaseAuth.instance.setSettings(appVerificationDisabledForTesting: true);
  }
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
      data: (user) => user == null ? const AuthScreen() : const AppShell(),
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
