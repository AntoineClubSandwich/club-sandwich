import 'package:flutter/material.dart';

import 'ds_colors.dart';

/// Typography scale for the Club Sandwich design system — "Bento Soft
/// Modern". Sizes/weights/line-heights/tracking come from
/// `design-system/CLAUDE.md`.
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

  /// "Stat large" — the biggest KPI/hero figure on a page. Tabular figures
  /// so a run of digits doesn't jitter in width as it updates.
  static const TextStyle display = TextStyle(
    fontFamily: fontFamily,
    fontSize: 36,
    height: 40 / 36,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.72, // -0.02em
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// "Stat moyen" — a secondary/smaller KPI figure, same tabular-numeral
  /// treatment as [display] at a lower size.
  static const TextStyle statMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 24,
    height: 28 / 24,
    fontWeight: FontWeight.w700,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const TextStyle h1 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 32,
    height: 40 / 32,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.64, // -0.02em
  );

  /// Card/entity title.
  static const TextStyle h2 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 24,
    height: 32 / 24,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.24, // -0.01em
  );

  /// Section title.
  static const TextStyle h3 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 18,
    height: 28 / 18,
    fontWeight: FontWeight.w600,
  );

  /// Button labels, active nav item text, default body copy.
  static const TextStyle body = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    height: 24 / 15,
    fontWeight: FontWeight.w400,
  );

  /// Nav labels, names — a step down from [body]. Not part of the
  /// design-system/CLAUDE.md scale; kept at its prior size/weight.
  static const TextStyle label = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w500,
  );

  /// "Body small" — meta text (dates, secondary line under a title).
  static const TextStyle meta = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    height: 20 / 13,
    fontWeight: FontWeight.w400,
  );

  /// "Label" — uppercase micro-labels (stat titles, section eyebrows).
  /// Callers apply `.toUpperCase()` to the string themselves; `TextStyle`
  /// has no built-in text-transform.
  static const TextStyle caption = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    height: 16 / 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.55, // 0.05em
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
