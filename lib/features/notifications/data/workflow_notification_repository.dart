import 'package:club_sandwich/features/notifications/domain/workflow_notification.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WorkflowNotificationRepository {
  const WorkflowNotificationRepository(this.client);

  final SupabaseClient client;

  Future<List<WorkflowNotification>> fetchMine() async {
    final rows = await client
        .from('user_notifications')
        .select()
        .order('created_at', ascending: false)
        .limit(50);
    return rows.map(WorkflowNotification.fromJson).toList(growable: false);
  }

  Future<void> markAsRead(String notificationId) async {
    await client
        .from('user_notifications')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', notificationId);
  }
}
