import 'package:club_sandwich/shared/widgets/feature_empty_state.dart';
import 'package:flutter/material.dart';

class VolunteersScreen extends StatelessWidget {
  const VolunteersScreen({super.key});

  @override
  Widget build(BuildContext context) => const FeatureEmptyState(
    title: 'Bénévoles',
    message:
        'Les bénévoles associés aux maraudes apparaissent dans les concerts.',
    icon: Icons.groups_outlined,
  );
}
