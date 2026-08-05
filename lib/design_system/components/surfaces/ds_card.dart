import 'package:flutter/material.dart';

import '../../tokens/ds_motion.dart';
import '../../tokens/ds_radius.dart';
import '../../tokens/ds_shadows.dart';
import '../../tokens/ds_spacing.dart';
import '../../tokens/ds_tokens.dart';
import '../ds_pressable.dart';

/// The base "floating card" surface of the design system: white, a hair
/// of border, an extremely subtle shadow — never a heavy Material
/// elevation. Every other surface component (`DsMetricCard`, the domain
/// showcase cards) is built on top of this one.
class DsCard extends StatelessWidget {
  const DsCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(DsSpacing.lg),
    this.onTap,
    this.elevated = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<DsTokens>()!;
    final colors = tokens.colors;

    Widget buildSurface(bool hovered) {
      return AnimatedContainer(
        duration: DsMotion.standard,
        curve: DsMotion.curve,
        padding: padding,
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: DsRadius.lgRadius,
          border: Border.all(color: colors.border),
          boxShadow: elevated
              ? DsShadows.elevated
              : (hovered ? DsShadows.elevated : DsShadows.card),
        ),
        child: child,
      );
    }

    if (onTap == null) {
      return buildSurface(false);
    }

    return DsPressable(
      onTap: onTap,
      builder: (context, state) => AnimatedScale(
        scale: state.pressed
            ? 0.99
            : state.hovered
            ? 1.01
            : 1,
        duration: DsMotion.standard,
        curve: DsMotion.curve,
        child: buildSurface(state.hovered),
      ),
    );
  }
}
