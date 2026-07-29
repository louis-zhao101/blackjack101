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
      );
}

/// The selected table felt. Persisted by preset id; switch with `setPreset(id)`.
class TableThemeController extends Notifier<AppearanceTheme> {
  @override
  AppearanceTheme build() {
    final id = ref.read(localStoreProvider).loadAppearanceId();
    return id == null ? classicGreen : appearanceById(id);
  }

  /// [push] mirrors the change to the cloud (default). Pass `push: false` when
  /// adopting a value that came *from* the cloud, so it doesn't echo back.
  void setPreset(String id, {bool push = true}) {
    final next = appearanceById(id);
    if (next.id == state.id) return;
    state = next;
    ref.read(localStoreProvider).saveAppearanceId(state.id);
    if (push) _pushCosmetics(ref);
  }
}

final tableThemeProvider =
    NotifierProvider<TableThemeController, AppearanceTheme>(TableThemeController.new);

/// The selected card back, sold independently of the table felt.
class CardBackController extends Notifier<CardBack> {
  @override
  CardBack build() => cardBackById(ref.read(localStoreProvider).loadCardBackId() ?? kFreeCardBackId);

  void setCardBack(String id, {bool push = true}) {
    final next = cardBackById(id);
    if (next.id == state.id) return;
    state = next;
    ref.read(localStoreProvider).saveCardBackId(state.id);
    if (push) _pushCosmetics(ref);
  }
}

final cardBackProvider =
    NotifierProvider<CardBackController, CardBack>(CardBackController.new);

/// The selected card-face deck, sold independently of the table felt. The free
/// default draws faces procedurally; a premium deck supplies image assets.
class CardDeckController extends Notifier<CardDeck> {
  @override
  CardDeck build() =>
      cardDeckById(ref.read(localStoreProvider).loadCardDeckId() ?? kFreeCardDeckId);

  void setCardDeck(String id) {
    final next = cardDeckById(id);
    if (next.id == state.id) return;
    state = next;
    ref.read(localStoreProvider).saveCardDeckId(state.id);
  }
}

final cardDeckProvider =
    NotifierProvider<CardDeckController, CardDeck>(CardDeckController.new);

/// The active look every widget renders with: the selected table theme composed
/// with the chosen card back and deck cosmetics. Read-only — change the pieces
/// via [tableThemeProvider], [cardBackProvider], [cardDeckProvider].
final appearanceProvider = Provider<AppearanceTheme>((ref) {
  final base = ref.watch(tableThemeProvider);
  final back = ref.watch(cardBackProvider);
  final deck = ref.watch(cardDeckProvider);
  return base.copyWith(cardBack: back, deck: deck);
});

/// Live cloud cosmetic selection for the signed-in user. A listener (see
/// [AuthGate]) adopts changes as they arrive, so a theme picked on one device
/// shows up on the others within a second. Empty (no emissions) while signed
/// out; rebuilds automatically when the user changes.
final cosmeticCloudProvider =
    StreamProvider<({String? appearance, String? cardBack})>((ref) {
  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid == null) return const Stream.empty();
  return ref.read(firestoreSyncProvider).watchCosmeticSelection(uid);
});
