import 'package:club_sandwich/design_system/tokens/ds_spacing.dart';
import 'package:club_sandwich/design_system/tokens/ds_theme.dart';
import 'package:club_sandwich/design_system/tokens/ds_tokens.dart';
import 'package:club_sandwich/design_system/tokens/ds_typography.dart';
import 'package:club_sandwich/design_system/widgets/club_sandwich_mascot.dart';
import 'package:flutter/material.dart';

/// A placeholder screen for a not-yet-built feature — a mascot, a title
/// and a message, no functional content.
class FeatureEmptyState extends StatelessWidget {
  const FeatureEmptyState({
    required this.title,
    required this.message,
    required this.icon,
    super.key,
  });

  final String title;
  final String message;
  // Kept for API compatibility with callers built before the mascot
  // replaced per-feature icons; unused now.
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    // Self-wrapped in a local DsTheme.light regardless of the ambient
    // theme, matching the rest of the shared design-system widgets.
    return Theme(
      data: DsTheme.light,
      child: Builder(
        builder: (context) {
          final colors = Theme.of(context).extension<DsTokens>()!.colors;
          return Scaffold(
            backgroundColor: Colors.transparent,
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const ClubSandwichMascot(size: 96),
                    const SizedBox(height: DsSpacing.lg),
                    Text(
                      title,
                      style: DsTypography.h2.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: DsSpacing.sm),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: DsTypography.body.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
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
