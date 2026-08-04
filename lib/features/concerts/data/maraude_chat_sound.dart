import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MaraudeChatSound {
  MaraudeChatSound(this._player, {SharedPreferencesAsync? preferences})
    : _preferencesOverride = preferences;

  static const _preferenceKey = 'maraude_chat_sound_enabled';

  final MaraudeChatAudioPlayer _player;
  // Constructing SharedPreferencesAsync() requires the platform plugin to
  // be registered, which isn't true in plain (non-widget) unit tests — so
  // this is created lazily, inside the try/catch of whichever method
  // first needs it, rather than eagerly in the constructor.
  final SharedPreferencesAsync? _preferencesOverride;
  bool _enabled = false;

  bool get enabled => _enabled;

  /// Loads the persisted preference. Call once after construction and
  /// rebuild the UI when it completes — the value isn't known
  /// synchronously, so [enabled] reads `false` until this resolves.
  Future<void> restore() async {
    try {
      final preferences = _preferencesOverride ?? SharedPreferencesAsync();
      _enabled = await preferences.getBool(_preferenceKey) ?? false;
    } catch (_) {
      // Une préférence locale indisponible ne doit jamais bloquer le chat.
    }
  }

  Future<void> enable() async {
    _enabled = true;
    unawaited(_persist(true));
    await _play();
  }

  void disable() {
    _enabled = false;
    unawaited(_persist(false));
    _player.stop();
  }

  Future<void> _persist(bool value) async {
    try {
      final preferences = _preferencesOverride ?? SharedPreferencesAsync();
      await preferences.setBool(_preferenceKey, value);
    } catch (_) {
      // Le son reste actif pour la session même si l’écriture échoue.
    }
  }

  Future<void> notify() async {
    if (!_enabled) return;
    await _play();
  }

  Future<void> dispose() => _player.dispose();

  Future<void> _play() async {
    await _player.stop();
    await _player.play(_notificationWave);
  }
}

abstract interface class MaraudeChatAudioPlayer {
  Future<void> play(Uint8List bytes);
  Future<void> stop();
  Future<void> dispose();
}

class AudioplayersMaraudeChatAudioPlayer implements MaraudeChatAudioPlayer {
  AudioplayersMaraudeChatAudioPlayer(this._player);

  final AudioPlayer _player;

  @override
  Future<void> play(Uint8List bytes) =>
      _player.play(BytesSource(bytes), volume: 0.35);

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> dispose() => _player.dispose();
}

final Uint8List _notificationWave = _buildNotificationWave();

Uint8List _buildNotificationWave() {
  const sampleRate = 44100;
  const durationSeconds = 0.14;
  final sampleCount = (sampleRate * durationSeconds).round();
  const bytesPerSample = 2;
  final dataLength = sampleCount * bytesPerSample;
  final data = ByteData(44 + dataLength);

  void writeAscii(int offset, String value) {
    for (var index = 0; index < value.length; index++) {
      data.setUint8(offset + index, value.codeUnitAt(index));
    }
  }

  writeAscii(0, 'RIFF');
  data.setUint32(4, 36 + dataLength, Endian.little);
  writeAscii(8, 'WAVE');
  writeAscii(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, sampleRate, Endian.little);
  data.setUint32(28, sampleRate * bytesPerSample, Endian.little);
  data.setUint16(32, bytesPerSample, Endian.little);
  data.setUint16(34, 16, Endian.little);
  writeAscii(36, 'data');
  data.setUint32(40, dataLength, Endian.little);

  for (var index = 0; index < sampleCount; index++) {
    final time = index / sampleRate;
    final progress = index / sampleCount;
    final envelope = math.pow(1 - progress, 2).toDouble();
    final signal =
        math.sin(2 * math.pi * 880 * time) * 0.6 +
        math.sin(2 * math.pi * 1320 * time) * 0.25;
    final sample = (signal * envelope * 32767).round().clamp(-32768, 32767);
    data.setInt16(44 + index * bytesPerSample, sample, Endian.little);
  }

  return data.buffer.asUint8List();
}
