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

  @override
  Widget build(BuildContext context) {
    if (environment != AppEnvironment.preprod) return child;

    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Material(
          color: colorScheme.tertiary,
          child: SafeArea(
            bottom: false,
            child: Semantics(
              container: true,
              excludeSemantics: true,
              label: 'Préproduction. Les données peuvent être réinitialisées.',
              child: const SizedBox(
                width: double.infinity,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    'PRÉPRODUCTION\n'
                    'Les données peuvent être réinitialisées.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}
