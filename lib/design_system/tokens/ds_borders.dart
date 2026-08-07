/// Border-width scale for the Club Sandwich design system.
///
/// Every `Border.all(width: ...)` in `Ds*` components must come from this
/// scale — never a raw literal — same discipline as [DsSpacing] for gaps.
abstract final class DsBorders {
  static const double hairline = 1;
  static const double standard = 2;
  static const double thick = 3;
  static const double heavy = 4;
}
