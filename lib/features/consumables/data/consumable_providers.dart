import 'package:club_sandwich/core/supabase/supabase_provider.dart';
import 'package:club_sandwich/features/auth/application/auth_providers.dart';
import 'package:club_sandwich/features/consumables/data/consumable_repository.dart';
import 'package:club_sandwich/features/consumables/domain/consumable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final consumableRepositoryProvider = Provider<ConsumableRepository>(
  (ref) => ConsumableRepository(ref.watch(supabaseClientProvider)),
);

final consumablesProvider = FutureProvider<List<Consumable>>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(consumableRepositoryProvider).fetchAll();
});

final consumableMovementsProvider =
    FutureProvider.family<List<ConsumableMovement>, String>((ref, id) {
      ref.watch(authStateProvider);
      return ref.watch(consumableRepositoryProvider).fetchMovements(id);
    });
