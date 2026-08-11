import 'package:club_sandwich/design_system/components/ds_hover_spotlight.dart';
import 'package:club_sandwich/design_system/components/indicators/ds_status_chip.dart';
import 'package:club_sandwich/design_system/components/surfaces/ds_card.dart';
import 'package:club_sandwich/design_system/icons/ds_icons.dart';
import 'package:club_sandwich/design_system/tokens/ds_spacing.dart';
import 'package:club_sandwich/design_system/tokens/ds_theme.dart';
import 'package:club_sandwich/design_system/tokens/ds_tokens.dart';
import 'package:club_sandwich/design_system/tokens/ds_typography.dart';
import 'package:club_sandwich/features/concerts/domain/concert.dart';
import 'package:club_sandwich/features/concerts/domain/maraude_operation.dart';
import 'package:club_sandwich/features/concerts/presentation/concert_formatters.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MaraudeOverviewCard extends StatelessWidget {
  const MaraudeOverviewCard({
    required this.maraude,
    this.actionLabel,
    this.canOpen = true,
    super.key,
  });

  final MaraudeOverview maraude;
  final String? actionLabel;
  final bool canOpen;

  @override
  Widget build(BuildContext context) {
    // Wrapped in a local DsTheme.light regardless of the ambient theme:
    // this card is reused by the promoter/volunteer dashboard sections and
    // by widget tests that pump DashboardScreen/VolunteersScreen without
    // the app-wide theme.
    return Theme(
      data: DsTheme.light,
      child: Builder(
        builder: (context) {
          final colors = Theme.of(context).extension<DsTokens>()!.colors;
          return Padding(
            padding: const EdgeInsets.only(bottom: DsSpacing.md),
            child: DsHoverSpotlight(
              enabled: canOpen,
              child: DsCard(
                onTap: canOpen
                    ? () => context.go('/maraudes/${maraude.concertId}')
                    : null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            maraude.artist,
                            style: DsTypography.h3.copyWith(
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: DsSpacing.sm),
                        DsStatusChip(
                          label: maraude.maraudeStatus.label,
                          status: _maraudeChipStatus(maraude.maraudeStatus),
                        ),
                      ],
                    ),
                    const SizedBox(height: DsSpacing.sm),
                    _CardInfo(
                      icon: DsIcons.mapPin,
                      text:
                          '${formatLongFrenchDate(maraude.date)} · '
                          '${maraude.venueName}'
                          '${maraude.time == null ? '' : ' · ${_shortTime(maraude.time!)}'}',
                    ),
                    if (maraude.venueAddress != null) ...[
                      const SizedBox(height: DsSpacing.xs),
                      _CardInfo(
                        icon: DsIcons.mapPin,
                        text: maraude.venueAddress!,
                      ),
                    ],
                    if (maraude.cateringName != null) ...[
                      const SizedBox(height: DsSpacing.xs),
                      _CardInfo(
                        icon: DsIcons.utensils,
                        text: 'Catering : ${maraude.cateringName}',
                      ),
                    ],
                    if (maraude.ownTeamRole != null) ...[
                      const SizedBox(height: DsSpacing.xs),
                      _CardInfo(
                        icon: DsIcons.user,
                        text: 'Rôle : ${maraude.ownTeamRole!.label}',
                      ),
                    ],
                    if (maraude.cateringClosesAt != null) ...[
                      const SizedBox(height: DsSpacing.xs),
                      _CardInfo(
                        icon: DsIcons.footprints,
                        text:
                            'Arrivée recommandée : '
                            '${_time(maraude.recommendedArrival)}',
                      ),
                    ],
                    if (maraude.isAdmin &&
                        maraude.maraudeStatus != MaraudeStatus.completed &&
                        maraude.maraudeStatus != MaraudeStatus.cancelled) ...[
                      const SizedBox(height: DsSpacing.sm),
                      Wrap(
                        spacing: DsSpacing.lg,
                        runSpacing: DsSpacing.xs,
                        children: [
                          Text(
                            maraude.selectedCount == 0
                                ? 'Équipe non constituée'
                                : '${maraude.selectedCount} bénévole'
                                      '${maraude.selectedCount > 1 ? 's' : ''} '
                                      'sélectionné'
                                      '${maraude.selectedCount > 1 ? 's' : ''}',
                            style: DsTypography.caption.copyWith(
                              color: colors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (maraude.pendingApplicationCount > 0)
                            Text(
                              '${maraude.pendingApplicationCount} candidature'
                              '${maraude.pendingApplicationCount > 1 ? 's' : ''} '
                              'à examiner',
                              style: DsTypography.caption.copyWith(
                                color: colors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          if (maraude.pendingConfirmationCount > 0)
                            Text(
                              '${maraude.pendingConfirmationCount} confirmation'
                              '${maraude.pendingConfirmationCount > 1 ? 's' : ''} '
                              'attendue'
                              '${maraude.pendingConfirmationCount > 1 ? 's' : ''}',
                              style: DsTypography.caption.copyWith(
                                color: colors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    ],
                    if (maraude.maraudeStatus == MaraudeStatus.completed ||
                        maraude.maraudeStatus == MaraudeStatus.cancelled) ...[
                      const SizedBox(height: DsSpacing.sm),
                      Wrap(
                        spacing: DsSpacing.lg,
                        runSpacing: DsSpacing.xs,
                        children: [
                          Text(
                            '${maraude.selectedCount} bénévole'
                            '${maraude.selectedCount > 1 ? 's' : ''}',
                            style: DsTypography.caption.copyWith(
                              color: colors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            maraude.totalWeightKg == null
                                ? 'Poids : —'
                                : '${_number(maraude.totalWeightKg!)} kg',
                            style: DsTypography.caption.copyWith(
                              color: colors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (actionLabel != null) ...[
                      const SizedBox(height: DsSpacing.sm),
                      Text(
                        actionLabel!,
                        style: DsTypography.body.copyWith(
                          color: colors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CardInfo extends StatelessWidget {
  const _CardInfo({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<DsTokens>()!.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: colors.textSecondary),
        const SizedBox(width: DsSpacing.sm),
        Expanded(
          child: Text(
            text,
            style: DsTypography.caption.copyWith(
              color: colors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

DsChipStatus _maraudeChipStatus(MaraudeStatus status) => switch (status) {
  MaraudeStatus.draft => DsChipStatus.draft,
  MaraudeStatus.open => DsChipStatus.active,
  MaraudeStatus.teamReady => DsChipStatus.active,
  MaraudeStatus.inProgress => DsChipStatus.active,
  MaraudeStatus.completed => DsChipStatus.completed,
  MaraudeStatus.cancelled => DsChipStatus.cancelled,
};

String _shortTime(String value) {
  final parts = value.split(':');
  return parts.length < 2 ? value : '${parts[0]}:${parts[1]}';
}

String _number(double value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value.toStringAsFixed(1).replaceAll('.', ',');
}

String _time(DateTime value) {
  return '${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}';
}
