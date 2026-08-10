/// Border-width scale for the Club Sandwich design system.
///
/// Every `Border.all(width: ...)` in `Ds*` components must come from this
/// scale — never a raw literal — same discipline as [DsSpacing] for gaps.
///
/// "Bento Soft Modern" is a uniform 1px-border language — every border in
/// the Figma reference is [hairline]. [standard] survives only for the
/// input focus-ring affordance. [thick]/[heavy] are deprecated: the old
/// neo-brutalist ink-outline treatment they served no longer exists.
abstract final class DsBorders {
  static const double hairline = 1;
  static const double standard = 2;

  @Deprecated('Neo-brutalist-only. Use hairline or standard.')
  static const double thick = 3;

  @Deprecated('Neo-brutalist-only. Use hairline or standard.')
  static const double heavy = 4;
}
