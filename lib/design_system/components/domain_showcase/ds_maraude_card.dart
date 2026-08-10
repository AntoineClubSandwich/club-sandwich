import 'package:flutter/material.dart';

import '../../icons/ds_icons.dart';
import '../../mock/style_guide_mock_data.dart';
import '../../tokens/ds_radius.dart';
import '../../tokens/ds_spacing.dart';
import '../../tokens/ds_tokens.dart';
import '../../tokens/ds_typography.dart';
import '../indicators/ds_status_chip.dart';
import '../surfaces/ds_card.dart';

String _maraudeStatusLabel(DsChipStatus status) => switch (status) {
  DsChipStatus.draft => 'Brouillon',
  DsChipStatus.active => 'Ouverte',
  DsChipStatus.pending => 'À confirmer',
  DsChipStatus.completed => 'Terminée',
  DsChipStatus.cancelled => 'Annulée',
};

/// A style showcase for how a maraude would read in the new visual
/// language — mock data only, not wired to `MaraudeOverview`/`Concert`.
/// The real screens keep using `MaraudeOverviewCard`/`_ConcertCard`
/// unchanged.
class DsMaraudeCard extends StatelessWidget {
  const DsMaraudeCard({super.key, required this.data, this.onTap});

  final DsMaraudeCardData data;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<DsTokens>()!;
    final colors = tokens.colors;
    final fill = data.volunteersRequired == 0
        ? 0.0
        : (data.volunteersRegistered / data.volunteersRequired)
              .clamp(0, 1)
              .toDouble();

    return DsCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  data.title,
                  style: DsTypography.h3.copyWith(color: colors.textPrimary),
                ),
              ),
              const SizedBox(width: DsSpacing.sm),
              DsStatusChip(
                label: _maraudeStatusLabel(data.status),
                status: data.status,
              ),
            ],
          ),
          const SizedBox(height: DsSpacing.md),
          Row(
            children: [
              Icon(DsIcons.calendar, size: 14, color: colors.textSecondary),
              const SizedBox(width: DsSpacing.xs),
              Flexible(
                child: Text(
                  data.dateLabel,
                  overflow: TextOverflow.ellipsis,
                  style: DsTypography.caption.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: DsSpacing.xs),
          Row(
            children: [
              Icon(DsIcons.mapPin, size: 14, color: colors.textSecondary),
              const SizedBox(width: DsSpacing.xs),
              Expanded(
                child: Text(
                  data.venue,
                  style: DsTypography.caption.copyWith(
                    color: colors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: DsSpacing.lg),
          Row(
            children: [
              Icon(DsIcons.users, size: 14, color: colors.textSecondary),
              const SizedBox(width: DsSpacing.xs),
              Flexible(
                child: Text(
                  '${data.volunteersRegistered}/${data.volunteersRequired} bénévoles',
                  overflow: TextOverflow.ellipsis,
                  style: DsTypography.caption.copyWith(
                    color: colors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: DsSpacing.xs),
          ClipRRect(
            borderRadius: DsRadius.pillRadius,
            child: LayoutBuilder(
              builder: (context, constraints) => Stack(
                children: [
                  Container(height: 6, color: colors.border),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: 6,
                    width: constraints.maxWidth * fill,
                    color: colors.primary,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
