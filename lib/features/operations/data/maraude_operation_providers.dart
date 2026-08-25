import 'dart:async';

import 'package:club_sandwich/core/supabase/supabase_provider.dart';
import 'package:club_sandwich/features/auth/application/auth_providers.dart';
import 'package:club_sandwich/features/operations/data/maraude_operation_repository.dart';
import 'package:club_sandwich/features/operations/domain/maraude_workflow.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final maraudeOperationRepositoryProvider = Provider<MaraudeOperationRepository>(
  (ref) => MaraudeOperationRepository(ref.watch(supabaseClientProvider)),
);

final maraudeOperationBundleProvider = FutureProvider.autoDispose
    .family<MaraudeOperationBundle, String>((ref, concertId) async {
      ref.watch(authStateProvider);
      final repository = ref.watch(maraudeOperationRepositoryProvider);
      final channel = repository.client.channel('maraude-operation-$concertId');
      for (final table in [
        'maraude_operations',
        'maraude_consumable_allocations',
        'maraude_equipment_allocations',
        'maraude_collections',
        'maraude_distributions',
      ]) {
        channel.onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: table,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'concert_id',
            value: concertId,
          ),
          callback: (_) => ref.invalidateSelf(),
        );
      }
      channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'encounters',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'maraude_id',
          value: concertId,
        ),
        callback: (_) => ref.invalidateSelf(),
      );
      channel.subscribe();
      ref.onDispose(() => unawaited(repository.client.removeChannel(channel)));
      return repository.fetchBundle(concertId);
    });
