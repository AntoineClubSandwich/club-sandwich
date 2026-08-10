import 'package:flutter/material.dart';

import 'ds_colors.dart';

/// Typography scale for the Club Sandwich design system — "Bento Soft
/// Modern".
///
/// Backed by Inter (bundled as a variable font in `assets/fonts/`, SIL
/// Open Font License) for every text role — hierarchy comes purely from
/// size/weight on the one family, not a second display face. Each named
/// style below is mapped onto a standard Material 3 `TextTheme` slot in
/// [DsTypography.buildTextTheme] so incidental Material widgets inherit a
/// consistent look too; use the named aliases (`DsTypography.h1`, ...)
/// directly when a `Ds*` component wants to be explicit about intent
/// rather than reaching for the Material slot name.
abstract final class DsTypography {
  static const String fontFamily = 'Inter';

  /// Alias of [fontFamily] — kept as a distinct name rather than deleted
  /// so call sites that reference it for "the display face" don't need
  /// editing; hierarchy in this style comes from weight, not a second face.
  static const String displayFontFamily = 'Inter';

  /// Large, high-impact figures — KPI values, hero stats. Distinct from
  /// the headline slots because it's meant for a single short number/word,
  /// not a wrapping line.
  static const TextStyle display = TextStyle(
    fontFamily: fontFamily,
    fontSize: 40,
    height: 44 / 40,
    fontWeight: FontWeight.w800,
  );

  static const TextStyle h1 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 32,
    height: 40 / 32,
    fontWeight: FontWeight.w700,
  );

  /// Card/entity title.
  static const TextStyle h2 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    height: 28 / 20,
    fontWeight: FontWeight.w600,
  );

  /// Section title.
  static const TextStyle h3 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 18,
    height: 24 / 18,
    fontWeight: FontWeight.w600,
  );

  /// Button labels, active nav item text.
  static const TextStyle body = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    height: 20 / 15,
    fontWeight: FontWeight.w500,
  );

  /// Nav labels, names — a step down from [body].
  static const TextStyle label = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w500,
  );

  /// Meta text (dates, secondary line under a title).
  static const TextStyle meta = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    height: 18 / 13,
    fontWeight: FontWeight.w500,
  );

  /// Uppercase micro-labels (stat titles, section eyebrows).
  static const TextStyle caption = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w600,
  );

  /// Smallest text — status chip labels, inline email/meta.
  static const TextStyle micro = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    height: 14 / 11,
    fontWeight: FontWeight.w800,
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
    titleMedium: label.copyWith(color: colors.textPrimary),
    bodyLarge: body.copyWith(color: colors.textPrimary),
    bodyMedium: meta.copyWith(color: colors.textSecondary),
    labelSmall: caption.copyWith(color: colors.textSecondary),
    labelMedium: micro.copyWith(color: colors.textSecondary),
  );
}
