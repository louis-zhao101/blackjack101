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
import 'ui/screens/splash_screen.dart';
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

class BlackjackApp extends ConsumerStatefulWidget {
  const BlackjackApp({super.key});

  @override
  ConsumerState<BlackjackApp> createState() => _BlackjackAppState();
}

class _BlackjackAppState extends ConsumerState<BlackjackApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Returning to the foreground: re-check RevenueCat so an entitlement that
    // couldn't be fetched earlier (e.g. no network at launch) lights up on its
    // own, without needing a sign-out / sign-in.
    if (state == AppLifecycleState.resumed && PurchasesService.isReady) {
      ref.read(proStatusProvider.notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
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
      if (next.isLoading) return;
      final user = next.value;
      if (user != null && prev?.value?.uid != user.uid) {
        _onLogin(ref, user.uid);
      } else if (user == null) {
        if (prev?.value != null) PurchasesService.logOut();
        // Nothing to load for a guest — lift the splash once its floor elapses.
        ref.read(appReadyProvider.notifier).dataLoaded();
      }
    });

    // Live-adopt cosmetic choices made on other devices. push: false so adopting
    // a cloud value doesn't echo straight back as a new write.
    ref.listen(cosmeticCloudProvider, (_, next) {
      final sel = next.value;
      if (sel == null) return;
      if (sel.appearance != null) {
        ref.read(tableThemeProvider.notifier).setPreset(sel.appearance!, push: false);
      }
      if (sel.cardBack != null) {
        ref.read(cardBackProvider.notifier).setCardBack(sel.cardBack!, push: false);
      }
      if (sel.chipStyle != null) {
        ref.read(chipStyleProvider.notifier).setChipStyle(sel.chipStyle!, push: false);
      }
    });

    // The splash owns its own dismissal: it deals a few cycles, then flies the
    // cards off once the first data load has finished, and only then flips
    // splashDone. Cross-fade whatever comes next so the reveal isn't a hard cut.
    final Widget child;
    if (!ref.watch(splashDoneProvider)) {
      child = const SplashScreen();
    } else if (!ref.watch(onboardingSeenProvider)) {
      child = const OnboardingPage();
    } else {
      final auth = ref.watch(authStateProvider);
      child = auth.when(
        loading: () => const SplashScreen(),
        error: (e, _) => Scaffold(body: Center(child: Text('Auth error: $e'))),
        // The app is playable as a guest; signing in (from the Account tab) only
        // unlocks saving and viewing stats. So always show the shell.
        data: (_) => const AppShell(),
      );
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 650),
      child: KeyedSubtree(key: ValueKey(child.runtimeType), child: child),
    );
  }

  Future<void> _onLogin(WidgetRef ref, String uid) async {
    try {
      await _loadUserIntoApp(ref, uid);
    } catch (_) {
      // Launch into the app even if the initial cloud load fails; the sync queue
      // retries writes and a foreground refresh can pull data later.
    } finally {
      ref.read(appReadyProvider.notifier).dataLoaded();
    }
  }

  Future<void> _loadUserIntoApp(WidgetRef ref, String uid) async {
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
    // (The live cosmeticCloudProvider listener also adopts these; both pass
    // push: false so neither echoes the cloud value back as a fresh write.)
    if (data.appearance != null) {
      ref.read(tableThemeProvider.notifier).setPreset(data.appearance!, push: false);
    }
    if (data.cardBack != null) {
      ref.read(cardBackProvider.notifier).setCardBack(data.cardBack!, push: false);
    }
    if (data.chipStyle != null) {
      ref.read(chipStyleProvider.notifier).setChipStyle(data.chipStyle!, push: false);
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
