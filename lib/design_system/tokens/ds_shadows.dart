import 'package:flutter/widgets.dart';

/// Shadow tokens for the Club Sandwich design system.
///
/// Hard, offset, zero-blur "ink" shadows — the neo-brutalist signature —
/// rather than Material's soft blurred elevation. `card` is for resting
/// surfaces, `elevated` for surfaces that float above the page (dialogs,
/// dropdown menus, bottom sheets). Both take the active `colors.borderStrong`
/// ink color, same pattern as `focusRing` already used for `colors.primary`,
/// so the shadow color always tracks the active theme rather than being
/// hardcoded. `focusRing` itself is a keyboard-focus indicator, not a
/// shadow proper.
abstract final class DsShadows {
  static List<BoxShadow> card(Color ink) => [
    BoxShadow(color: ink, offset: const Offset(3, 3)),
  ];

  static List<BoxShadow> elevated(Color ink) => [
    BoxShadow(color: ink, offset: const Offset(5, 5)),
  ];

  static List<BoxShadow> focusRing(Color primary) => [
    BoxShadow(
      color: primary.withValues(alpha: 0.16),
      blurRadius: 0,
      spreadRadius: 3,
    ),
  ];
}
