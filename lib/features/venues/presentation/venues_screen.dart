import 'package:club_sandwich/shared/widgets/feature_empty_state.dart';
import 'package:flutter/material.dart';

class VenuesScreen extends StatelessWidget {
  const VenuesScreen({super.key});

  @override
  Widget build(BuildContext context) => const FeatureEmptyState(
    title: 'Lieux',
    message: 'Aucun lieu à afficher sur cet écran.',
    icon: Icons.place_outlined,
  );
}
