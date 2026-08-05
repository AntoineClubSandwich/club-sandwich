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
}
