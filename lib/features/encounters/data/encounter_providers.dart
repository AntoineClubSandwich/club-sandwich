import 'package:club_sandwich/core/supabase/supabase_provider.dart';
import 'package:club_sandwich/features/auth/application/auth_providers.dart';
import 'package:club_sandwich/features/encounters/data/encounter_location_service.dart';
import 'package:club_sandwich/features/encounters/data/encounter_repository.dart';
import 'package:club_sandwich/features/encounters/domain/maraude_encounter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final encounterRepositoryProvider = Provider<EncounterRepository>(
  (ref) => EncounterRepository(ref.watch(supabaseClientProvider)),
);

final encounterLocationServiceProvider = Provider<EncounterLocationService>(
  (ref) => const EncounterLocationService(),
);

final adminEncounterMapProvider = FutureProvider.autoDispose
    .family<List<MaraudeEncounter>, EncounterMapPeriod>((ref, period) {
      ref.watch(authStateProvider);
      return ref.watch(encounterRepositoryProvider).fetchAdminMap(period);
    });

final myEncounterMapProvider = FutureProvider.autoDispose
    .family<List<MaraudeEncounter>, EncounterMapPeriod>((ref, period) {
      ref.watch(authStateProvider);
      return ref.watch(encounterRepositoryProvider).fetchMyMap(period);
    });
