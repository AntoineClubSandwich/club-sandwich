import 'package:club_sandwich/core/supabase/realtime_invalidation.dart';
import 'package:club_sandwich/core/supabase/supabase_provider.dart';
import 'package:club_sandwich/features/auth/application/auth_providers.dart';
import 'package:club_sandwich/features/operations/data/maraude_operation_repository.dart';
import 'package:club_sandwich/features/operations/domain/maraude_workflow.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final maraudeOperationRepositoryProvider = Provider<MaraudeOperationRepository>(
  (ref) => MaraudeOperationRepository(ref.watch(supabaseClientProvider)),
);

final maraudeOperationBundleProvider = FutureProvider.autoDispose
    .family<MaraudeOperationBundle, String>((ref, concertId) async {
      ref.watch(authStateProvider);
      final repository = ref.watch(maraudeOperationRepositoryProvider);
      watchRealtimeInvalidation(
        ref: ref,
        client: repository.client,
        channelName: 'maraude-operation-$concertId',
        watches: [
          for (final table in [
            'maraude_operations',
            'maraude_step_events',
            'maraude_consumable_allocations',
            'maraude_equipment_allocations',
            'maraude_collections',
            'maraude_distributions',
          ])
            RealtimeWatch(
              table,
              filterColumn: 'concert_id',
              filterValue: concertId,
            ),
          RealtimeWatch(
            'encounters',
            filterColumn: 'maraude_id',
            filterValue: concertId,
          ),
        ],
      );
      return repository.fetchBundle(concertId);
    });
