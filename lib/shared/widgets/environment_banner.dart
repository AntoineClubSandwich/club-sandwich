import 'dart:ui';

import 'package:club_sandwich/core/config/environment.dart';
import 'package:flutter/material.dart';

class AppEnvironmentBanner extends StatelessWidget {
  const AppEnvironmentBanner({
    required this.environment,
    required this.child,
    super.key,
  });

  final AppEnvironment environment;
  final Widget child;

  static const double _barHeight = 28;

  @override
  Widget build(BuildContext context) {
    if (environment != AppEnvironment.preprod) return child;

    final colorScheme = Theme.of(context).colorScheme;
    return Stack(
      children: [
        child,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Semantics(
                  container: true,
                  excludeSemantics: true,
                  label:
                      'Préproduction. Les données peuvent être réinitialisées.',
                  child: Container(
                    width: double.infinity,
                    height: _barHeight,
                    alignment: Alignment.center,
                    color: colorScheme.tertiary.withValues(alpha: 0.75),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'PRÉPRODUCTION · Les données peuvent être réinitialisées',
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
