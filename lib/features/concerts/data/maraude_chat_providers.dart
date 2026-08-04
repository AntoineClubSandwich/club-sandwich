import 'package:club_sandwich/core/supabase/supabase_provider.dart';
import 'package:club_sandwich/features/concerts/data/maraude_chat_repository.dart';
import 'package:club_sandwich/features/concerts/data/maraude_chat_sound.dart';
import 'package:club_sandwich/features/concerts/domain/maraude_message.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final maraudeChatRepositoryProvider = Provider<MaraudeChatRepository>(
  (ref) => MaraudeChatRepository(ref.watch(supabaseClientProvider)),
);

final maraudeChatSoundProvider = Provider<MaraudeChatSound>((ref) {
  final sound = MaraudeChatSound(
    AudioplayersMaraudeChatAudioPlayer(AudioPlayer()),
  );
  ref.onDispose(sound.dispose);
  return sound;
});

final maraudeMessagesProvider =
    FutureProvider.family<List<MaraudeMessage>, String>((ref, concertId) {
      return ref.watch(maraudeChatRepositoryProvider).fetch(concertId);
    });
