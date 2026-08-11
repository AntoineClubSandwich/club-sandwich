import 'package:flutter/widgets.dart';

import '../tokens/ds_motion.dart';

/// Wraps [child] so it fades, slides up and scales in once it scrolls
/// into view — the "Bento Soft Modern" equivalent of a cinematic scroll
/// reveal, kept subtle (a few px of travel, no motion from off-black)
/// instead of the heavier curtain-opening effect it's modeled on.
///
/// Reveals exactly once: after [child] has been shown, further scrolling
/// (including scrolling it back out of view and in again) has no effect.
/// Pass [delay] to stagger a list of these (e.g. `index * 40ms`).
class DsRevealOnScroll extends StatefulWidget {
  const DsRevealOnScroll({
    super.key,
    required this.child,
    this.delay = Duration.zero,
  });

  final Widget child;
  final Duration delay;

  @override
  State<DsRevealOnScroll> createState() => _DsRevealOnScrollState();
}

class _DsRevealOnScrollState extends State<DsRevealOnScroll> {
  bool _visible = false;
  bool _revealScheduled = false;
  ScrollPosition? _scrollPosition;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final position = Scrollable.maybeOf(context)?.position;
    if (position != _scrollPosition) {
      _scrollPosition?.removeListener(_maybeReveal);
      _scrollPosition = position;
      _scrollPosition?.addListener(_maybeReveal);
    }
    // Covers content that's already on screen on first frame (nothing to
    // scroll for it to become visible).
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeReveal());
  }

  @override
  void dispose() {
    _scrollPosition?.removeListener(_maybeReveal);
    super.dispose();
  }

  void _maybeReveal() {
    if (_visible || _revealScheduled || !mounted) return;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    final top = box.localToGlobal(Offset.zero).dy;
    final viewportHeight = MediaQuery.sizeOf(context).height;
    // Heuristic "about to enter/already inside the viewport" check rather
    // than exact intersection-with-scrollable-bounds — plenty accurate for
    // a decorative reveal and avoids depending on RenderAbstractViewport.
    if (top > viewportHeight * 0.94) return;
    _revealScheduled = true;
    Future.delayed(widget.delay, () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      offset: _visible ? Offset.zero : const Offset(0, 0.04),
      duration: DsMotion.entrance,
      curve: DsMotion.curve,
      child: AnimatedOpacity(
        opacity: _visible ? 1 : 0,
        duration: DsMotion.entrance,
        curve: DsMotion.curve,
        child: AnimatedScale(
          scale: _visible ? 1 : 0.98,
          duration: DsMotion.entrance,
          curve: DsMotion.curve,
          child: widget.child,
        ),
      ),
    );
  }
}
