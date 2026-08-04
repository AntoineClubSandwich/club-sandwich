import 'package:club_sandwich/features/auth/application/auth_providers.dart';
import 'package:club_sandwich/features/auth/domain/user_account.dart';
import 'package:club_sandwich/features/concerts/data/concert_providers.dart';
import 'package:club_sandwich/features/concerts/domain/concert.dart';
import 'package:club_sandwich/features/concerts/domain/maraude_operation.dart';
import 'package:club_sandwich/features/concerts/presentation/maraude_list_section.dart';
import 'package:club_sandwich/features/concerts/presentation/maraude_overview_card.dart';
import 'package:club_sandwich/features/exports/presentation/maraude_export_dialog.dart';
import 'package:club_sandwich/features/volunteers/data/concert_volunteer_providers.dart';
import 'package:club_sandwich/features/volunteers/data/volunteer_document_providers.dart';
import 'package:club_sandwich/features/volunteers/domain/concert_volunteer_application.dart';
import 'package:club_sandwich/features/volunteers/domain/volunteer_document.dart';
import 'package:club_sandwich/features/invitations/data/invitation_providers.dart';
import 'package:club_sandwich/features/invitations/domain/invitation_campaign.dart';
import 'package:club_sandwich/shared/utils/error_messages.dart';
import 'package:club_sandwich/shared/widgets/app_state_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(maraudeOverviewProvider);
    final contextRole = ref.watch(currentUserContextProvider).value?.role;
    final invitationCampaigns = ref.watch(invitationCampaignsProvider);
    final invitations =
        invitationCampaigns.value ?? const <InvitationCampaign>[];
    final creditSummary = ref.watch(volunteerCreditSummaryProvider).value;
    final hasPendingDocuments =
        ref.watch(pendingVolunteerDocumentsProvider).value?.isNotEmpty == true;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: overview.when(
        loading: () =>
            const AppLoadingState(label: 'Chargement du tableau de bord'),
        error: (_, _) => AppErrorState(
          message: 'Impossible de charger le tableau de bord.',
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
          invitationsUnavailable: invitationCampaigns.hasError,
          onRetryInvitations: () => ref.invalidate(invitationCampaignsProvider),
          creditSummary: creditSummary,
          hasPendingDocuments: hasPendingDocuments,
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
    required this.invitationsUnavailable,
    required this.onRetryInvitations,
    this.creditSummary,
    this.hasPendingDocuments = false,
  });

  final List<MaraudeOverview> items;
  final AppUserRole role;
  final List<InvitationCampaign> invitations;
  final bool invitationsUnavailable;
  final VoidCallback onRetryInvitations;
  final VolunteerCreditSummary? creditSummary;
  final bool hasPendingDocuments;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 48),
      children: [
        Text(
          role == AppUserRole.admin ? 'Tableau de bord' : 'Accueil',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 6),
        Text(
          role == AppUserRole.admin
              ? 'Ce qui nécessite votre attention maintenant.'
              : 'Votre impact et vos prochaines actions.',
        ),
        if (role != AppUserRole.admin) ...[
          const SizedBox(height: 24),
          _AchievementSummary(
            role: role,
            items: items,
            invitations: invitations,
            creditSummary: creditSummary,
          ),
          const SizedBox(height: 28),
          Text(
            'À faire maintenant',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ],
        if (invitationsUnavailable) ...[
          const SizedBox(height: 16),
          _DashboardWarning(onRetry: onRetryInvitations),
        ],
        const SizedBox(height: 24),
        if (items.isEmpty &&
            invitations.isEmpty &&
            !(role == AppUserRole.admin && hasPendingDocuments))
          const _DashboardEmpty()
        else if (role == AppUserRole.admin)
          _AdminDashboard(items: items, invitations: invitations)
        else if (role == AppUserRole.promoter)
          _PromoterDashboard(items: items, invitations: invitations)
        else
          _VolunteerDashboard(items: items, invitations: invitations),
      ],
    );
  }
}

class _AchievementSummary extends StatelessWidget {
  const _AchievementSummary({
    required this.role,
    required this.items,
    required this.invitations,
    this.creditSummary,
  });

  final AppUserRole role;
  final List<MaraudeOverview> items;
  final List<InvitationCampaign> invitations;
  final VolunteerCreditSummary? creditSummary;

