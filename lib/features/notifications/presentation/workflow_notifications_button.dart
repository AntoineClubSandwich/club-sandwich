import 'package:club_sandwich/design_system/components/buttons/ds_ghost_button.dart';
import 'package:club_sandwich/design_system/components/feedback/ds_dialog.dart';
import 'package:club_sandwich/design_system/components/indicators/ds_notification_badge.dart';
import 'package:club_sandwich/design_system/components/ds_pressable.dart';
import 'package:club_sandwich/design_system/icons/ds_icons.dart';
import 'package:club_sandwich/design_system/tokens/ds_radius.dart';
import 'package:club_sandwich/design_system/tokens/ds_spacing.dart';
import 'package:club_sandwich/design_system/tokens/ds_tokens.dart';
import 'package:club_sandwich/design_system/tokens/ds_typography.dart';
import 'package:club_sandwich/features/notifications/data/workflow_notification_providers.dart';
import 'package:club_sandwich/features/notifications/domain/workflow_notification.dart';
import 'package:club_sandwich/features/concerts/presentation/concert_formatters.dart';
import 'package:club_sandwich/shared/widgets/app_state_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class WorkflowNotificationsButton extends ConsumerWidget {
  const WorkflowNotificationsButton({this.foregroundColor, super.key});

  final Color? foregroundColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).extension<DsTokens>()!.colors;
    final unreadCount = ref
        .watch(workflowNotificationsProvider)
        .value
        ?.where((item) => !item.isRead)
        .length;
    return DsNotificationBadge(
      count: unreadCount ?? 0,
      child: IconButton(
        tooltip: 'Notifications',
        icon: Icon(DsIcons.bell, color: foregroundColor ?? colors.textPrimary),
        onPressed: () => showDialog<void>(
          context: context,
          builder: (context) => const _WorkflowNotificationsDialog(),
        ),
      ),
    );
  }
}

class _WorkflowNotificationsDialog extends ConsumerWidget {
  const _WorkflowNotificationsDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<DsTokens>()!;
    final colors = tokens.colors;
    final notifications = ref.watch(workflowNotificationsProvider);
    return DsDialog(
      title: 'Notifications',
      content: notifications.when(
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
            ? SizedBox(
                height: 120,
                child: Center(
                  child: Text(
                    'Aucune notification.',
                    style: DsTypography.body.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              )
            : ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 480),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: items.length,
                  separatorBuilder: (_, _) =>
                      Divider(height: DsSpacing.md, color: colors.border),
                  itemBuilder: (context, index) =>
                      _NotificationTile(notification: items[index]),
                ),
              ),
      ),
      actions: [
        DsGhostButton(
          label: 'Fermer',
          onPressed: () => Navigator.of(context).pop(),
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
    final colors = Theme.of(context).extension<DsTokens>()!.colors;

    Future<void> open() async {
      if (!notification.isRead) {
        await ref
            .read(workflowNotificationRepositoryProvider)
            .markAsRead(notification.id);
        ref.invalidate(workflowNotificationsProvider);
      }
      if (!context.mounted) return;
      final destination = _destinationFor(notification);
      if (destination == null) return;
      Navigator.of(context).pop();
      context.go(destination);
    }

    return DsPressable(
      onTap: open,
      builder: (context, state) => AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(
          horizontal: DsSpacing.sm,
          vertical: DsSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: state.hovered ? colors.neutralHoverOverlay : null,
          borderRadius: DsRadius.smRadius,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: notification.isRead
                      ? Colors.transparent
                      : colors.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const SizedBox(width: DsSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title,
                    style: DsTypography.body.copyWith(
                      color: colors.textPrimary,
                      fontWeight: notification.isRead
                          ? FontWeight.w600
                          : FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    notification.body,
                    style: DsTypography.caption.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formatFrenchDateTime(notification.createdAt),
                    style: DsTypography.caption.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Where tapping this notification should take the user. Maraude-related
/// notifications already carry a concert_id; the rest are routed by type
/// (verified against every notify_user/notify_active_admins call site
/// currently live, not just what happened to fire in this environment).
String? _destinationFor(WorkflowNotification notification) {
  if (notification.concertId != null) {
    return '/maraudes/${notification.concertId}';
  }
  return switch (notification.type) {
    'invitation_delivered' ||
    'invitation_not_selected' ||
    'invitation_selected' => '/invitations',
    'volunteer_document_requested' ||
    'volunteer_document_reviewed' ||
    'volunteer_documents_missing' => '/profile',
    'volunteer_document_submitted' => '/volunteers',
    'organization_convention_submitted' => '/organizations',
    _ => null,
  };
}
