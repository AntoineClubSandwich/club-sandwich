import 'package:flutter/widgets.dart';

/// Shadow tokens for the Club Sandwich design system.
///
/// Deliberately extremely subtle — this system avoids the heavy Material
/// default elevation shadows. `card` is for resting surfaces, `elevated`
/// for surfaces that float above the page (dialogs, dropdown menus, bottom
/// sheets), `focusRing` is a keyboard-focus indicator, not a shadow proper.
abstract final class DsShadows {
  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x0A000000), // #000000 @ 4%
      blurRadius: 2,
      offset: Offset(0, 1),
    ),
  ];

  static const List<BoxShadow> elevated = [
    BoxShadow(
      color: Color(0x14000000), // #000000 @ 8%
      blurRadius: 24,
      offset: Offset(0, 8),
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
