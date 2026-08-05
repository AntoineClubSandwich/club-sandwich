import 'package:flutter/material.dart';

import 'ds_colors.dart';
import 'ds_tokens.dart';
import 'ds_typography.dart';

/// The Club Sandwich design system's theme.
///
/// Deliberately **not** wired into `lib/app.dart` — the existing app keeps
/// using `AppTheme.light` (`lib/core/theme/app_theme.dart`) unchanged, so
/// every current screen renders exactly as before. `DsTheme.light` is
/// applied locally, only around the `/style-guide` screen, via
/// `Theme(data: DsTheme.light, child: ...)`. Wiring it in more broadly is a
/// deliberate decision for a future screen-by-screen redesign, not this
/// design-system build.
abstract final class DsTheme {
  static ThemeData get light {
    const colors = DsColorTokens.light;

    final colorScheme = ColorScheme.light(
      primary: colors.primary,
      onPrimary: colors.textOnColor,
      secondary: colors.secondary,
      onSecondary: colors.textOnColor,
      surface: colors.surface,
      onSurface: colors.textPrimary,
      error: colors.error,
      onError: colors.textOnColor,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colors.canvas,
      fontFamily: DsTypography.fontFamily,
      textTheme: DsTypography.buildTextTheme(colors),
      dividerColor: colors.border,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      extensions: const [DsTokens.light],
    );
  }
}
