import 'package:club_sandwich/features/concerts/data/maraude_chat_sound.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:typed_data';

void main() {
  test('active le son par une action utilisateur puis notifie', () async {
    final player = _FakeAudioPlayer();
    final sound = MaraudeChatSound(player);
    addTearDown(sound.dispose);

    expect(sound.enabled, isFalse);
    await sound.notify();
    expect(player.playCount, 0);

    await sound.enable();
    expect(sound.enabled, isTrue);
    expect(player.playCount, 1);

    await sound.notify();
    expect(player.playCount, 2);

    sound.disable();
    expect(sound.enabled, isFalse);
  });
}

class _FakeAudioPlayer implements MaraudeChatAudioPlayer {
  int playCount = 0;

  @override
  Future<void> play(Uint8List bytes) async {
    expect(bytes.length, greaterThan(44));
    playCount++;
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}
