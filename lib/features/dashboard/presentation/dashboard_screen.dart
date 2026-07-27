import 'package:club_sandwich/features/auth/application/auth_providers.dart';
import 'package:club_sandwich/features/auth/domain/user_account.dart';
import 'package:club_sandwich/features/concerts/data/concert_providers.dart';
import 'package:club_sandwich/features/concerts/domain/concert.dart';
import 'package:club_sandwich/features/concerts/domain/maraude_operation.dart';
import 'package:club_sandwich/features/concerts/presentation/maraude_overview_card.dart';
import 'package:club_sandwich/features/volunteers/domain/concert_volunteer_application.dart';
import 'package:club_sandwich/features/invitations/data/invitation_providers.dart';
import 'package:club_sandwich/features/invitations/domain/invitation_campaign.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(maraudeOverviewProvider);
    final contextRole = ref.watch(currentUserContextProvider).value?.role;
    final invitations =
        ref.watch(invitationCampaignsProvider).value ??
        const <InvitationCampaign>[];
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: overview.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => _DashboardError(
          onRetry: () => ref.invalidate(maraudeOverviewProvider),
        ),
        data: (items) => _DashboardContent(
          items: items,
          role:
              contextRole ??
              (items.any((item) => item.isAdmin)
                  ? AppUserRole.admin
                  : AppUserRole.volunteer),
          invitations: invitations,
        ),
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({
    required this.items,
    required this.role,
    required this.invitations,
  });

  final List<MaraudeOverview> items;
  final AppUserRole role;
  final List<InvitationCampaign> invitations;

  @override
  Widget build(BuildContext context) {
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
        if (items.isEmpty && invitations.isEmpty)
          const _DashboardEmpty()
        else if (role == AppUserRole.admin)
          _AdminDashboard(items: items)
        else if (role == AppUserRole.promoter)
          _PromoterDashboard(items: items, invitations: invitations)
        else
          _VolunteerDashboard(items: items),
      ],
    );
  }
}

class _PromoterDashboard extends StatelessWidget {
  const _PromoterDashboard({required this.items, required this.invitations});

  final List<MaraudeOverview> items;
  final List<InvitationCampaign> invitations;

  @override
  Widget build(BuildContext context) {
    final today = _day(DateTime.now());
    final upcoming =
        items
            .where(
              (item) =>
                  !item.date.isBefore(today) &&
                  item.maraudeStatus != MaraudeStatus.cancelled,
            )
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));
    final activeInvitations = invitations
        .where(
          (campaign) =>
              campaign.status == InvitationCampaignStatus.open ||
              campaign.status == InvitationCampaignStatus.draft,
        )
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              onPressed: () => context.go('/maraudes'),
              icon: const Icon(Icons.add),
              label: const Text('Ouvrir une maraude'),
            ),
            FilledButton.tonalIcon(
              onPressed: () => context.go('/invitations'),
              icon: const Icon(Icons.confirmation_number_outlined),
              label: const Text('Ouvrir des invitations'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _DashboardSection(
          title: 'Prochaines maraudes',
          items: upcoming.take(5).toList(),
          actionLabel: 'Voir la maraude',
        ),
        if (activeInvitations.isNotEmpty)
          Card(
            child: ListTile(
              leading: const Icon(Icons.confirmation_number_outlined),
              title: Text(
                '${activeInvitations.length} campagne(s) d’invitations en cours',
              ),
              subtitle: const Text('Consulter les candidatures et résultats'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/invitations'),
            ),
          ),
        if (items.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text(
            'Activité récente',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          for (final item in items.take(3)) MaraudeOverviewCard(maraude: item),
        ],
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
