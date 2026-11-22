import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Small pooled audio player. All assets are original synthesized WAVs.
class AudioManager {
  AudioManager();

  static final AudioManager instance = AudioManager();

  final List<AudioPlayer> _pool = [];
  final AudioPlayer _music = AudioPlayer();
  int _next = 0;
  bool _initialized = false;
  bool _musicWanted = false;

  bool sfxEnabled = true;
  bool musicEnabled = true;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      for (var i = 0; i < 4; i++) {
        final p = AudioPlayer(playerId: 'bm-sfx-$i');
        await p.setReleaseMode(ReleaseMode.stop);
        await p.setVolume(1.0);
        _pool.add(p);
      }
      await _music.setReleaseMode(ReleaseMode.loop);
      await _music.setVolume(0.34);
    } catch (e) {
      debugPrint('Audio init failed: $e');
    }
  }

  Future<void> setSfxEnabled(bool value) async {
    sfxEnabled = value;
    if (!_initialized) return;
    if (!value) {
      for (final p in _pool) {
        try {
          await p.stop();
        } catch (_) {}
      }
    }
  }

  Future<void> setMusicEnabled(bool value) async {
    musicEnabled = value;
    if (!_initialized) return;
    try {
      if (value && _musicWanted) {
        await _startMusic();
      } else if (!value) {
        await _music.pause();
      }
    } catch (e) {
      debugPrint('audio toggle failed: $e');
    }
  }

  Future<void> playSfx(String name, {double volume = 1.0}) async {
    if (!sfxEnabled || _pool.isEmpty) return;
    final p = _pool[_next++ % _pool.length];
    try {
      await p.stop();
      await p.setVolume(volume);
      await p.play(AssetSource('audio/$name.wav'), volume: volume);
    } catch (e) {
      debugPrint('sfx $name failed: $e');
    }
  }

  Future<void> startMusic() async {
    _musicWanted = true;
    if (!_initialized) return;
    if (musicEnabled) await _startMusic();
  }

  Future<void> _startMusic() async {
    try {
      await _music.setVolume(0.34);
      await _music.play(AssetSource('audio/music_loop.wav'));
    } catch (e) {
      debugPrint('music failed: $e');
    }
  }

  Future<void> stopMusic() async {
    _musicWanted = false;
    try {
      await _music.stop();
    } catch (_) {}
  }

  Future<void> dispose() async {
    for (final p in _pool) {
      await p.dispose();
    }
    await _music.dispose();
  }
}
