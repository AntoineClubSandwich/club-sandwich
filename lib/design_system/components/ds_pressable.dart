import 'package:flutter/widgets.dart';

import '../tokens/ds_motion.dart';

/// Wraps [child] in a subtle scale-down transform when [pressed] — the
/// "Bento Soft Modern" press affordance shared by [DsCard]/`DsPrimaryButton`/
/// `DsSecondaryButton`. Replaces the old neo-brutalist illusion of the
/// widget translating into its own hard offset shadow, which doesn't read
/// as a press against this style's soft blurred shadows.
class DsPressScale extends StatelessWidget {
  const DsPressScale({super.key, required this.pressed, required this.child});

  final bool pressed;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedScale(
    scale: pressed ? 0.98 : 1,
    duration: DsMotion.standard,
    curve: DsMotion.curve,
    child: child,
  );
}

/// Hover/press state passed to a [DsPressable] builder.
class DsInteractionState {
  const DsInteractionState({this.hovered = false, this.pressed = false});

  final bool hovered;
  final bool pressed;
}

typedef DsInteractiveBuilder =
    Widget Function(BuildContext context, DsInteractionState state);

/// Shared hover/press tracking for interactive `Ds*` components.
///
/// Every interactive component (buttons, filter chips, interactive cards,
/// calendar cells, dropdown items, ...) needs the same hovered/pressed
/// bookkeeping to drive its `AnimatedContainer` state — this widget is
/// that bookkeeping, factored out once rather than repeated in every
/// component. It renders no visuals of its own; [builder] does.
class DsPressable extends StatefulWidget {
  const DsPressable({
    super.key,
    required this.builder,
    this.onTap,
    this.enabled = true,
  });

  final DsInteractiveBuilder builder;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  State<DsPressable> createState() => _DsPressableState();
}

class _DsPressableState extends State<DsPressable> {
  bool _hovered = false;
  bool _pressed = false;

  bool get _interactive => widget.enabled && widget.onTap != null;

  @override
  Widget build(BuildContext context) {
    final state = DsInteractionState(
      hovered: _hovered && _interactive,
      pressed: _pressed && _interactive,
    );
    return MouseRegion(
      cursor: _interactive ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) {
        if (_interactive) setState(() => _hovered = true);
      },
      onExit: (_) {
        if (_hovered) setState(() => _hovered = false);
      },
      child: GestureDetector(
        onTap: widget.enabled ? widget.onTap : null,
        onTapDown: _interactive ? (_) => setState(() => _pressed = true) : null,
        onTapUp: _interactive ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: _interactive
            ? () => setState(() => _pressed = false)
            : null,
        child: widget.builder(context, state),
      ),
    );
  }
}
