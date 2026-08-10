import 'package:flutter/material.dart';

import '../../tokens/ds_motion.dart';
import '../../tokens/ds_radius.dart';
import '../../tokens/ds_shadows.dart';
import '../../tokens/ds_spacing.dart';
import '../../tokens/ds_tokens.dart';
import '../ds_pressable.dart';

/// The base "floating card" surface of the design system: white, a hair
/// of border, a soft blurred ambient shadow — never a hard offset "ink"
/// shadow. Every other surface component (`DsMetricCard`, the domain
/// showcase cards) is built on top of this one. When [onTap] is set,
/// pressing the card scales it down slightly ([DsPressScale]) and drops
/// its shadow.
class DsCard extends StatelessWidget {
  const DsCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(DsSpacing.lg),
    this.onTap,
    this.elevated = false,
    this.borderRadius = DsRadius.xlRadius,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final bool elevated;

  /// Defaults to [DsRadius.xlRadius] (16px — stat/content cards). Some
  /// smaller surfaces (quick-action tiles, filter accordions) want the
  /// tighter [DsRadius.lgRadius] (12px) instead; override explicitly
  /// rather than introducing a second card primitive for that.
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<DsTokens>()!;
    final colors = tokens.colors;

    Widget buildSurface(bool hovered, bool pressed) {
      final shadow = elevated || hovered
          ? DsShadows.ambientElevated(colors.textPrimary)
          : DsShadows.ambient(colors.textPrimary);

      return DsPressScale(
        pressed: pressed,
        child: AnimatedContainer(
          duration: DsMotion.standard,
          curve: DsMotion.curve,
          padding: padding,
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: borderRadius,
            border: Border.all(color: colors.border),
            boxShadow: pressed ? const [] : shadow,
          ),
          child: child,
        ),
      );
    }

    if (onTap == null) {
      return buildSurface(false, false);
    }

    return DsPressable(
      onTap: onTap,
      builder: (context, state) => buildSurface(state.hovered, state.pressed),
    );
  }
}
