import 'package:club_sandwich/design_system/widgets/club_sandwich_mascot.dart';
import 'package:flutter/material.dart';

class BrandHeader extends StatelessWidget {
  const BrandHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const ClubSandwichMascot(size: 64),
        const SizedBox(height: 12),
        Text(
          'Club Sandwich',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text('Connexion', style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }
}
