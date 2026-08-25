import 'package:flutter/material.dart';

/// Responsive, vertically centred shell shared by the authentication screens.
///
/// Keeping the scroll view as the viewport-sized widget prevents a card with an
/// intrinsic desktop width from widening the whole page on narrow screens.
class AuthCardLayout extends StatelessWidget {
  const AuthCardLayout({
    required this.child,
    this.maxWidth = 420,
    this.pagePadding = const EdgeInsets.all(24),
    this.cardPadding = const EdgeInsets.all(32),
    super.key,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsets pagePadding;
  final EdgeInsets cardPadding;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight > pagePadding.vertical
            ? constraints.maxHeight - pagePadding.vertical
            : 0.0;
        return SingleChildScrollView(
          padding: pagePadding,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: availableHeight),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Card(
                  child: Padding(padding: cardPadding, child: child),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
