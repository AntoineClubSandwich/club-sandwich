import 'package:club_sandwich/design_system/tokens/ds_motion.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// A soft fade + scale page transition — the "Bento Soft Modern" stand-in
/// for a cinema-style fade-to-black between pages, minus the black:
/// the incoming page fades and scales in from 0.98 over [DsMotion.entrance].
/// Use for pushes that deserve to feel like "opening" a destination (e.g.
/// list → detail) rather than every route in the app.
CustomTransitionPage<T> dsFadeScalePage<T>({
  required LocalKey key,
  required Widget child,
}) {
  return CustomTransitionPage<T>(
    key: key,
    transitionDuration: DsMotion.entrance,
    reverseTransitionDuration: DsMotion.entrance,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: DsMotion.curve);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.98, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}
