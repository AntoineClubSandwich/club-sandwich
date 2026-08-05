import 'package:flutter/material.dart';

import '../../icons/ds_icons.dart';
import '../../tokens/ds_spacing.dart';
import '../../tokens/ds_tokens.dart';
import '../../tokens/ds_typography.dart';
import 'ds_card.dart';

enum DsMetricTrend { up, down, neutral }

/// A single-number "at a glance" metric — e.g. "Maraudes réalisées: 12".
/// [delta] is an optional pre-formatted string ("+12%", "-3"); [trend]
/// colors it success/error/neutral.
class DsMetricCard extends StatelessWidget {
  const DsMetricCard({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.delta,
    this.trend = DsMetricTrend.neutral,
  });

  final String label;
  final String value;
  final IconData? icon;
  final String? delta;
  final DsMetricTrend trend;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<DsTokens>()!;
    final colors = tokens.colors;

    final Color trendColor = switch (trend) {
      DsMetricTrend.up => colors.success,
      DsMetricTrend.down => colors.error,
      DsMetricTrend.neutral => colors.textSecondary,
    };
    final IconData trendIcon = switch (trend) {
      DsMetricTrend.up => DsIcons.trendingUp,
      DsMetricTrend.down => DsIcons.trendingDown,
      DsMetricTrend.neutral => DsIcons.dot,
    };

    return DsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colors.primarySelectedBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 16, color: colors.primary),
                ),
                const SizedBox(width: DsSpacing.sm),
              ],
              Expanded(
                child: Text(
                  label,
                  style: DsTypography.caption.copyWith(
                    color: colors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: DsSpacing.md),
          Text(
            value,
            style: DsTypography.h2.copyWith(color: colors.textPrimary),
          ),
          if (delta != null) ...[
            const SizedBox(height: DsSpacing.xs),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(trendIcon, size: 14, color: trendColor),
                const SizedBox(width: 2),
                Text(
                  delta!,
                  style: DsTypography.caption.copyWith(
                    color: trendColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
