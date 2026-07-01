import 'dart:math';

import 'package:flutter/services.dart' show rootBundle;
import 'package:soundpool/soundpool.dart';

/// Fire-and-forget sound effects. Uses soundpool (AVAudioPlayer on iOS,
/// SoundPool on Android) which is built for short overlapping clips, unlike
/// AVPlayer-based players that fail to load bundled audio on iOS.
class SoundService {
  SoundService._() {
    for (final entry in _clips.entries) {
      _ids[entry.key] =
          rootBundle.load(entry.value).then((data) => _pool.load(data));
    }
  }

  static final SoundService instance = SoundService._();

  static const _clips = {
    'card_deal': 'assets/sounds/card_deal.wav',
    'card_slide': 'assets/sounds/card_slide.mp3',
    'card_flip': 'assets/sounds/card_flip.wav',
    'chip_place': 'assets/sounds/chip_place.wav',
    'chip_stack': 'assets/sounds/chip_stack.wav',
    'shuffle': 'assets/sounds/shuffle.wav',
    'win': 'assets/sounds/win.wav',
    'lose': 'assets/sounds/lose.wav',
    'push': 'assets/sounds/push.wav',
    'blackjack': 'assets/sounds/blackjack.wav',
  };

  final Soundpool _pool = Soundpool.fromOptions(
    options: const SoundpoolOptions(streamType: StreamType.music, maxStreams: 6),
  );
  final Map<String, Future<int>> _ids = {};
  final Map<String, int> _lastPlayMs = {};
  final Random _rng = Random();

  bool enabled = true;

  /// [vary] adds subtle pitch variation so repeated clicks feel organic.
  /// [minGapMs] drops retriggers fired too close together, which is what makes
  /// rapid dealing/betting sound harsh and machine-gunned.
  void _play(String name, {bool vary = false, int minGapMs = 0}) {
    if (!enabled) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (minGapMs > 0 && now - (_lastPlayMs[name] ?? 0) < minGapMs) return;
    _lastPlayMs[name] = now;
    final rate = vary ? 0.97 + _rng.nextDouble() * 0.09 : 1.0;
    _ids[name]?.then((id) => _pool.play(id, rate: rate));
  }

  void chipPlace() => _play('chip_place', vary: true, minGapMs: 40);
  void chipStack() => _play('chip_stack', vary: true, minGapMs: 40);
  void cardDeal() => _play('card_deal', vary: true, minGapMs: 40);
  void cardSlide() => _play('card_slide', vary: true, minGapMs: 40);
  void cardFlip() => _play('card_flip', minGapMs: 40);
  void shuffle() => _play('shuffle', minGapMs: 200);

  // Outcome jingles reflect the result of the hand (money won/lost), matching
  // the on-table headline — not whether the play was strategically optimal.
  void win() => _play('win');
  void lose() => _play('lose');
  void push() => _play('push');
  void blackjack() => _play('blackjack');
}
