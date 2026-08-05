import 'package:flutter/material.dart';

import 'ds_colors.dart';
import 'ds_shadows.dart';

/// The single lookup point every `Ds*` component uses to read the active
/// color palette: `Theme.of(context).extension<DsTokens>()!`.
///
/// Only colors are modeled as a [ThemeExtension] (and therefore
/// lerp-able) — this design system has one theme today
/// ([DsTheme.light], no dark variant yet), but routing color lookups
/// through `Theme.of(context)` rather than a hardcoded
/// `DsColorTokens.light` keeps every component ready for a future
/// `DsTheme.dark` without changes. Spacing/radius/motion
/// ([DsSpacing], [DsRadius], [DsMotion], [DsShadows]) are pure numeric
/// scales that never vary by theme, so components reference those
/// directly as static constants instead.
class DsTokens extends ThemeExtension<DsTokens> {
  const DsTokens({required this.colors});

  final DsColorTokens colors;

  /// Keyboard-focus ring shadow, derived from the active primary color.
  List<BoxShadow> get focusRing => DsShadows.focusRing(colors.primary);

  static const DsTokens light = DsTokens(colors: DsColorTokens.light);

  @override
  DsTokens copyWith({DsColorTokens? colors}) {
    return DsTokens(colors: colors ?? this.colors);
  }

  @override
  DsTokens lerp(ThemeExtension<DsTokens>? other, double t) {
    if (other is! DsTokens) return this;
    return DsTokens(colors: colors.lerp(other.colors, t));
  }
}