  @override
  Widget build(BuildContext context) {
    final completed = items
        .where((item) => item.maraudeStatus == MaraudeStatus.completed)
        .toList(growable: false);
    final totalWeight = completed.fold<double>(
      0,
      (sum, item) => sum + (item.totalWeightKg ?? 0),
    );
    final metrics = role == AppUserRole.volunteer
        ? [
            ('Maraudes réalisées', '${completed.length}'),
            ('Impact collectif', '${_dashboardNumber(totalWeight)} kg'),
            (
              'Invitations obtenues',
              '${invitations.where((campaign) => campaign.ownApplication?.status == InvitationApplicationStatus.selected).length}',
            ),
            ('Crédits disponibles', '${creditSummary?.available ?? '—'}'),
          ]
        : [
            ('Maraudes réalisées', '${completed.length}'),
            ('Collecte accompagnée', '${_dashboardNumber(totalWeight)} kg'),
            ('Campagnes d’invitations', '${invitations.length}'),
          ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          role == AppUserRole.volunteer
              ? 'Votre engagement'
              : 'Votre contribution',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 136,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: metrics.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final metric = metrics[index];
              return SizedBox(
                width: 200,
                child: Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          metric.$2,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(metric.$1),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (role == AppUserRole.volunteer && creditSummary != null) ...[
          const SizedBox(height: 16),
          _CreditProgress(summary: creditSummary!),
        ],
      ],
    );
  }
}

class _CreditProgress extends StatelessWidget {
  const _CreditProgress({required this.summary});
  final VolunteerCreditSummary summary;

  static const _threshold = 3;

  @override
  Widget build(BuildContext context) {
    final eligible = summary.available >= _threshold;
    final progress = (summary.available / _threshold).clamp(0, 1).toDouble();
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              eligible
                  ? 'Vous êtes éligible aux invitations'
                  : 'Progression vers les invitations',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                color: eligible ? Colors.green : null,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              eligible
                  ? '${summary.available} crédits disponibles — vous pouvez candidater aux invitations.'
                  : '${summary.available}/$_threshold crédits pour pouvoir candidater aux invitations.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardWarning extends StatelessWidget {
  const _DashboardWarning({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      color: colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          children: [
            Icon(
              Icons.warning_amber_outlined,
              color: colorScheme.onErrorContainer,
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Les invitations sont temporairement indisponibles.'),
            ),
            TextButton(onPressed: onRetry, child: const Text('Réessayer')),
          ],
        ),
      ),
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
                  item.maraudeStatus != MaraudeStatus.completed &&
                  item.maraudeStatus != MaraudeStatus.cancelled,
            )
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));
    final upcomingIds = upcoming.map((item) => item.concertId).toSet();
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
              label: const Text('Nouvelle campagne'),
            ),
            OutlinedButton.icon(
              key: const ValueKey('open-export-dialog-button'),
              onPressed: () =>
                  showMaraudeExportDialog(context, AppUserRole.promoter),
              icon: const Icon(Icons.file_download_outlined),
              label: const Text('Exporter les indicateurs'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        MaraudeListSection(
          title: 'Prochaines maraudes',
          items: upcoming.take(5).toList(),
          actionLabel: 'Voir la maraude',
        ),
        _InvitationDashboardSection(
          role: AppUserRole.promoter,
          campaigns: activeInvitations,
        ),
        if (items.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text(
            'Activité récente',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          for (final item
              in items
                  .where((item) => !upcomingIds.contains(item.concertId))
                  .take(3))
            MaraudeOverviewCard(maraude: item),
        ],
      ],
    );
  }
}

class _AdminDashboard extends StatelessWidget {
  const _AdminDashboard({required this.items, required this.invitations});

  final List<MaraudeOverview> items;
  final List<InvitationCampaign> invitations;

