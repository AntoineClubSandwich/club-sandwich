import 'package:flutter/material.dart';

import '../../tokens/ds_spacing.dart';
import '../../tokens/ds_tokens.dart';
import '../../tokens/ds_typography.dart';

/// A section title, optional supporting subtitle, and an optional
/// trailing action — used to head a group of cards/content.
class DsSectionHeader extends StatelessWidget {
  const DsSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<DsTokens>()!;
    final colors = tokens.colors;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: DsTypography.h2.copyWith(color: colors.textPrimary),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: DsSpacing.xs),
                Text(
                  subtitle!,
                  style: DsTypography.body.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: DsSpacing.lg),
          trailing!,
        ],
      ],
    );
  }
}
