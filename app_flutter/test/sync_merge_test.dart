import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:blackjack101/services/firebase_auth_service.dart';
import 'package:blackjack101/state/app_providers.dart';
import 'package:blackjack101/state/auth_provider.dart';
import 'package:blackjack101/state/learn_provider.dart';
import 'package:blackjack101/state/stats_provider.dart';

/// A signed-out auth service so the controllers' cloud-sync path is skipped
/// (uid == null) and no Firebase is ever touched — we only exercise the merge.
class _SignedOutAuth extends Fake implements FirebaseAuth {
  @override
  User? get currentUser => null;
}

Future<ProviderContainer> makeContainer(Map<String, Object> initialPrefs) async {
  SharedPreferences.setMockInitialValues(initialPrefs);
  final prefs = await SharedPreferences.getInstance();
  return ProviderContainer(overrides: [
    sharedPreferencesProvider.overrideWithValue(prefs),
    authServiceProvider.overrideWithValue(FirebaseAuthService(_SignedOutAuth())),
  ]);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('strategy cell merge', () {
    test('keeps the higher play count and never regresses', () async {
      final c = await makeContainer({
        'bj101-strategy-cells':
            jsonEncode({'hard|16|10': [40, 50], 'soft|18|6': [5, 5]}),
      });
      addTearDown(c.dispose);
      final ctrl = c.read(strategyStatsProvider.notifier);

      // Cloud has fewer plays for one cell and a brand-new cell.
      ctrl.mergeFromCloud({'hard|16|10': (9, 10), 'pair|8|2': (3, 3)});
      var s = c.read(strategyStatsProvider);
      expect(s['hard|16|10'], (40, 50), reason: 'local had more plays — must not shrink');
      expect(s['pair|8|2'], (3, 3), reason: 'new cloud cell is added');
      expect(s['soft|18|6'], (5, 5), reason: 'untouched cell stays');

      // Cloud ahead on the same cell → adopt the larger total.
      ctrl.mergeFromCloud({'hard|16|10': (20, 80)});
      expect(c.read(strategyStatsProvider)['hard|16|10'], (20, 80));
    });

    test('empty cloud does not clobber local', () async {
      final c = await makeContainer({
        'bj101-strategy-cells': jsonEncode({'hard|16|10': [40, 50]}),
      });
      addTearDown(c.dispose);
      final ctrl = c.read(strategyStatsProvider.notifier);
      ctrl.mergeFromCloud({});
      expect(c.read(strategyStatsProvider)['hard|16|10'], (40, 50));
    });
  });

  group('drill stats merge', () {
    ({int total, int correct, int bestStreak, Set<String> attempted, List<bool> recent})
        cloud({
      required int total,
      required int correct,
      required int bestStreak,
      Set<String> attempted = const {},
      List<bool> recent = const [],
    }) =>
            (
              total: total,
              correct: correct,
              bestStreak: bestStreak,
              attempted: attempted,
              recent: recent,
            );

    Future<ProviderContainer> seeded() => makeContainer({
          'bj101-drill-stats': jsonEncode({
            'total': 100,
            'correct': 80,
            'bestStreak': 12,
            'attempted': ['stiff', 'soft'],
            'recent': '11110',
          }),
        });

    test('local ahead keeps its totals; streak maxes; attempted unions', () async {
      final c = await seeded();
      addTearDown(c.dispose);
      final ctrl = c.read(drillStatsProvider.notifier);

      ctrl.mergeFromCloud(cloud(
          total: 50, correct: 45, bestStreak: 20, attempted: {'doubles'}));
      final d = c.read(drillStatsProvider);
      expect(d.total, 100, reason: 'local had more hands — keep them');
      expect(d.correct, 80);
      expect(d.bestStreak, 20, reason: 'best streak is the max of both');
      expect(d.attempted, {'stiff', 'soft', 'doubles'});
    });

    test('cloud ahead adopts its totals but streak still maxes', () async {
      final c = await seeded();
      addTearDown(c.dispose);
      final ctrl = c.read(drillStatsProvider.notifier);

      ctrl.mergeFromCloud(cloud(
          total: 200, correct: 150, bestStreak: 5, recent: [false, true]));
      final d = c.read(drillStatsProvider);
      expect(d.total, 200);
      expect(d.correct, 150);
      expect(d.bestStreak, 12, reason: 'local streak (12) still beat cloud (5)');
    });

    test('empty cloud does not clobber local', () async {
      final c = await seeded();
      addTearDown(c.dispose);
      final ctrl = c.read(drillStatsProvider.notifier);
      ctrl.mergeFromCloud(cloud(total: 0, correct: 0, bestStreak: 0));
      final d = c.read(drillStatsProvider);
      expect(d.total, 100);
      expect(d.correct, 80);
    });
  });

  group('learn progress merge', () {
    test('unions local and cloud lessons', () async {
      final c = await makeContainer({});
      addTearDown(c.dispose);
      final ctrl = c.read(learnProvider.notifier);
      ctrl.markComplete('basics');
      ctrl.markComplete('dealer');

      ctrl.mergeFromCloud({'dealer', 'hit-stand'});
      expect(c.read(learnProvider), {'basics', 'dealer', 'hit-stand'});

      ctrl.mergeFromCloud(<String>{});
      expect(c.read(learnProvider), {'basics', 'dealer', 'hit-stand'},
          reason: 'empty cloud must not un-complete lessons');
    });
  });
}
