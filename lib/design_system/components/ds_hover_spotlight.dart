import 'package:flutter/material.dart';

import '../tokens/ds_motion.dart';
import '../tokens/ds_radius.dart';
import '../tokens/ds_tokens.dart';

/// Wraps [child] with a soft brand-colored glow that follows the cursor,
/// clipped to [borderRadius] — the "Bento Soft Modern" translation of a
/// spotlight/cursor-light effect: a restrained highlight *inside* a card
/// on hover, not a page-wide halo. No-op on touch (there's no hover
/// event to drive it), so it needs no separate mobile gate.
///
/// Purely decorative — stack it around a [DsCard] (or its content), it
/// doesn't affect layout or hit-testing of [child].
class DsHoverSpotlight extends StatefulWidget {
  const DsHoverSpotlight({
    super.key,
    required this.child,
    this.borderRadius = DsRadius.xlRadius,
    this.radius = 220,
    this.enabled = true,
  });

  final Widget child;
  final BorderRadius borderRadius;

  /// Radius of the glow, in logical pixels.
  final double radius;

  /// When false, renders [child] as-is — no `MouseRegion`, no glow. For
  /// call sites reusing this on both interactive and non-interactive
  /// variants of the same card (e.g. `canOpen: false`), where a glow with
  /// no tap target underneath it would read as a mistake.
  final bool enabled;

  @override
  State<DsHoverSpotlight> createState() => _DsHoverSpotlightState();
}

class _DsHoverSpotlightState extends State<DsHoverSpotlight> {
  Offset? _localPosition;

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    final colors = Theme.of(context).extension<DsTokens>()!.colors;

    return MouseRegion(
      onHover: (event) => setState(() => _localPosition = event.localPosition),
      onExit: (_) => setState(() => _localPosition = null),
      child: ClipRRect(
        borderRadius: widget.borderRadius,
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            widget.child,
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedOpacity(
                  opacity: _localPosition == null ? 0 : 1,
                  duration: DsMotion.standard,
                  curve: DsMotion.curve,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final position =
                          _localPosition ??
                          constraints.biggest.center(Offset.zero);
                      return DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: FractionalOffset(
                              constraints.maxWidth == 0
                                  ? 0.5
                                  : position.dx / constraints.maxWidth,
                              constraints.maxHeight == 0
                                  ? 0.5
                                  : position.dy / constraints.maxHeight,
                            ),
                            radius: constraints.maxWidth == 0
                                ? 0.5
                                : widget.radius / constraints.maxWidth,
                            colors: [
                              colors.primary.withValues(alpha: 0.08),
                              colors.primary.withValues(alpha: 0),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
