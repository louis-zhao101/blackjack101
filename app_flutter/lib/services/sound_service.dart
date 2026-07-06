import 'dart:math';

import 'package:audioplayers/audioplayers.dart';

/// Fire-and-forget sound effects. Uses audioplayers with a small round-robin
/// pool of players so short clips can overlap (dealing, chip stacks) without
/// cutting each other off — the equivalent of soundpool's `maxStreams`.
class SoundService {
  SoundService._() {
    // Copy the bundled clips into audioplayers' cache up front so the first
    // play of each doesn't stutter while the asset is unpacked.
    AudioCache.instance.loadAll(_clips.values.toList());
    for (var i = 0; i < _poolSize; i++) {
      _pool.add(AudioPlayer()..setReleaseMode(ReleaseMode.stop));
    }
  }

  static final SoundService instance = SoundService._();

  static const _poolSize = 6;

  // Paths are relative to audioplayers' default asset prefix ('assets/').
  static const _clips = {
    'card_deal': 'sounds/card_deal.wav',
    'card_slide': 'sounds/card_slide.mp3',
    'card_flip': 'sounds/card_flip.wav',
    'chip_place': 'sounds/chip_place.wav',
    'chip_stack': 'sounds/chip_stack.wav',
    'shuffle': 'sounds/shuffle.wav',
    'win': 'sounds/win.wav',
    'lose': 'sounds/lose.wav',
    'push': 'sounds/push.wav',
    'blackjack': 'sounds/blackjack.wav',
  };

  final List<AudioPlayer> _pool = [];
  int _next = 0;
  final Map<String, int> _lastPlayMs = {};
  final Random _rng = Random();

  bool enabled = true;

  /// [vary] adds subtle pitch variation so repeated clicks feel organic.
  /// [minGapMs] drops retriggers fired too close together, which is what makes
  /// rapid dealing/betting sound harsh and machine-gunned.
  void _play(String name, {bool vary = false, int minGapMs = 0}) {
    if (!enabled) return;
    final path = _clips[name];
    if (path == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (minGapMs > 0 && now - (_lastPlayMs[name] ?? 0) < minGapMs) return;
    _lastPlayMs[name] = now;

    final rate = vary ? 0.97 + _rng.nextDouble() * 0.09 : 1.0;
    final player = _pool[_next];
    _next = (_next + 1) % _pool.length;
    player.setPlaybackRate(rate);
    player.play(AssetSource(path));
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
