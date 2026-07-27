import 'package:club_sandwich/core/supabase/supabase_provider.dart';
import 'package:club_sandwich/features/profiles/data/profile_repository.dart';
import 'package:club_sandwich/features/profiles/domain/profile.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(ref.watch(supabaseClientProvider)),
);

final currentProfileProvider = FutureProvider<Profile?>(
  (ref) => ref.watch(profileRepositoryProvider).fetchCurrentProfile(),
);
