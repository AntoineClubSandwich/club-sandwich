import 'package:club_sandwich/core/supabase/supabase_provider.dart';
import 'package:club_sandwich/features/auth/application/auth_providers.dart';
import 'package:club_sandwich/features/avatar/data/avatar_repository.dart';
import 'package:club_sandwich/features/avatar/domain/avatar_config.dart';
import 'package:club_sandwich/features/profiles/data/profile_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final avatarRepositoryProvider = Provider<AvatarRepository>(
  (ref) => AvatarRepository(ref.watch(supabaseClientProvider)),
);

final currentAvatarConfigProvider = FutureProvider<AvatarConfig>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(avatarRepositoryProvider).fetchCurrentAvatar();
});

/// Maraudes completed by the current volunteer, used to gate unlockable
/// items — `0` while loading/on error so locked items simply stay locked
/// rather than the customizer crashing or flashing everything unlocked.
final maraudesCompletedProvider = Provider<int>((ref) {
  return ref
      .watch(volunteerStatisticsProvider)
      .maybeWhen(
        data: (stats) => stats?.maraudesCompleted ?? 0,
        orElse: () => 0,
      );
});
