import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../engine/strategy.dart' show Difficulty;
import '../engine/variants.dart';
import '../services/sound_service.dart';
import '../ui/widgets/game_button.dart' show setHapticsEnabled;
import 'app_providers.dart';

class SettingsState {
  final RuleSet ruleSet;
  final bool hapticsEnabled;
  final bool soundEnabled;
  final Difficulty difficulty;
  const SettingsState({
    required this.ruleSet,
    this.hapticsEnabled = true,
    this.soundEnabled = true,
    this.difficulty = Difficulty.regular,
  });

  SettingsState copyWith({
    RuleSet? ruleSet,
    bool? hapticsEnabled,
    bool? soundEnabled,
    Difficulty? difficulty,
  }) =>
      SettingsState(
        ruleSet: ruleSet ?? this.ruleSet,
        hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
        soundEnabled: soundEnabled ?? this.soundEnabled,
        difficulty: difficulty ?? this.difficulty,
      );
}

class SettingsController extends Notifier<SettingsState> {
  @override
  SettingsState build() {
    final loaded = ref.read(localStoreProvider).loadSettings();
    final hapticsEnabled = loaded?.hapticsEnabled ?? true;
    final soundEnabled = loaded?.soundEnabled ?? true;
    setHapticsEnabled(hapticsEnabled);
    SoundService.instance.enabled = soundEnabled;
    return SettingsState(
      ruleSet: loaded?.ruleSet ?? vegasStrip,
      hapticsEnabled: hapticsEnabled,
      soundEnabled: soundEnabled,
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

  void setHaptics(bool enabled) {
    setHapticsEnabled(enabled);
    state = state.copyWith(hapticsEnabled: enabled);
    _persist();
  }

  void setSound(bool enabled) {
    SoundService.instance.enabled = enabled;
    state = state.copyWith(soundEnabled: enabled);
    _persist();
  }

  void _persist() {
    ref.read(localStoreProvider).saveSettings(
        state.ruleSet, state.hapticsEnabled, state.soundEnabled, state.difficulty);
  }
}

final settingsProvider =
    NotifierProvider<SettingsController, SettingsState>(SettingsController.new);
