import 'package:flutter/painting.dart';

import '../../tokens/ds_colors.dart';

/// Semantic color variant shared by [DsBadge] and [DsStatusChip].
enum DsSemanticVariant {
  primary,
  secondary,
  success,
  warning,
  error,
  info,
  neutral,
}

/// Foreground/background pair for a [DsSemanticVariant], resolved from the
/// active [DsColorTokens].
class DsSemanticColors {
  const DsSemanticColors({required this.foreground, required this.background});

  final Color foreground;
  final Color background;

  static DsSemanticColors resolve(
    DsColorTokens colors,
    DsSemanticVariant variant,
  ) {
    return switch (variant) {
      DsSemanticVariant.primary => DsSemanticColors(
        foreground: colors.primary,
        background: colors.primarySelectedBg,
      ),
      DsSemanticVariant.secondary => DsSemanticColors(
        foreground: colors.secondary,
        background: colors.secondarySelectedBg,
      ),
      DsSemanticVariant.success => DsSemanticColors(
        foreground: colors.success,
        background: colors.successBg,
      ),
      DsSemanticVariant.warning => DsSemanticColors(
        foreground: colors.warning,
        background: colors.warningBg,
      ),
      DsSemanticVariant.error => DsSemanticColors(
        foreground: colors.error,
        background: colors.errorBg,
      ),
      DsSemanticVariant.info => DsSemanticColors(
        foreground: colors.info,
        background: colors.infoBg,
      ),
      DsSemanticVariant.neutral => DsSemanticColors(
        foreground: colors.textSecondary,
        background: colors.neutralSelectedBg,
      ),
    };
  }
}
