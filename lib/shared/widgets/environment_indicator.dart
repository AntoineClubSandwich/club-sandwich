import 'package:club_sandwich/core/config/environment.dart';
import 'package:club_sandwich/design_system/components/indicators/ds_badge.dart';
import 'package:club_sandwich/design_system/components/indicators/ds_semantic_variant.dart';
import 'package:flutter/material.dart';

/// Compact environment marker used in navigation without consuming the
/// application content's vertical space.
class AppEnvironmentBadge extends StatelessWidget {
  const AppEnvironmentBadge({required this.environment, super.key});

  final AppEnvironment environment;

  @override
  Widget build(BuildContext context) {
    if (environment != AppEnvironment.preprod) {
      return const SizedBox.shrink();
    }

    return Semantics(
      label: 'Environnement de préproduction',
      child: const DsBadge(
        label: 'PRÉPRODUCTION',
        variant: DsSemanticVariant.warning,
      ),
    );
  }
}
