import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../engine/variants.dart';
import 'app_providers.dart';

class SettingsState {
  final RuleSet ruleSet;
  final int startingBankroll;
  const SettingsState({required this.ruleSet, required this.startingBankroll});

  SettingsState copyWith({RuleSet? ruleSet, int? startingBankroll}) => SettingsState(
        ruleSet: ruleSet ?? this.ruleSet,
        startingBankroll: startingBankroll ?? this.startingBankroll,
      );
}

class SettingsController extends Notifier<SettingsState> {
  @override
  SettingsState build() {
    final loaded = ref.read(localStoreProvider).loadSettings();
    return SettingsState(
      ruleSet: loaded?.ruleSet ?? vegasStrip,
      startingBankroll: loaded?.startingBankroll ?? 1000,
    );
  }

  void setRuleSet(RuleSet ruleSet) {
    state = state.copyWith(ruleSet: ruleSet);
    _persist();
  }

  void setStartingBankroll(int amount) {
    state = state.copyWith(startingBankroll: amount);
    _persist();
  }

  void _persist() {
    ref.read(localStoreProvider).saveSettings(state.ruleSet, state.startingBankroll);
  }
}

final settingsProvider =
    NotifierProvider<SettingsController, SettingsState>(SettingsController.new);
