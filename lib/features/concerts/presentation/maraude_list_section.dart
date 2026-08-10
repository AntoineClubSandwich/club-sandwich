import 'package:club_sandwich/design_system/tokens/ds_spacing.dart';
import 'package:club_sandwich/design_system/tokens/ds_theme.dart';
import 'package:club_sandwich/design_system/tokens/ds_tokens.dart';
import 'package:club_sandwich/design_system/tokens/ds_typography.dart';
import 'package:club_sandwich/features/concerts/domain/maraude_operation.dart';
import 'package:club_sandwich/features/concerts/presentation/maraude_overview_card.dart';
import 'package:flutter/material.dart';

class MaraudeListSection extends StatelessWidget {
  const MaraudeListSection({
    required this.title,
    required this.items,
    this.actionLabel,
    this.actionLabelFor,
    this.canOpenFor,
    super.key,
  });

  final String title;
  final List<MaraudeOverview> items;
  final String? actionLabel;
  final String Function(MaraudeOverview)? actionLabelFor;
  final bool Function(MaraudeOverview)? canOpenFor;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    // See MaraudeOverviewCard for why this wraps its own DsTheme.light.
    return Theme(
      data: DsTheme.light,
      child: Builder(
        builder: (context) {
          final colors = Theme.of(context).extension<DsTokens>()!.colors;
          return Padding(
            padding: const EdgeInsets.only(bottom: DsSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  style: DsTypography.h3.copyWith(color: colors.textPrimary),
                ),
                const SizedBox(height: DsSpacing.sm),
                for (final item in items)
                  MaraudeOverviewCard(
                    maraude: item,
                    actionLabel: actionLabelFor?.call(item) ?? actionLabel,
                    canOpen: canOpenFor?.call(item) ?? true,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
