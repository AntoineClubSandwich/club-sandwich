import 'package:flutter/material.dart';

import '../../tokens/ds_motion.dart';
import '../../tokens/ds_spacing.dart';
import '../../tokens/ds_tokens.dart';
import '../../tokens/ds_typography.dart';

/// A calm, discreet loading indicator — a thin `colors.primary` spinner
/// and a label, fading in rather than popping in abruptly.
class DsLoadingState extends StatelessWidget {
  const DsLoadingState({super.key, this.label = 'Chargement'});

  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<DsTokens>()!;
    final colors = tokens.colors;

    return Center(
      child: AnimatedOpacity(
        opacity: 1,
        duration: DsMotion.standard,
        curve: DsMotion.curve,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colors.primary,
              ),
            ),
            const SizedBox(height: DsSpacing.md),
            Text(
              label,
              style: DsTypography.caption.copyWith(color: colors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
