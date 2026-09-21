import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'game_assets.dart';

/// Thin wrapper over audioplayers with a small round-robin pool so overlapping
/// effects (reel stops, coin ticks) do not cut each other off.
class AudioService {
  AudioService._();

  static final AudioService instance = AudioService._();

  final AudioPlayer _music = AudioPlayer(playerId: 'music');
  final List<AudioPlayer> _effects = <AudioPlayer>[];
  int _cursor = 0;
  bool _ready = false;
  String? _currentMusic;

  bool musicEnabled = true;
  bool soundEnabled = true;

  Future<void> init() async {
    if (_ready) return;
    try {
      await _music.setReleaseMode(ReleaseMode.loop);
      await _music.setVolume(0.32);
      for (int i = 0; i < 5; i++) {
        final AudioPlayer player = AudioPlayer(playerId: 'sfx_$i');
        await player.setReleaseMode(ReleaseMode.stop);
        await player.setPlayerMode(PlayerMode.lowLatency);
        _effects.add(player);
      }
      _ready = true;
    } catch (error) {
      debugPrint('AudioService init failed: $error');
    }
  }

  Future<void> playMusic(String asset) async {
    _currentMusic = asset;
    if (!musicEnabled) return;
    try {
      await _music.play(AssetSource(asset), volume: 0.32);
    } catch (error) {
      debugPrint('playMusic failed: $error');
    }
  }

  Future<void> stopMusic() async {
    try {
      await _music.stop();
    } catch (_) {
      // Nothing to do: losing background music is not worth surfacing.
    }
  }

  Future<void> setMusicEnabled(bool enabled) async {
    musicEnabled = enabled;
    if (enabled) {
      if (_currentMusic != null) await playMusic(_currentMusic!);
    } else {
      await stopMusic();
    }
  }

  void play(String asset, {double volume = 0.9}) {
    if (!soundEnabled || _effects.isEmpty) return;
    final AudioPlayer player = _effects[_cursor];
    _cursor = (_cursor + 1) % _effects.length;
    player.play(AssetSource(asset), volume: volume).catchError((Object error) {
      debugPrint('play $asset failed: $error');
    });
  }

  void click() => play(GameSounds.click, volume: 0.7);

  void select() => play(GameSounds.selection, volume: 0.8);

  void reward() => play(GameSounds.reward);

  void victory() => play(GameSounds.victory);

  void defeat() => play(GameSounds.defeat, volume: 0.7);

  void error() => play(GameSounds.error, volume: 0.7);

  void bigBonus() => play(GameSounds.majorBonus);

  Future<void> dispose() async {
    await _music.dispose();
    for (final AudioPlayer player in _effects) {
      await player.dispose();
    }
    _effects.clear();
    _ready = false;
  }
}
