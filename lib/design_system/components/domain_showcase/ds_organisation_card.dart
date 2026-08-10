import 'package:flutter/material.dart';

import '../../icons/ds_icons.dart';
import '../../mock/style_guide_mock_data.dart';
import '../../tokens/ds_spacing.dart';
import '../../tokens/ds_tokens.dart';
import '../../tokens/ds_typography.dart';
import '../indicators/ds_avatar.dart';
import '../surfaces/ds_card.dart';

/// A style showcase for a tourneur organisation entry — mock data only,
/// not wired to the real `OrganizationsScreen`/`Organization`.
class DsOrganisationCard extends StatelessWidget {
  const DsOrganisationCard({super.key, required this.data, this.onTap});

  final DsOrganisationCardData data;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<DsTokens>()!;
    final colors = tokens.colors;

    return DsCard(
      onTap: onTap,
      child: Row(
        children: [
          DsAvatar(
            initials: data.initials,
            size: DsAvatarSize.lg,
            square: true,
          ),
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
                    Icon(DsIcons.mapPin, size: 12, color: colors.textSecondary),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        data.city,
                        overflow: TextOverflow.ellipsis,
                        style: DsTypography.caption.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: DsSpacing.sm),
                    Icon(DsIcons.users, size: 12, color: colors.textSecondary),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        '${data.memberCount} membres',
                        overflow: TextOverflow.ellipsis,
                        style: DsTypography.caption.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
