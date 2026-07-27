import 'package:club_sandwich/shared/widgets/feature_empty_state.dart';
import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) => const FeatureEmptyState(
    title: 'Paramètres',
    message: 'Aucun paramètre configurable pour le moment.',
    icon: Icons.settings_outlined,
  );
}
