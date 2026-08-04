import 'package:club_sandwich/core/supabase/supabase_provider.dart';
import 'package:club_sandwich/features/auth/application/auth_providers.dart';
import 'package:club_sandwich/features/profiles/data/profile_repository.dart';
import 'package:club_sandwich/features/profiles/domain/profile.dart';
import 'package:club_sandwich/features/profiles/domain/volunteer_statistics.dart';
import 'package:club_sandwich/features/profiles/domain/volunteer_private_profile.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(ref.watch(supabaseClientProvider)),
);

final currentProfileProvider = FutureProvider<Profile?>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(profileRepositoryProvider).fetchCurrentProfile();
});

final currentVolunteerPrivateProfileProvider =
    FutureProvider<VolunteerPrivateProfile?>((ref) {
      ref.watch(authStateProvider);
      return ref
          .watch(profileRepositoryProvider)
          .fetchCurrentVolunteerProfile();
    });

final volunteerStatisticsProvider = FutureProvider<VolunteerStatistics?>((
  ref,
) async {
  ref.watch(authStateProvider);
  final client = ref.watch(supabaseClientProvider);
  if (client.auth.currentUser == null) return null;
  final rows = await client.rpc<List<dynamic>>('get_my_volunteer_statistics');
  if (rows.isEmpty) return null;
  return VolunteerStatistics.fromJson(rows.first as Map<String, dynamic>);
});
