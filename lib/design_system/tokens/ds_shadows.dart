import 'package:flutter/widgets.dart';

/// Shadow tokens for the Club Sandwich design system — "Bento Soft Modern":
/// soft, blurred, low-opacity shadows, never a hard offset "ink" shadow.
/// `ambient` is for resting neutral surfaces (cards, top bar), `accent` is
/// for branded/interactive elements (primary button, avatar, active nav —
/// anything that should read as "purple-lit" rather than "just elevated").
/// `ambientElevated` is `ambient`'s larger-blur variant for surfaces that
/// float above the page (dialogs, bottom sheets). `focusRing` itself is a
/// keyboard-focus indicator, not a shadow proper.
abstract final class DsShadows {
  static List<BoxShadow> ambient(Color tint) => [
    BoxShadow(
      color: tint.withValues(alpha: 0.03),
      offset: const Offset(0, 12),
      blurRadius: 12,
    ),
  ];

  static List<BoxShadow> ambientElevated(Color tint) => [
    BoxShadow(
      color: tint.withValues(alpha: 0.03),
      offset: const Offset(0, 12),
      blurRadius: 24,
    ),
  ];

  static List<BoxShadow> accent(Color tint) => [
    BoxShadow(
      color: tint.withValues(alpha: 0.08),
      offset: const Offset(0, 4),
      blurRadius: 6,
    ),
  ];

  static List<BoxShadow> focusRing(Color primary) => [
    BoxShadow(
      color: primary.withValues(alpha: 0.16),
      blurRadius: 0,
      spreadRadius: 3,
    ),
  ];
}
