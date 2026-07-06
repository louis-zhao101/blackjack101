import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show kDebugMode, kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';
import 'services/purchases_service.dart';
import 'state/achievements_provider.dart';
import 'state/app_providers.dart';
import 'state/appearance_provider.dart';
import 'state/auth_provider.dart';
import 'state/game_provider.dart';
import 'state/learn_provider.dart';
import 'state/stats_provider.dart';
import 'state/store_provider.dart';
import 'ui/app_shell.dart';
import 'ui/screens/onboarding_page.dart';
import 'ui/theme/appearance.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await PurchasesService.configure();
  // Android emulators have no Play Integrity, so in debug let configured test
  // numbers bypass verification. iOS uses the reCAPTCHA fallback instead (the
  // disable flag doesn't attach a client identifier on iOS). No effect on
  // release or web builds.
  if (kDebugMode && !kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    await FirebaseAuth.instance.setSettings(appVerificationDisabledForTesting: true);
  }
  const useEmulator = bool.fromEnvironment('USE_EMULATOR');
  if (useEmulator) {
    await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
  }
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const BlackjackApp(),
    ),
  );
}

class BlackjackApp extends ConsumerWidget {
  const BlackjackApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appearance = ref.watch(appearanceProvider);
    return MaterialApp(
      title: 'Blackjack 101',
      theme: appThemeData(appearance),
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        dragDevices: {
          PointerDeviceKind.touch,
          PointerDeviceKind.mouse,
          PointerDeviceKind.trackpad,
          PointerDeviceKind.stylus,
        },
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
      } else if (user == null && prev?.value != null) {
        PurchasesService.logOut();
      }
    });

    if (!ref.watch(onboardingSeenProvider)) return const OnboardingPage();

    final auth = ref.watch(authStateProvider);
    return auth.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Auth error: $e'))),
      // The app is playable as a guest; signing in (from the Account tab) only
      // unlocks saving and viewing stats. So always show the shell.
      data: (_) => const AppShell(),
    );
  }

  Future<void> _onLogin(WidgetRef ref, String uid) async {
    await PurchasesService.logIn(uid);
    ref.read(proStatusProvider.notifier).refresh();
    final data = await ref.read(firestoreSyncProvider).loadUserData(uid);
    final sync = ref.read(syncQueueProvider.notifier);

    if (data.sessions.isNotEmpty) {
      ref.read(statsProvider.notifier).loadFromCloud(data.sessions);
    } else {
      final local = ref.read(statsProvider);
      for (final s in [
        ...local.sessions,
        if (local.currentSession != null) local.currentSession!,
      ]) {
        sync.session(uid, s);
      }
    }

    if (data.bankroll != null) {
      ref.read(gameProvider.notifier).loadBankroll(data.bankroll!);
    } else {
      sync.profile(uid, ref.read(gameProvider).game.bankroll);
    }

    if (data.ownedProducts.isNotEmpty) {
      ref.read(entitlementsProvider.notifier).mergeOwnedFromCloud(data.ownedProducts);
    } else {
      final localCosmetics =
          ref.read(entitlementsProvider).owned.difference({kLifetimeProductId});
      if (localCosmetics.isNotEmpty) sync.ownedProducts(uid, localCosmetics);
    }

    if (data.achievements.isNotEmpty) {
      ref.read(achievementsProvider.notifier).mergeFromCloud(data.achievements);
    } else {
      final localAchievements = ref.read(achievementsProvider);
      if (localAchievements.isNotEmpty) sync.achievements(uid, localAchievements);
    }

    if (data.strategyCells.isNotEmpty) {
      ref.read(strategyStatsProvider.notifier).mergeFromCloud(data.strategyCells);
    } else {
      final localCells = ref.read(strategyStatsProvider);
      if (localCells.isNotEmpty) sync.strategyCells(uid, localCells);
    }

    if (data.drill != null) {
      ref.read(drillStatsProvider.notifier).mergeFromCloud(data.drill!);
    } else {
      final d = ref.read(drillStatsProvider);
      if (d.total > 0 || d.attempted.isNotEmpty) {
        sync.drill(uid,
            total: d.total,
            correct: d.correct,
            bestStreak: d.bestStreak,
            attempted: d.attempted,
            recent: d.recent);
      }
    }

    if (data.learnProgress.isNotEmpty) {
      ref.read(learnProvider.notifier).mergeFromCloud(data.learnProgress);
    } else {
      final localLessons = ref.read(learnProvider);
      if (localLessons.isNotEmpty) sync.learnProgress(uid, localLessons);
    }

    // Cosmetic selection: adopt cloud choices where present, else back up local.
    if (data.appearance != null) {
      ref.read(tableThemeProvider.notifier).setPreset(data.appearance!);
    }
    if (data.cardBack != null) {
      ref.read(cardBackProvider.notifier).setCardBack(data.cardBack!);
    }
    if (data.chipStyle != null) {
      ref.read(chipStyleProvider.notifier).setChipStyle(data.chipStyle!);
    }
    if (data.appearance == null && data.cardBack == null && data.chipStyle == null) {
      sync.cosmeticSelection(uid,
          appearance: ref.read(tableThemeProvider).id,
          cardBack: ref.read(cardBackProvider).id,
          chipStyle: ref.read(chipStyleProvider).id);
    }

    ref.read(achievementsProvider.notifier).evaluate();
  }
}