  @override
  Widget build(BuildContext context) {
    final today = _day(DateTime.now());
    final todayMaraudes = items
        .where(
          (item) =>
              _day(item.date) == today &&
              item.maraudeStatus != MaraudeStatus.completed &&
              item.maraudeStatus != MaraudeStatus.cancelled,
        )
        .toList();
    final todayIds = todayMaraudes.map((item) => item.concertId).toSet();
    final confirmationsPending = items
        .where(
          (item) =>
              !todayIds.contains(item.concertId) &&
              !item.date.isBefore(today) &&
              item.pendingConfirmationCount > 0 &&
              item.maraudeStatus != MaraudeStatus.completed &&
              item.maraudeStatus != MaraudeStatus.cancelled,
        )
        .toList();
    final confirmationIds = confirmationsPending
        .map((item) => item.concertId)
        .toSet();
    final openWithApplications = items
        .where(
          (item) =>
              !todayIds.contains(item.concertId) &&
              !confirmationIds.contains(item.concertId) &&
              !item.date.isBefore(today) &&
              item.maraudeStatus == MaraudeStatus.open &&
              item.pendingApplicationCount > 0,
        )
        .toList();
    final applicationIds = openWithApplications
        .map((item) => item.concertId)
        .toSet();
    final teamNotValidated = items
        .where(
          (item) =>
              !todayIds.contains(item.concertId) &&
              !applicationIds.contains(item.concertId) &&
              !confirmationIds.contains(item.concertId) &&
              !item.date.isBefore(today) &&
              item.selectedCount == 0 &&
              (item.maraudeStatus == MaraudeStatus.draft ||
                  item.maraudeStatus == MaraudeStatus.open),
        )
        .toList();
    final teamNotValidatedIds = teamNotValidated
        .map((item) => item.concertId)
        .toSet();
    final upcoming =
        items
            .where(
              (item) =>
                  !item.date.isBefore(today) &&
                  !todayIds.contains(item.concertId) &&
                  !applicationIds.contains(item.concertId) &&
                  !confirmationIds.contains(item.concertId) &&
                  !teamNotValidatedIds.contains(item.concertId) &&
                  item.maraudeStatus != MaraudeStatus.completed &&
                  item.maraudeStatus != MaraudeStatus.cancelled,
            )
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));
    final pastNotClosed = items
        .where(
          (item) =>
              item.date.isBefore(today) &&
              item.maraudeStatus != MaraudeStatus.completed &&
              item.maraudeStatus != MaraudeStatus.cancelled,
        )
        .toList();
    final creditsToValidate = items
        .where(
          (item) =>
              item.maraudeStatus == MaraudeStatus.completed &&
              item.pendingCreditValidationCount > 0,
        )
        .toList();
    final creditsToValidateIds = creditsToValidate
        .map((item) => item.concertId)
        .toSet();
    final history = items
        .where(
          (item) =>
              !creditsToValidateIds.contains(item.concertId) &&
              (item.maraudeStatus == MaraudeStatus.completed ||
                  item.maraudeStatus == MaraudeStatus.cancelled),
        )
        .take(5)
        .toList();

    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            key: const ValueKey('open-export-dialog-button'),
            onPressed: () =>
                showMaraudeExportDialog(context, AppUserRole.admin),
            icon: const Icon(Icons.file_download_outlined),
            label: const Text('Exporter les indicateurs'),
          ),
        ),
        const SizedBox(height: 24),
        MaraudeListSection(
          title: 'Prochaines maraudes',
          items: upcoming.take(5).toList(),
          actionLabel: 'Ouvrir la fiche opérationnelle',
        ),
        MaraudeListSection(
          title: 'Candidatures à examiner',
          items: openWithApplications,
          actionLabel: 'Constituer l’équipe',
        ),
        MaraudeListSection(
          title: 'Équipes non validées',
          items: teamNotValidated,
          actionLabel: 'Valider l’organisation retenue',
        ),
        MaraudeListSection(
          title: 'Confirmations bénévoles en attente',
          items: confirmationsPending,
          actionLabel: 'Suivre les confirmations',
        ),
        MaraudeListSection(
          title: 'Aujourd’hui',
          items: todayMaraudes,
          actionLabelFor: _adminTodayAction,
        ),
        MaraudeListSection(
          title: 'Maraudes passées non clôturées',
          items: pastNotClosed,
          actionLabel: 'Saisir le compte rendu',
        ),
        MaraudeListSection(
          title: 'Présences et crédits à valider',
          items: creditsToValidate,
          actionLabelFor: (item) =>
              '${item.pendingCreditValidationCount} '
              '${item.pendingCreditValidationCount == 1 ? 'crédit à valider' : 'crédits à valider'}',
        ),
        MaraudeListSection(
          title: 'Dernières maraudes clôturées',
          items: history,
          actionLabel: 'Consulter l’historique',
        ),
        _InvitationDashboardSection(
          role: AppUserRole.admin,
          campaigns: invitations
              .where(
                (campaign) =>
                    campaign.status == InvitationCampaignStatus.open ||
                    campaign.status == InvitationCampaignStatus.draft ||
                    campaign.awaitingConfirmationCount > 0,
              )
              .toList(growable: false),
        ),
        const _PendingDocumentsSection(),
      ],
    );
  }
}

