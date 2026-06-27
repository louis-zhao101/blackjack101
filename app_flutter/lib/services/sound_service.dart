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

  bool enabled = true;

  void _play(String name) {
    if (!enabled) return;
    _ids[name]?.then((id) => _pool.play(id));
  }

  void chipPlace() => _play('chip_place');
  void chipStack() => _play('chip_stack');
  void cardDeal() => _play('card_deal');
  void cardFlip() => _play('card_flip');
  void shuffle() => _play('shuffle');
  void win() => _play('win');
  void lose() => _play('lose');
  void push() => _play('push');
  void blackjack() => _play('blackjack');
}
