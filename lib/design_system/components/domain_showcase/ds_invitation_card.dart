import 'package:flutter/material.dart';

import '../../icons/ds_icons.dart';
import '../../mock/style_guide_mock_data.dart';
import '../../tokens/ds_spacing.dart';
import '../../tokens/ds_tokens.dart';
import '../../tokens/ds_typography.dart';
import '../buttons/ds_ghost_button.dart';
import '../indicators/ds_avatar.dart';
import '../indicators/ds_badge.dart';
import '../indicators/ds_status_chip.dart';
import '../surfaces/ds_card.dart';

String _invitationStatusLabel(DsChipStatus status) => switch (status) {
  DsChipStatus.draft => 'Brouillon',
  DsChipStatus.active => 'Envoyée',
  DsChipStatus.pending => 'Envoyée',
  DsChipStatus.completed => 'Acceptée',
  DsChipStatus.cancelled => 'Expirée',
};

/// A style showcase for an invitation candidate — mock data only, not
/// wired to the real `InvitationsScreen`/`concert_volunteer_application`.
class DsInvitationCard extends StatelessWidget {
  const DsInvitationCard({super.key, required this.data, this.onResend});

  final DsInvitationCardData data;
  final VoidCallback? onResend;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<DsTokens>()!;
    final colors = tokens.colors;
    final initials = data.name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0])
        .join();

    return DsCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DsAvatar(initials: initials),
          const SizedBox(width: DsSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  data.name,
                  style: DsTypography.body.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(DsIcons.mail, size: 12, color: colors.textSecondary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        data.email,
                        style: DsTypography.caption.copyWith(
                          color: colors.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: DsSpacing.sm),
                Wrap(
                  spacing: DsSpacing.xs,
                  runSpacing: DsSpacing.xs,
                  children: [
                    DsBadge(label: data.role),
                    DsStatusChip(
                      label: _invitationStatusLabel(data.status),
                      status: data.status,
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (onResend != null) ...[
            const SizedBox(width: DsSpacing.sm),
            DsGhostButton(
              label: 'Renvoyer',
              icon: DsIcons.mail,
              onPressed: onResend,
            ),
          ],
        ],
      ),
    );
  }
}
