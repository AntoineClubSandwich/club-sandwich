import 'package:club_sandwich/core/supabase/supabase_provider.dart';
import 'package:club_sandwich/features/auth/application/auth_providers.dart';
import 'package:club_sandwich/features/equipment/data/equipment_repository.dart';
import 'package:club_sandwich/features/equipment/domain/equipment_asset.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final equipmentRepositoryProvider = Provider<EquipmentRepository>(
  (ref) => EquipmentRepository(ref.watch(supabaseClientProvider)),
);

final equipmentAssetsProvider = FutureProvider<List<EquipmentAsset>>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(equipmentRepositoryProvider).fetchAll();
});

final equipmentLocationsProvider = FutureProvider<List<EquipmentLocation>>((
  ref,
) {
  ref.watch(authStateProvider);
  return ref.watch(equipmentRepositoryProvider).fetchLocations();
});

final equipmentEventsProvider =
    FutureProvider.family<List<EquipmentEvent>, String>((ref, id) {
      ref.watch(authStateProvider);
      return ref.watch(equipmentRepositoryProvider).fetchEvents(id);
    });
