import 'package:club_sandwich/features/notifications/data/workflow_notification_providers.dart';
import 'package:club_sandwich/features/notifications/domain/workflow_notification.dart';
import 'package:club_sandwich/features/concerts/presentation/concert_formatters.dart';
import 'package:club_sandwich/shared/widgets/app_state_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class WorkflowNotificationsButton extends ConsumerWidget {
  const WorkflowNotificationsButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      tooltip: 'Notifications',
      icon: const Icon(Icons.notifications_outlined),
      onPressed: () => showDialog<void>(
        context: context,
        builder: (context) => const _WorkflowNotificationsDialog(),
      ),
    );
  }
}

class _WorkflowNotificationsDialog extends ConsumerWidget {
  const _WorkflowNotificationsDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(workflowNotificationsProvider);
    return AlertDialog(
      title: const Text('Notifications'),
      content: SizedBox(
        width: 520,
        child: notifications.when(
          loading: () => const SizedBox(
            height: 160,
            child: AppLoadingState(label: 'Chargement des notifications'),
          ),
          error: (_, _) => SizedBox(
            height: 160,
            child: AppErrorState(
              message: 'Impossible de charger les notifications.',
              onRetry: () => ref.invalidate(workflowNotificationsProvider),
            ),
          ),
          data: (items) => items.isEmpty
              ? const SizedBox(
                  height: 120,
                  child: Center(child: Text('Aucune notification.')),
                )
              : ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 520),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) =>
                        _NotificationTile(notification: items[index]),
                  ),
                ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fermer'),
        ),
      ],
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  const _NotificationTile({required this.notification});

  final WorkflowNotification notification;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: Icon(
        notification.isRead
            ? Icons.notifications_none
            : Icons.notifications_active,
      ),
      title: Text(
        notification.title,
        style: notification.isRead
            ? null
            : const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        '${notification.body}\n'
        '${formatFrenchDateTime(notification.createdAt)}',
      ),
      isThreeLine: true,
      onTap: () async {
        if (!notification.isRead) {
          await ref
              .read(workflowNotificationRepositoryProvider)
              .markAsRead(notification.id);
          ref.invalidate(workflowNotificationsProvider);
        }
        if (!context.mounted || notification.concertId == null) return;
        Navigator.of(context).pop();
        context.go('/concerts/${notification.concertId}');
      },
    );
  }
}
