import 'package:club_sandwich/core/supabase/supabase_provider.dart';
import 'package:club_sandwich/features/auth/application/auth_providers.dart';
import 'package:club_sandwich/features/notifications/data/workflow_notification_repository.dart';
import 'package:club_sandwich/features/notifications/domain/workflow_notification.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final workflowNotificationRepositoryProvider =
    Provider<WorkflowNotificationRepository>(
      (ref) =>
          WorkflowNotificationRepository(ref.watch(supabaseClientProvider)),
    );

final workflowNotificationsProvider =
    FutureProvider<List<WorkflowNotification>>((ref) {
      ref.watch(authStateProvider);
      return ref.watch(workflowNotificationRepositoryProvider).fetchMine();
    });
