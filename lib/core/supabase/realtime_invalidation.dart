import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// One table to watch for changes, optionally scoped to a single row's
/// foreign key (e.g. `concert_id = <id>`). The table must be added to the
/// `supabase_realtime` publication in a migration for events to arrive.
class RealtimeWatch {
  const RealtimeWatch(this.table, {this.filterColumn, this.filterValue});
  final String table;
  final String? filterColumn;
  final String? filterValue;
}

/// Subscribes [watches] on a dedicated channel and invalidates the calling
/// provider whenever a matching row changes, so open screens refresh
/// themselves without the user having to reload the page. Call once at the
/// top of a `FutureProvider` builder, after the initial data fetch is
/// kicked off. The channel is torn down automatically when the provider is
/// disposed.
void watchRealtimeInvalidation({
  required Ref ref,
  required SupabaseClient client,
  required String channelName,
  required List<RealtimeWatch> watches,
}) {
  final channel = client.channel(channelName);
  for (final watch in watches) {
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: watch.table,
      filter: watch.filterColumn == null
          ? null
          : PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: watch.filterColumn!,
              value: watch.filterValue,
            ),
      callback: (_) => ref.invalidateSelf(),
    );
  }
  channel.subscribe();
  ref.onDispose(() => unawaited(client.removeChannel(channel)));
}
