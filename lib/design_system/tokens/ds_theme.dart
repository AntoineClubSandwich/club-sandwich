import 'package:flutter/material.dart';

import 'ds_borders.dart';
import 'ds_colors.dart';
import 'ds_radius.dart';
import 'ds_tokens.dart';
import 'ds_typography.dart';

/// The Club Sandwich design system's theme — wired app-wide via
/// `MaterialApp.router(theme: DsTheme.light)` in `lib/app.dart`.
///
/// `Ds*` components read colors through `Theme.of(context).extension<
/// DsTokens>()`, never through this theme's Material component themes
/// directly. The Material component themes below (`cardTheme`,
/// `inputDecorationTheme`, `dialogTheme`, button themes, ...) exist so that
/// screens not yet converted to `Ds*` components still render with the
/// Bento Soft Modern palette/type/shape instead of stock Material — a
/// consistent stopgap during the screen-by-screen rollout, not a
/// replacement for adopting `Ds*` components directly. Material's `Card`/
/// `Dialog` elevation model can't express `DsShadows`' soft blurred shadow,
/// so these only carry the border + shape; the full soft-shadow treatment
/// is specific to `DsCard`/`DsDialog`.
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
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: DsRadius.smRadius),
        enabledBorder: OutlineInputBorder(
          borderRadius: DsRadius.smRadius,
          borderSide: BorderSide(color: colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: DsRadius.smRadius,
          borderSide: BorderSide(
            color: colors.borderFocus,
            width: DsBorders.standard,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: DsRadius.smRadius,
          borderSide: BorderSide(color: colors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: DsRadius.smRadius,
          borderSide: BorderSide(
            color: colors.error,
            width: DsBorders.standard,
          ),
        ),
        filled: true,
        fillColor: colors.surface,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: colors.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: DsRadius.xlRadius,
          side: BorderSide(color: colors.border, width: DsBorders.hairline),
        ),
      ),
      dialogTheme: DialogThemeData(
        elevation: 0,
        backgroundColor: colors.surfaceElevated,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(
          borderRadius: DsRadius.xxlRadius,
          side: BorderSide(color: colors.border, width: DsBorders.hairline),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: colors.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: DsRadius.smRadius,
          side: BorderSide(color: colors.border),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        showCloseIcon: true,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(borderRadius: DsRadius.mdRadius),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(borderRadius: DsRadius.mdRadius),
          side: BorderSide(color: colors.border, width: DsBorders.hairline),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: colors.textOnColor,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: DsRadius.mdRadius),
        ),
      ),
      dividerTheme: DividerThemeData(color: colors.border, space: 24),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colors.primary,
        foregroundColor: colors.textOnColor,
        extendedTextStyle: DsTypography.body.copyWith(
          color: colors.textOnColor,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: DsRadius.pillRadius),
      ),
    );
  }
}