class _PendingDocumentsSection extends ConsumerWidget {
  const _PendingDocumentsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingVolunteerDocumentsProvider);
    final items = pending.value ?? const <PendingVolunteerDocument>[];
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Documents en attente',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          for (final document in items)
            _PendingDocumentCard(document: document),
        ],
      ),
    );
  }
}

class _PendingDocumentCard extends ConsumerStatefulWidget {
  const _PendingDocumentCard({required this.document});
  final PendingVolunteerDocument document;

  @override
  ConsumerState<_PendingDocumentCard> createState() =>
      _PendingDocumentCardState();
}

class _PendingDocumentCardState extends ConsumerState<_PendingDocumentCard> {
  bool _busy = false;

  Future<void> _openFile() async {
    try {
      final url = await ref
          .read(volunteerDocumentRepositoryProvider)
          .signedUrl(widget.document.storagePath);
      await launchUrl(Uri.parse(url));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              describeError(error, 'Impossible d’ouvrir ce document.'),
            ),
          ),
        );
      }
    }
  }

  Future<void> _review(VolunteerDocumentStatus status) async {
    String? reason;
    if (status == VolunteerDocumentStatus.rejected) {
      final controller = TextEditingController();
      reason = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Refuser ce document'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Motif du refus'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, controller.text),
              child: const Text('Refuser'),
            ),
          ],
        ),
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.dispose();
      });
      if (reason == null || reason.trim().isEmpty || !mounted) return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(volunteerDocumentRepositoryProvider)
          .reviewDocument(
            documentId: widget.document.id,
            status: status,
            rejectionReason: reason?.trim(),
          );
      ref.invalidate(pendingVolunteerDocumentsProvider);
      ref.invalidate(volunteerDocumentsProvider(widget.document.userId));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(describeError(error, 'Impossible de valider.')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.document.displayName,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(widget.document.displayLabel),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton.icon(
                  onPressed: _busy ? null : _openFile,
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Voir le document'),
                ),
                FilledButton.tonalIcon(
                  onPressed: _busy
                      ? null
                      : () => _review(VolunteerDocumentStatus.approved),
                  icon: const Icon(Icons.check),
                  label: const Text('Valider'),
                ),
                OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _review(VolunteerDocumentStatus.rejected),
                  icon: const Icon(Icons.close),
                  label: const Text('Refuser'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _VolunteerDashboard extends StatelessWidget {
  const _VolunteerDashboard({required this.items, required this.invitations});

  final List<MaraudeOverview> items;
  final List<InvitationCampaign> invitations;

  @override
  Widget build(BuildContext context) {
    final today = _day(DateTime.now());
    final open = items.where((item) => item.isOpenForApplication).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final confirmationPending =
        items
            .where(
              (item) =>
                  !item.date.isBefore(today) &&
                  item.ownStatus == ConcertVolunteerStatus.selected &&
                  item.ownConfirmationStatus !=
                      VolunteerConfirmationStatus.confirmed,
            )
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));
    final selected =
        items
            .where(
              (item) =>
                  !item.date.isBefore(today) &&
                  item.ownStatus == ConcertVolunteerStatus.selected &&
                  item.maraudeStatus != MaraudeStatus.completed &&
                  item.maraudeStatus != MaraudeStatus.cancelled &&
                  item.ownConfirmationStatus ==
                      VolunteerConfirmationStatus.confirmed,
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
        MaraudeListSection(
          title: 'Maraudes ouvertes',
          items: open,
          actionLabel: 'Je me propose',
        ),
        MaraudeListSection(
          title: 'Participation à confirmer',
          items: confirmationPending,
          actionLabel: 'Confirmer ma participation',
        ),
        MaraudeListSection(
          title: 'Prochaine mission',
          items: selected.take(1).toList(),
          actionLabel: 'Voir les informations pratiques',
        ),
        MaraudeListSection(
          title: 'Disponibilités en attente',
          items: pending,
          actionLabel: 'En attente de sélection',
        ),
        _InvitationDashboardSection(
          role: AppUserRole.volunteer,
          campaigns: invitations,
        ),
      ],
    );
  }
}

