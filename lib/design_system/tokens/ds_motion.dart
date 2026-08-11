import 'package:flutter/animation.dart';

/// Motion tokens for the Club Sandwich design system.
///
/// All `Ds*` components animate exclusively through Flutter's implicit
/// animation widgets (`AnimatedContainer`, `AnimatedOpacity`,
/// `AnimatedScale`, `AnimatedDefaultTextStyle`, ...) using this single
/// duration/curve pair — no `AnimationController`, no bounce/elastic curves.
abstract final class DsMotion {
  static const Duration standard = Duration(milliseconds: 200);
  static const Curve curve = Curves.easeOutCubic;

  /// Slower duration for one-off entrance choreography (scroll reveals,
  /// page transitions) — distinct from [standard], which is reserved for
  /// interactive `Ds*` micro-interactions (hover/press/focus). Still uses
  /// [curve]; only the pacing differs.
  static const Duration entrance = Duration(milliseconds: 380);
}
