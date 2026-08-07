import 'package:flutter/material.dart';

import '../../tokens/ds_motion.dart';
import '../../tokens/ds_radius.dart';
import '../../tokens/ds_shadows.dart';
import '../../tokens/ds_spacing.dart';
import '../../tokens/ds_tokens.dart';
import '../ds_pressable.dart';

/// The base "floating card" surface of the design system: white, a hair
/// of border, a hard offset ink shadow — the neo-brutalist signature,
/// never a soft Material elevation. Every other surface component
/// (`DsMetricCard`, the domain showcase cards) is built on top of this
/// one. When [onTap] is set, pressing the card shrinks its shadow offset
/// and nudges the card toward it — simulating it physically pressing
/// onto its own shadow.
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

    Widget buildSurface(bool hovered, bool pressed) {
      final shadowOffsets = elevated
          ? DsShadows.elevated(colors.borderStrong)
          : (hovered
                ? DsShadows.elevated(colors.borderStrong)
                : DsShadows.card(colors.borderStrong));
      final pressDelta = pressed && shadowOffsets.isNotEmpty
          ? shadowOffsets.first.offset
          : Offset.zero;

      return AnimatedContainer(
        duration: DsMotion.standard,
        curve: DsMotion.curve,
        transform: Matrix4.translationValues(pressDelta.dx, pressDelta.dy, 0),
        padding: padding,
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: DsRadius.mdRadius,
          border: Border.all(color: colors.border),
          boxShadow: pressed ? const [] : shadowOffsets,
        ),
        child: child,
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
