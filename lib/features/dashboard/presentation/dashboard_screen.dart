import 'package:club_sandwich/features/concerts/data/concert_providers.dart';
import 'package:club_sandwich/features/concerts/domain/concert.dart';
import 'package:club_sandwich/features/concerts/domain/maraude_operation.dart';
import 'package:club_sandwich/features/concerts/presentation/maraude_overview_card.dart';
import 'package:club_sandwich/features/volunteers/domain/concert_volunteer_application.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(maraudeOverviewProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: overview.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => _DashboardError(
          onRetry: () => ref.invalidate(maraudeOverviewProvider),
        ),
        data: (items) => _DashboardContent(items: items),
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({required this.items});

  final List<MaraudeOverview> items;

  @override
  Widget build(BuildContext context) {
    final isAdmin = items.any((item) => item.isAdmin);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 48),
      children: [
        Text(
          'Tableau de bord',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 6),
        const Text('Ce qui nécessite votre attention maintenant.'),
        const SizedBox(height: 24),
        if (items.isEmpty)
          const _DashboardEmpty()
        else if (isAdmin)
          _AdminDashboard(items: items)
        else
          _VolunteerDashboard(items: items),
      ],
    );
  }
}

class _AdminDashboard extends StatelessWidget {
  const _AdminDashboard({required this.items});

  final List<MaraudeOverview> items;

  @override
  Widget build(BuildContext context) {
    final today = _day(DateTime.now());
    final upcoming =
        items
            .where(
              (item) =>
                  !item.date.isBefore(today) &&
                  item.maraudeStatus != MaraudeStatus.completed &&
                  item.maraudeStatus != MaraudeStatus.cancelled,
            )
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));
    final openWithApplications = items
        .where(
          (item) =>
              item.maraudeStatus == MaraudeStatus.open &&
              item.applicationCount > 0,
        )
        .toList();
    final teamNotValidated = items
        .where(
          (item) =>
              item.maraudeStatus == MaraudeStatus.draft ||
              item.maraudeStatus == MaraudeStatus.open,
        )
        .toList();
    final todayMaraudes = items
        .where((item) => _day(item.date) == today)
        .toList();
    final pastNotClosed = items
        .where(
          (item) =>
              item.date.isBefore(today) &&
              item.maraudeStatus != MaraudeStatus.completed &&
              item.maraudeStatus != MaraudeStatus.cancelled,
        )
        .toList();
    final history = items
        .where(
          (item) =>
              item.maraudeStatus == MaraudeStatus.completed ||
              item.maraudeStatus == MaraudeStatus.cancelled,
        )
        .take(5)
        .toList();

    return Column(
      children: [
        _DashboardSection(
          title: 'Prochaines maraudes',
          items: upcoming.take(5).toList(),
          actionLabel: 'Ouvrir la fiche opérationnelle',
        ),
        _DashboardSection(
          title: 'Candidatures à examiner',
          items: openWithApplications,
          actionLabel: 'Constituer l’équipe',
        ),
        _DashboardSection(
          title: 'Équipes non validées',
          items: teamNotValidated,
          actionLabel: 'Valider l’organisation retenue',
        ),
        _DashboardSection(
          title: 'Aujourd’hui',
          items: todayMaraudes,
          actionLabel: 'Ouvrir la maraude',
        ),
        _DashboardSection(
          title: 'Maraudes passées non clôturées',
          items: pastNotClosed,
          actionLabel: 'Saisir le compte rendu',
        ),
        _DashboardSection(
          title: 'Dernières maraudes clôturées',
          items: history,
          actionLabel: 'Consulter l’historique',
        ),
      ],
    );
  }
}

class _VolunteerDashboard extends StatelessWidget {
  const _VolunteerDashboard({required this.items});

  final List<MaraudeOverview> items;

  @override
  Widget build(BuildContext context) {
    final today = _day(DateTime.now());
    final selected =
        items
            .where(
              (item) =>
                  !item.date.isBefore(today) &&
                  item.ownStatus == ConcertVolunteerStatus.selected,
            )
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));
    final pending = items
        .where(
          (item) =>
              !item.date.isBefore(today) &&
              item.ownStatus == ConcertVolunteerStatus.pending,
        )
        .toList();

    return Column(
      children: [
        _DashboardSection(
          title: 'Prochaine mission',
          items: selected.take(1).toList(),
          actionLabel: 'Voir les informations pratiques',
        ),
        _DashboardSection(
          title: 'Disponibilités en attente',
          items: pending,
          actionLabel: 'En attente de sélection',
        ),
      ],
    );
  }
}

class _DashboardSection extends StatelessWidget {
  const _DashboardSection({
    required this.title,
    required this.items,
    required this.actionLabel,
  });

  final String title;
  final List<MaraudeOverview> items;
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          for (final item in items)
            MaraudeOverviewCard(maraude: item, actionLabel: actionLabel),
        ],
      ),
    );
  }
}

class _DashboardEmpty extends StatelessWidget {
  const _DashboardEmpty();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text('Aucune action en attente.'),
      ),
    );
  }
}

class _DashboardError extends StatelessWidget {
  const _DashboardError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FilledButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh),
        label: const Text('Réessayer'),
      ),
    );
  }
}

DateTime _day(DateTime value) => DateTime(value.year, value.month, value.day);