class _InvitationDashboardSection extends StatelessWidget {
  const _InvitationDashboardSection({
    required this.role,
    required this.campaigns,
  });

  final AppUserRole role;
  final List<InvitationCampaign> campaigns;

  @override
  Widget build(BuildContext context) {
    final visible = campaigns.where(_requiresInvitationAttention).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (visible.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Invitations nécessitant votre attention',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          for (final campaign in visible.take(5))
            Card(
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => context.go('/invitations'),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              campaign.title,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Chip(label: Text(_invitationStatus(campaign))),
                        ],
                      ),
                      if (campaign.organizationName != null)
                        Text(campaign.organizationName!),
                      const SizedBox(height: 6),
                      Text(_invitationSummary(campaign)),
                      const SizedBox(height: 10),
                      Text(
                        _invitationAction(campaign),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  bool _requiresInvitationAttention(InvitationCampaign campaign) {
    if (role != AppUserRole.volunteer) {
      return campaign.status == InvitationCampaignStatus.open ||
          campaign.status == InvitationCampaignStatus.draft ||
          campaign.awaitingConfirmationCount > 0;
    }
    return campaign.status == InvitationCampaignStatus.open ||
        campaign.ownApplication?.status ==
            InvitationApplicationStatus.selected ||
        campaign.ownApplication?.status == InvitationApplicationStatus.pending;
  }

  String _invitationStatus(InvitationCampaign campaign) {
    if (role == AppUserRole.volunteer && campaign.ownApplication != null) {
      return campaign.ownApplication!.status.label;
    }
    return campaign.status.label;
  }

  String _invitationSummary(InvitationCampaign campaign) {
    if (role == AppUserRole.volunteer) {
      final application = campaign.ownApplication;
      if (application?.status == InvitationApplicationStatus.selected) {
        return 'Une place vous a été attribuée.';
      }
      if (application?.status == InvitationApplicationStatus.pending) {
        return 'Votre candidature attend une décision.';
      }
      return '${campaign.remainingPlaces} '
          '${campaign.remainingPlaces == 1 ? 'place proposée' : 'places proposées'}.';
    }

    final remaining = campaign.remainingPlaces;
    final summary =
        '${campaign.pendingCount} '
        '${campaign.pendingCount == 1 ? 'décision restante' : 'décisions restantes'}'
        ' · $remaining '
        '${remaining == 1 ? 'place restante' : 'places restantes'}';
    if (campaign.awaitingConfirmationCount == 0) return summary;
    return '$summary · ${campaign.awaitingConfirmationCount} '
        '${campaign.awaitingConfirmationCount == 1 ? 'invitation en attente de confirmation' : 'invitations en attente de confirmation'}';
  }

  String _invitationAction(InvitationCampaign campaign) {
    if (role == AppUserRole.admin) {
      if (campaign.pendingCount > 0) return 'Décider des attributions';
      if (campaign.awaitingConfirmationCount > 0) {
        return 'Suivre les confirmations bénévoles';
      }
      return 'Vérifier et clôturer la campagne';
    }
    if (role == AppUserRole.promoter) return 'Suivre la campagne';

    return switch (campaign.ownApplication?.status) {
      InvitationApplicationStatus.selected =>
        'Voir les informations de l’invitation',
      InvitationApplicationStatus.pending => 'Suivre ma candidature',
      _ => 'Candidater',
    };
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

DateTime _day(DateTime value) => DateTime(value.year, value.month, value.day);

String _dashboardNumber(double value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value.toStringAsFixed(1).replaceAll('.', ',');
}

String _adminTodayAction(MaraudeOverview item) {
  if (item.pendingConfirmationCount > 0) return 'Suivre les confirmations';
  return switch (item.maraudeStatus) {
    MaraudeStatus.draft || MaraudeStatus.open =>
      item.selectedCount == 0
          ? 'Constituer l’équipe'
          : 'Vérifier l’équipe et démarrer',
    MaraudeStatus.teamReady => 'Démarrer la maraude',
    MaraudeStatus.inProgress => 'Poursuivre la maraude',
    MaraudeStatus.completed => 'Consulter le bilan',
    MaraudeStatus.cancelled => 'Consulter la maraude annulée',
  };
}
