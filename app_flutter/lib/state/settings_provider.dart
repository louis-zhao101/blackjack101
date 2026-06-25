import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../engine/strategy.dart' show Difficulty;
import '../engine/variants.dart';
import '../ui/widgets/game_button.dart' show setHapticsEnabled;
import 'app_providers.dart';

class SettingsState {
  final RuleSet ruleSet;
  final int startingBankroll;
  final bool hapticsEnabled;
  final Difficulty difficulty;
  const SettingsState({
    required this.ruleSet,
    required this.startingBankroll,
    this.hapticsEnabled = true,
    this.difficulty = Difficulty.regular,
  });

  SettingsState copyWith({
    RuleSet? ruleSet,
    int? startingBankroll,
    bool? hapticsEnabled,
    Difficulty? difficulty,
  }) =>
      SettingsState(
        ruleSet: ruleSet ?? this.ruleSet,
        startingBankroll: startingBankroll ?? this.startingBankroll,
        hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
        difficulty: difficulty ?? this.difficulty,
      );
}

class SettingsController extends Notifier<SettingsState> {
  @override
  SettingsState build() {
    final loaded = ref.read(localStoreProvider).loadSettings();
    final hapticsEnabled = loaded?.hapticsEnabled ?? true;
    setHapticsEnabled(hapticsEnabled);
    return SettingsState(
      ruleSet: loaded?.ruleSet ?? vegasStrip,
      startingBankroll: loaded?.startingBankroll ?? 1000,
      hapticsEnabled: hapticsEnabled,
      difficulty: loaded?.difficulty ?? Difficulty.regular,
    );
  }

  void setRuleSet(RuleSet ruleSet) {
    state = state.copyWith(ruleSet: ruleSet);
    _persist();
  }

  void setDifficulty(Difficulty difficulty) {
    state = state.copyWith(difficulty: difficulty);
    _persist();
  }

  void setStartingBankroll(int amount) {
    state = state.copyWith(startingBankroll: amount);
    _persist();
  }

  void setHaptics(bool enabled) {
    setHapticsEnabled(enabled);
    state = state.copyWith(hapticsEnabled: enabled);
    _persist();
  }

  void _persist() {
    ref.read(localStoreProvider).saveSettings(
        state.ruleSet, state.startingBankroll, state.hapticsEnabled, state.difficulty);
  }
}

final settingsProvider =
    NotifierProvider<SettingsController, SettingsState>(SettingsController.new);
