import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_providers.dart';
import 'auth_provider.dart';

/// Number of completable Learn lessons — the non-practice entries in `_lessons`
/// (learn_page.dart), matching its `teachable` count. Drives the "Scholar"
/// achievement; bump this when a real (non-practice) lesson is added.
const int kLearnLessonCount = 5;

/// Number of Test Yourself drills (see `_drillSets` in learn_page.dart).
/// Drives the "Well Rounded" achievement; bump this when drills are added.
const int kDrillCount = 5;

/// Tracks which Learn lessons the user has completed. Local-only for now
/// (soft progression — completion drives the path's "recommended next",
/// nothing is hard-locked).
class LearnController extends Notifier<Set<String>> {
  @override
  Set<String> build() => ref.read(localStoreProvider).loadLearnProgress();

  void markComplete(String lessonId) {
    if (state.contains(lessonId)) return;
    _set({...state, lessonId});
    if (state.length >= kLearnLessonCount) {
      ref.read(reviewPromptProvider.notifier).maybePrompt();
    }
  }

  /// Unions cloud-completed lessons into local (completion never un-completes).
  void mergeFromCloud(Set<String> ids) {
    final merged = {...state, ...ids};
    if (merged.length != state.length) _set(merged);
  }

  void reset() => _set(<String>{});

  void _set(Set<String> next) {
    state = next;
    ref.read(localStoreProvider).saveLearnProgress(next);
    final uid = ref.read(authServiceProvider).currentUser?.uid;
    if (uid != null) ref.read(syncQueueProvider.notifier).learnProgress(uid, next);
  }
}

final learnProvider = NotifierProvider<LearnController, Set<String>>(LearnController.new);
