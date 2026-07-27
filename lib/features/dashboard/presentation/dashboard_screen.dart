import 'package:club_sandwich/shared/widgets/feature_empty_state.dart';
import 'package:flutter/material.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) => const FeatureEmptyState(
    title: 'Tableau de bord',
    message: 'Aucun indicateur disponible pour le moment.',
    icon: Icons.dashboard_outlined,
  );
}
