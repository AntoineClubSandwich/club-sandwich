import 'package:flutter/material.dart';

import '../../tokens/ds_spacing.dart';
import '../../tokens/ds_tokens.dart';
import '../../tokens/ds_typography.dart';

/// A "nothing here yet" placeholder — an illustration, a title, a short
/// message, and an optional action (typically a [DsPrimaryButton] or
/// [DsGhostButton]).
class DsEmptyState extends StatelessWidget {
  const DsEmptyState({
    super.key,
    required this.title,
    required this.message,
    this.illustration,
    this.action,
  });

  final String title;
  final String message;
  final Widget? illustration;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<DsTokens>()!;
    final colors = tokens.colors;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (illustration != null) ...[
              SizedBox(width: 120, height: 120, child: illustration),
              const SizedBox(height: DsSpacing.xl),
            ],
            Text(
              title,
              textAlign: TextAlign.center,
              style: DsTypography.h3.copyWith(color: colors.textPrimary),
            ),
            const SizedBox(height: DsSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: DsTypography.body.copyWith(color: colors.textSecondary),
            ),
            if (action != null) ...[
              const SizedBox(height: DsSpacing.xl),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
