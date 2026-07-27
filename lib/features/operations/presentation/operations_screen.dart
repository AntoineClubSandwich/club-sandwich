import 'package:club_sandwich/shared/widgets/feature_empty_state.dart';
import 'package:flutter/material.dart';

class OperationsScreen extends StatelessWidget {
  const OperationsScreen({super.key});

  @override
  Widget build(BuildContext context) => const FeatureEmptyState(
    title: 'Opérations',
    message: 'Aucune opération à afficher.',
    icon: Icons.local_shipping_outlined,
  );
}
