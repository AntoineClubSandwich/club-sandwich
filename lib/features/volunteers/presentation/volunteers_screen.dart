import 'package:club_sandwich/features/concerts/data/concert_providers.dart';
import 'package:club_sandwich/features/concerts/domain/concert.dart';
import 'package:club_sandwich/features/concerts/domain/maraude_operation.dart';
import 'package:club_sandwich/features/concerts/presentation/maraude_overview_card.dart';
import 'package:club_sandwich/features/volunteers/domain/concert_volunteer_application.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class VolunteersScreen extends ConsumerWidget {
  const VolunteersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(maraudeOverviewProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: overview.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: FilledButton.icon(
            onPressed: () => ref.invalidate(maraudeOverviewProvider),
            icon: const Icon(Icons.refresh),
            label: const Text('Réessayer'),
          ),
        ),
        data: (items) => _VolunteerMaraudes(items: items),
      ),
    );
  }
}

class _VolunteerMaraudes extends StatelessWidget {
  const _VolunteerMaraudes({required this.items});

  final List<MaraudeOverview> items;

  @override
  Widget build(BuildContext context) {
    final ownItems = items
        .where((item) => item.ownStatus != null)
        .toList(growable: false);
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final upcoming =
        ownItems
            .where(
              (item) =>
                  !item.date.isBefore(todayDate) &&
                  item.maraudeStatus != MaraudeStatus.cancelled,
            )
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));
    final history =
        ownItems
            .where(
              (item) =>
                  item.maraudeStatus == MaraudeStatus.completed &&
                  item.ownStatus == ConcertVolunteerStatus.selected,
            )
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 48),
      children: [
        Text('Mes maraudes', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 20),
        if (upcoming.isEmpty)
          const Text('Aucune maraude à venir.')
        else ...[
          Text('À venir', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          for (final item in upcoming)
            MaraudeOverviewCard(
              maraude: item,
              actionLabel: _availabilityLabel(item.ownStatus!),
            ),
        ],
        if (history.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            'Historique personnel',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          for (final item in history)
            MaraudeOverviewCard(
              maraude: item,
              actionLabel: 'Consulter la maraude',
            ),
        ],
      ],
    );
  }
}

String _availabilityLabel(ConcertVolunteerStatus status) {
  return switch (status) {
    ConcertVolunteerStatus.pending => 'Disponibilité transmise',
    ConcertVolunteerStatus.selected => 'Sélectionné',
    ConcertVolunteerStatus.notSelected => 'Non sélectionné',
    ConcertVolunteerStatus.withdrawn => 'Désisté — repositionnement possible',
  };
}
