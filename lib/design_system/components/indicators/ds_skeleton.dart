import 'package:flutter/material.dart';

import '../../tokens/ds_radius.dart';
import '../../tokens/ds_tokens.dart';

/// A pulsing placeholder block for content that's still loading.
///
/// Unlike every other `Ds*` component, this drives its animation with a
/// real [AnimationController] rather than Flutter's implicit animation
/// widgets ([DsMotion]'s documented convention) — a continuous loop has
/// no "target value" to animate towards, so the implicit-animation
/// pattern doesn't apply here. This is the one deliberate exception.
class DsSkeleton extends StatefulWidget {
  const DsSkeleton({
    super.key,
    this.width,
    this.height = 14,
    this.borderRadius = DsRadius.xsRadius,
  });

  final double? width;
  final double height;
  final BorderRadius borderRadius;

  @override
  State<DsSkeleton> createState() => _DsSkeletonState();
}

class _DsSkeletonState extends State<DsSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _opacity = Tween<double>(
      begin: 0.45,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<DsTokens>()!.colors;
    return FadeTransition(
      opacity: _opacity,
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: colors.secondarySelectedBg,
          borderRadius: widget.borderRadius,
        ),
      ),
    );
  }
}
