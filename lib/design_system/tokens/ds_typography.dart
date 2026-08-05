import 'package:flutter/material.dart';

import 'ds_colors.dart';

/// Typography scale for the Club Sandwich design system.
///
/// Backed by Inter (bundled as a variable font in `assets/fonts/`,
/// SIL Open Font License — same license family as the Noto Sans already
/// bundled for PDF export). Each named style below is mapped onto a
/// standard Material 3 `TextTheme` slot in [DsTypography.buildTextTheme]
/// so incidental Material widgets inherit a consistent look too; use the
/// named aliases (`DsTypography.h1`, ...) directly when a `Ds*` component
/// wants to be explicit about intent rather than reaching for the
/// Material slot name.
abstract final class DsTypography {
  static const String fontFamily = 'Inter';

  static const TextStyle h1 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 32,
    height: 40 / 32,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle h2 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 24,
    height: 32 / 24,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle h3 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    height: 28 / 20,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle body = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w500,
  );

  /// Builds the Material [TextTheme] slots consumed by `ThemeData`,
  /// colored from [colors]. `Ds*` components should still prefer the
  /// named aliases above over reaching into `Theme.of(context).textTheme`
  /// directly, but incidental Material widgets in the style guide (e.g.
  /// `Divider`, default `Text` inside a `Dialog` barrier) get a coherent
  /// look for free through this mapping.
  static TextTheme buildTextTheme(DsColorTokens colors) => TextTheme(
    headlineLarge: h1.copyWith(color: colors.textPrimary),
    headlineSmall: h2.copyWith(color: colors.textPrimary),
    titleLarge: h3.copyWith(color: colors.textPrimary),
    bodyLarge: body.copyWith(color: colors.textPrimary),
    labelSmall: caption.copyWith(color: colors.textSecondary),
  );
}
