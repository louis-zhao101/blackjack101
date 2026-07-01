import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_providers.dart';

/// Tracks which Learn lessons the user has completed. Local-only for now
/// (soft progression — completion drives the path's "recommended next",
/// nothing is hard-locked).
class LearnController extends Notifier<Set<String>> {
  @override
  Set<String> build() => ref.read(localStoreProvider).loadLearnProgress();

  void markComplete(String lessonId) {
    if (state.contains(lessonId)) return;
    state = {...state, lessonId};
    ref.read(localStoreProvider).saveLearnProgress(state);
  }

  void reset() {
    state = <String>{};
    ref.read(localStoreProvider).saveLearnProgress(state);
  }
}

final learnProvider = NotifierProvider<LearnController, Set<String>>(LearnController.new);
