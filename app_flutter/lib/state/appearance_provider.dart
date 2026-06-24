import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ui/theme/appearance.dart';
import 'app_providers.dart';

/// Holds the active table skin. Persisted by preset id so a future settings
/// screen can switch skins with `setPreset(id)`.
class AppearanceController extends Notifier<AppearanceTheme> {
  @override
  AppearanceTheme build() {
    final id = ref.read(localStoreProvider).loadAppearanceId();
    return id == null ? classicGreen : appearanceById(id);
  }

  void setPreset(String id) {
    state = appearanceById(id);
    ref.read(localStoreProvider).saveAppearanceId(state.id);
  }
}

final appearanceProvider =
    NotifierProvider<AppearanceController, AppearanceTheme>(AppearanceController.new);
