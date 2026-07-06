import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ui/theme/appearance.dart';
import 'app_providers.dart';
import 'auth_provider.dart';

/// Mirrors the full current cosmetic selection to the cloud. Always sends all
/// three ids so the coalescing sync queue (latest-wins per key) never drops a
/// field that changed in a separate call. Reads the just-saved ids from local
/// storage rather than the cosmetic providers — a controller can't depend on
/// its own provider (and each setter persists before calling this).
void _pushCosmetics(Ref ref) {
  final uid = ref.read(authServiceProvider).currentUser?.uid;
  if (uid == null) return;
  final store = ref.read(localStoreProvider);
  ref.read(syncQueueProvider.notifier).cosmeticSelection(
        uid,
        appearance: store.loadAppearanceId(),
        cardBack: store.loadCardBackId(),
        chipStyle: store.loadChipStyleId(),
      );
}

/// The selected table felt. Persisted by preset id; switch with `setPreset(id)`.
class TableThemeController extends Notifier<AppearanceTheme> {
  @override
  AppearanceTheme build() {
    final id = ref.read(localStoreProvider).loadAppearanceId();
    return id == null ? classicGreen : appearanceById(id);
  }

  void setPreset(String id) {
    state = appearanceById(id);
    ref.read(localStoreProvider).saveAppearanceId(state.id);
    _pushCosmetics(ref);
  }
}

final tableThemeProvider =
    NotifierProvider<TableThemeController, AppearanceTheme>(TableThemeController.new);

/// The selected card back, sold independently of the table felt.
class CardBackController extends Notifier<CardBack> {
  @override
  CardBack build() => cardBackById(ref.read(localStoreProvider).loadCardBackId() ?? kFreeCardBackId);

  void setCardBack(String id) {
    state = cardBackById(id);
    ref.read(localStoreProvider).saveCardBackId(state.id);
    _pushCosmetics(ref);
  }
}

final cardBackProvider =
    NotifierProvider<CardBackController, CardBack>(CardBackController.new);

/// The selected chip palette, sold independently of the table felt.
class ChipStyleController extends Notifier<ChipStyle> {
  @override
  ChipStyle build() =>
      chipStyleById(ref.read(localStoreProvider).loadChipStyleId() ?? kFreeChipStyleId);

  void setChipStyle(String id) {
    state = chipStyleById(id);
    ref.read(localStoreProvider).saveChipStyleId(state.id);
    _pushCosmetics(ref);
  }
}

final chipStyleProvider =
    NotifierProvider<ChipStyleController, ChipStyle>(ChipStyleController.new);

/// The active look every widget renders with: the selected table theme composed
/// with the chosen card back and chip cosmetics. Read-only — change the pieces
/// via [tableThemeProvider], [cardBackProvider], [chipStyleProvider].
final appearanceProvider = Provider<AppearanceTheme>((ref) {
  final base = ref.watch(tableThemeProvider);
  final back = ref.watch(cardBackProvider);
  final chips = ref.watch(chipStyleProvider);
  return base.copyWith(cardBack: back, chipStyle: chips);
});
