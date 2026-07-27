import 'package:club_sandwich/features/collections/data/maraude_collection_providers.dart';
import 'package:club_sandwich/features/collections/domain/maraude_collection.dart';
import 'package:club_sandwich/features/collections/presentation/maraude_collection_form_dialog.dart';
import 'package:club_sandwich/features/concerts/data/concert_providers.dart';
import 'package:club_sandwich/features/concerts/domain/concert.dart';
import 'package:club_sandwich/features/concerts/domain/maraude_report.dart';
import 'package:club_sandwich/features/concerts/presentation/concert_form.dart';
import 'package:club_sandwich/features/concerts/presentation/concert_formatters.dart';
import 'package:club_sandwich/features/concerts/presentation/maraude_report_providers.dart';
import 'package:club_sandwich/features/concerts/presentation/maraude_operational_report_card.dart';
import 'package:club_sandwich/features/concerts/presentation/concerts_screen.dart';
import 'package:club_sandwich/features/distributions/data/maraude_distribution_providers.dart';
import 'package:club_sandwich/features/distributions/domain/maraude_distribution.dart';
import 'package:club_sandwich/features/distributions/presentation/maraude_distribution_form_dialog.dart';
import 'package:club_sandwich/features/volunteers/data/concert_volunteer_providers.dart';
import 'package:club_sandwich/features/volunteers/data/concert_volunteer_repository.dart';
import 'package:club_sandwich/features/volunteers/domain/concert_volunteer_application.dart';
import 'package:club_sandwich/features/volunteers/domain/volunteer_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ConcertDetailScreen extends ConsumerWidget {
  const ConcertDetailScreen({required this.concertId, super.key});

  final String concertId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final concert = ref.watch(concertDetailsProvider(concertId));

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: concert.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _DetailError(
          onRetry: () => ref.invalidate(concertDetailsProvider(concertId)),
        ),
        data: (value) {
          if (value == null) return const _ConcertNotFound();
          return _ConcertDetails(concert: value);
        },
      ),
    );
  }
}

class _ConcertDetails extends ConsumerWidget {
  const _ConcertDetails({required this.concert});

  final Concert concert;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final volunteerSection = ref.watch(
      concertVolunteerSectionProvider(concert.id),
    );
    final volunteerData = volunteerSection.value;
    final canManageMaraude = volunteerData?.isAdmin ?? false;
    final canManageConcert = volunteerData?.canManageConcert ?? false;
    final ownApplication = volunteerData?.ownApplication;
    final isSelectedVolunteer =
        ownApplication?.status == ConcertVolunteerStatus.selected;
    final canEditOperationalReport =
        canManageMaraude ||
        (isSelectedVolunteer &&
            ownApplication?.teamRole == MaraudeRole.teamLeader);
    final canEditOperationalPhoto =
        !canEditOperationalReport &&
        isSelectedVolunteer &&
        ownApplication?.teamRole == MaraudeRole.communication;
    final canViewReport =
        concert.maraudeStatus == MaraudeStatus.completed &&
        volunteerData != null &&
        (volunteerData.isAdmin ||
            (ownApplication?.status == ConcertVolunteerStatus.selected &&
                ownApplication?.effectiveAttendanceStatus ==
                    VolunteerAttendanceStatus.present));

    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth < 600 ? 16.0 : 24.0;
        final availableWidth =
            constraints.maxWidth.clamp(0, 1200).toDouble() -
            horizontalPadding * 2;
        const spacing = 16.0;
        final sectionWidth = availableWidth >= 800
            ? (availableWidth - spacing) / 2
            : availableWidth;

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            16,
            horizontalPadding,
            48,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DetailHeader(
                    concert: concert,
                    onEdit: canManageConcert ? () => _edit(context, ref) : null,
                    onDelete: canManageMaraude
                        ? () => _delete(context, ref)
                        : null,
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children: [
                      SizedBox(
                        width: sectionWidth,
                        child: _InformationSection(concert: concert),
                      ),
                      SizedBox(
                        width: sectionWidth,
                        child: _VenueSection(concert: concert),
                      ),
                      SizedBox(
                        width: sectionWidth,
                        child: _MaraudeSection(
                          concert: concert,
                          canManage: canManageMaraude,
                        ),
                      ),
                      SizedBox(
                        width: sectionWidth,
                        child: _CollectionsSection(
                          concert: concert,
                          canManage: canManageMaraude,
                        ),
                      ),
                      SizedBox(
                        width: sectionWidth,
                        child: _DistributionSection(
                          concert: concert,
                          canManage: canManageMaraude,
                        ),
                      ),
                      if (concert.maraudeStatus == MaraudeStatus.inProgress ||
                          concert.maraudeStatus == MaraudeStatus.completed ||
                          concert.operationalReport != null)
                        SizedBox(
                          width: sectionWidth,
                          child: MaraudeOperationalReportCard(
                            concert: concert,
                            canEdit: canEditOperationalReport,
                            canEditPhoto: canEditOperationalPhoto,
                          ),
                        ),
                      if (canViewReport)
                        SizedBox(
                          width: sectionWidth,
                          child: _MaraudeReportSection(
                            concert: concert,
                            volunteerCounts: volunteerData.counts,
                            canEditComment: volunteerData.isAdmin,
                          ),
                        ),
                      SizedBox(
                        width: sectionWidth,
                        child: _ContactsSection(concert: concert),
                      ),
                      SizedBox(
                        width: availableWidth,
                        child: _VolunteersSection(concertId: concert.id),
                      ),
                      SizedBox(
                        width: sectionWidth,
                        child: const _PlaceholderSection(
                          title: 'Documents',
                          icon: Icons.folder_outlined,
                          message: 'Aucun document disponible.',
                        ),
                      ),
                      SizedBox(
                        width: sectionWidth,
                        child: const _PlaceholderSection(
                          title: 'Commentaires',
                          icon: Icons.chat_bubble_outline,
                          message: 'Aucun commentaire.',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final updated = await showDialog<bool>(
      context: context,
      builder: (context) => ConcertForm(
        initialConcert: concert,
        onSubmit: (draft) => ref
            .read(concertRepositoryProvider)
            .updateConcert(concert.id, draft),
      ),
    );
    if (updated != true || !context.mounted) return;

    ref.invalidate(concertsProvider);
    ref.invalidate(concertDetailsProvider(concert.id));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Concert modifié.')));
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final deleted = await deleteConcertWithConfirmation(context, ref, concert);
    if (deleted && context.mounted) context.go('/maraudes');
  }
}

class _MaraudeSection extends ConsumerStatefulWidget {
  const _MaraudeSection({required this.concert, required this.canManage});

  final Concert concert;
  final bool canManage;

  @override
  ConsumerState<_MaraudeSection> createState() => _MaraudeSectionState();
}

class _MaraudeSectionState extends ConsumerState<_MaraudeSection> {
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    final concert = widget.concert;
    return _SectionCard(
      title: 'Maraude',
      icon: Icons.local_shipping_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('État', style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 6),
          _MaraudeStatusChip(status: concert.maraudeStatus),
          const Divider(height: 24),
          _DetailRow(
            label: 'Début réel',
            value: concert.actualStartAt == null
                ? '—'
                : formatFrenchDateTime(concert.actualStartAt!),
          ),
          _DetailRow(
            label: 'Fin réelle',
            value: concert.actualEndAt == null
                ? '—'
                : formatFrenchDateTime(concert.actualEndAt!),
            showDivider: widget.canManage,
          ),
          if (widget.canManage) ...[
            DropdownButtonFormField<MaraudeStatus>(
              key: const ValueKey('maraude-status-selector'),
              initialValue: concert.maraudeStatus,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Modifier l’état'),
              items: [
                for (final status in MaraudeStatus.values)
                  DropdownMenuItem(value: status, child: Text(status.label)),
              ],
              onChanged: _isSubmitting
                  ? null
                  : (status) {
                      if (status != null && status != concert.maraudeStatus) {
                        _setStatus(status);
                      }
                    },
            ),
            if (_isSubmitting) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
            if (concert.maraudeStatus == MaraudeStatus.completed) ...[
              const SizedBox(height: 12),
              const Text(
                'Maraude terminée',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
            if (concert.maraudeStatus == MaraudeStatus.cancelled &&
                concert.cancellationReason != null) ...[
              const SizedBox(height: 12),
              Text('Motif : ${concert.cancellationReason}'),
            ],
          ],
        ],
      ),
    );
  }

  Future<void> _setStatus(MaraudeStatus status) async {
    await _changeStatus(
      action: () => ref
          .read(concertRepositoryProvider)
          .setMaraudeStatus(widget.concert.id, status),
      successMessage: 'État de la maraude mis à jour.',
      errorMessage: 'Impossible de modifier l’état de la maraude.',
    );
  }

  Future<void> _changeStatus({
    required Future<void> Function() action,
    required String successMessage,
    required String errorMessage,
  }) async {
    setState(() => _isSubmitting = true);
    try {
      await action();
      ref.invalidate(concertDetailsProvider(widget.concert.id));
      ref.invalidate(concertsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(successMessage)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errorMessage)));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}

class _MaraudeStatusChip extends StatelessWidget {
  const _MaraudeStatusChip({required this.status});

  final MaraudeStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (icon, color) = switch (status) {
      MaraudeStatus.draft => (Icons.edit_note_outlined, colors.outline),
      MaraudeStatus.open => (Icons.campaign_outlined, colors.secondary),
      MaraudeStatus.teamReady => (Icons.groups_outlined, colors.primary),
      MaraudeStatus.inProgress => (Icons.play_circle_outline, colors.primary),
      MaraudeStatus.completed => (Icons.check_circle_outline, colors.tertiary),
      MaraudeStatus.cancelled => (Icons.cancel_outlined, colors.error),
    };

    return Chip(
      avatar: Icon(icon, color: color, size: 20),
      label: Text(status.label),
      side: BorderSide(color: color),
    );
  }
}

class _CollectionsSection extends ConsumerStatefulWidget {
  const _CollectionsSection({required this.concert, required this.canManage});

  final Concert concert;
  final bool canManage;

  @override
  ConsumerState<_CollectionsSection> createState() =>
      _CollectionsSectionState();
}

class _CollectionsSectionState extends ConsumerState<_CollectionsSection> {
  final Set<String> _deletingIds = {};

  bool get _canEdit =>
      widget.canManage &&
      widget.concert.maraudeStatus == MaraudeStatus.inProgress;

  @override
  Widget build(BuildContext context) {
    final collections = widget.concert.collections;
    final summary = MaraudeCollectionSummary.fromCollections(collections);

    return _SectionCard(
      title: 'Collecte',
      icon: Icons.inventory_2_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _CollectionSummaryValue(
                label: 'Nombre de lots',
                value: summary.lotCount.toString(),
              ),
              _CollectionSummaryValue(
                label: 'Poids total (kg)',
                value: formatCollectionNumber(summary.totalWeightKg),
              ),
              _CollectionSummaryValue(
                label: 'Nombre total de pièces',
                value: formatCollectionNumber(summary.totalPieces),
              ),
            ],
          ),
          if (_canEdit) ...[
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: () => _openForm(),
                icon: const Icon(Icons.add),
                label: const Text('Ajouter un lot'),
              ),
            ),
          ] else if (widget.concert.maraudeStatus ==
              MaraudeStatus.completed) ...[
            const SizedBox(height: 16),
            const Text('Cette collecte est en lecture seule.'),
          ],
          const Divider(height: 28),
          if (collections.isEmpty)
            const Text('Aucun lot enregistré.')
          else
            for (final collection in collections)
              _CollectionItem(
                collection: collection,
                canEdit: _canEdit,
                isDeleting: _deletingIds.contains(collection.id),
                onEdit: () => _openForm(collection),
                onDelete: () => _delete(collection),
              ),
        ],
      ),
    );
  }

  Future<void> _openForm([MaraudeCollection? collection]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => MaraudeCollectionFormDialog(
        initialCollection: collection,
        onSubmit: (draft) async {
          final repository = ref.read(maraudeCollectionRepositoryProvider);
          if (collection == null) {
            await repository.create(widget.concert.id, draft);
          } else {
            await repository.update(collection.id, draft);
          }
        },
      ),
    );
    if (saved != true || !mounted) return;
    ref.invalidate(concertDetailsProvider(widget.concert.id));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(collection == null ? 'Lot ajouté.' : 'Lot modifié.'),
      ),
    );
  }

  Future<void> _delete(MaraudeCollection collection) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer ce lot ?'),
        content: Text(
          'Le lot « ${collection.category.label} » et ses quantités seront '
          'retirés définitivement de la collecte et du bilan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deletingIds.add(collection.id));
    try {
      await ref.read(maraudeCollectionRepositoryProvider).delete(collection.id);
      ref.invalidate(concertDetailsProvider(widget.concert.id));
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Lot supprimé.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible de supprimer ce lot.')),
      );
    } finally {
      if (mounted) setState(() => _deletingIds.remove(collection.id));
    }
  }
}

class _CollectionSummaryValue extends StatelessWidget {
  const _CollectionSummaryValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 2),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _CollectionItem extends StatelessWidget {
  const _CollectionItem({
    required this.collection,
    required this.canEdit,
    required this.isDeleting,
    required this.onEdit,
    required this.onDelete,
  });

  final MaraudeCollection collection;
  final bool canEdit;
  final bool isDeleting;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final description = collection.description?.trim();
    final comment = collection.comment?.trim();
    return Card(
      key: ValueKey('collection-${collection.id}'),
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    collection.category.label,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (description?.isNotEmpty == true) ...[
                    const SizedBox(height: 4),
                    Text(description!),
                  ],
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 6,
                    children: [
                      Text(
                        '${formatCollectionNumber(collection.quantity)} '
                        '${collection.unit.label}',
                      ),
                      if (collection.weightKg != null)
                        Text(
                          'Poids : '
                          '${formatCollectionNumber(collection.weightKg!)} kg',
                        ),
                    ],
                  ),
                  if (comment?.isNotEmpty == true) ...[
                    const SizedBox(height: 8),
                    Text(
                      comment!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
            if (isDeleting)
              const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else if (canEdit)
              PopupMenuButton<_CollectionAction>(
                tooltip: 'Actions du lot',
                onSelected: (action) {
                  switch (action) {
                    case _CollectionAction.edit:
                      onEdit();
                    case _CollectionAction.delete:
                      onDelete();
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: _CollectionAction.edit,
                    child: Text('Modifier'),
                  ),
                  PopupMenuItem(
                    value: _CollectionAction.delete,
                    child: Text('Supprimer'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

enum _CollectionAction { edit, delete }

class _DistributionSection extends ConsumerWidget {
  const _DistributionSection({required this.concert, required this.canManage});

  final Concert concert;
  final bool canManage;

  bool get canEdit =>
      canManage && concert.maraudeStatus == MaraudeStatus.inProgress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final distribution = concert.distribution;

    return _SectionCard(
      title: 'Distribution',
      icon: Icons.volunteer_activism_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (distribution == null)
            const Text('Aucune distribution enregistrée.')
          else ...[
            _DetailRow(
              label: 'Lieu de distribution',
              value: _valueOrDash(distribution.distributionLocation),
            ),
            _DetailRow(
              label: 'Bénéficiaires estimés',
              value: distribution.estimatedBeneficiaries?.toString() ?? '—',
            ),
            _DetailRow(
              label: 'Repas distribués',
              value: distribution.distributedMeals?.toString() ?? '—',
            ),
            _DetailRow(
              label: 'Poids restant',
              value: distribution.remainingWeightKg == null
                  ? '—'
                  : '${formatDistributionNumber(distribution.remainingWeightKg!)} kg',
            ),
            _DetailRow(
              label: 'Début de la distribution',
              value: distribution.distributionStartedAt == null
                  ? '—'
                  : formatFrenchDateTime(distribution.distributionStartedAt!),
            ),
            _DetailRow(
              label: 'Fin de la distribution',
              value: distribution.distributionCompletedAt == null
                  ? '—'
                  : formatFrenchDateTime(distribution.distributionCompletedAt!),
            ),
            _DetailRow(
              label: 'Commentaire d’incident',
              value: _valueOrDash(distribution.incidentComment),
              showDivider: false,
            ),
          ],
          if (canEdit) ...[
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                key: const ValueKey('edit-distribution'),
                onPressed: () => _openForm(context, ref, distribution),
                icon: Icon(
                  distribution == null ? Icons.add : Icons.edit_outlined,
                ),
                label: Text(
                  distribution == null ? 'Ajouter la distribution' : 'Modifier',
                ),
              ),
            ),
          ] else if (concert.maraudeStatus == MaraudeStatus.completed) ...[
            const SizedBox(height: 16),
            const Text('Cette distribution est en lecture seule.'),
          ],
        ],
      ),
    );
  }

  Future<void> _openForm(
    BuildContext context,
    WidgetRef ref,
    MaraudeDistribution? distribution,
  ) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => MaraudeDistributionFormDialog(
        initialDistribution: distribution,
        onSubmit: (draft) async {
          final repository = ref.read(maraudeDistributionRepositoryProvider);
          if (distribution == null) {
            await repository.create(concert.id, draft);
          } else {
            await repository.update(distribution.id, draft);
          }
        },
      ),
    );
    if (saved != true || !context.mounted) return;
    ref.invalidate(concertDetailsProvider(concert.id));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          distribution == null
              ? 'Distribution ajoutée.'
              : 'Distribution modifiée.',
        ),
      ),
    );
  }
}

String _valueOrDash(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? '—' : trimmed;
}

class _MaraudeReportSection extends ConsumerStatefulWidget {
  const _MaraudeReportSection({
    required this.concert,
    required this.volunteerCounts,
    required this.canEditComment,
  });

  final Concert concert;
  final ConcertVolunteerCounts volunteerCounts;
  final bool canEditComment;

  @override
  ConsumerState<_MaraudeReportSection> createState() =>
      _MaraudeReportSectionState();
}

class _MaraudeReportSectionState extends ConsumerState<_MaraudeReportSection> {
  bool _isExporting = false;

  MaraudeReport get _report =>
      MaraudeReport.fromConcert(widget.concert, widget.volunteerCounts);

  @override
  Widget build(BuildContext context) {
    final report = _report;
    final distribution = report.distribution;

    return _SectionCard(
      title: 'Bilan',
      icon: Icons.summarize_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Général', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          _DetailRow(label: 'Artiste', value: report.artist),
          _DetailRow(label: 'Salle', value: report.venueName ?? '—'),
          _DetailRow(
            label: 'Date',
            value: formatLongFrenchDate(report.concertDate),
          ),
          _DetailRow(
            label: 'Durée réelle',
            value: formatMaraudeDuration(report.actualDuration),
          ),
          const SizedBox(height: 8),
          Text('Équipe', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          _DetailRow(
            label: 'Bénévoles sélectionnés',
            value: report.selectedCount.toString(),
          ),
          _DetailRow(label: 'Présents', value: report.presentCount.toString()),
          _DetailRow(label: 'Absents', value: report.absentCount.toString()),
          const SizedBox(height: 8),
          Text('Collecte', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          _DetailRow(
            label: 'Nombre de lots',
            value: report.collectionSummary.lotCount.toString(),
          ),
          _DetailRow(
            label: 'Poids total',
            value:
                '${formatCollectionNumber(report.collectionSummary.totalWeightKg)} kg',
          ),
          _DetailRow(
            label: 'Quantité totale de pièces',
            value: formatCollectionNumber(report.collectionSummary.totalPieces),
          ),
          const SizedBox(height: 8),
          Text('Distribution', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          if (distribution == null)
            const Text('Aucune distribution enregistrée.')
          else ...[
            _DetailRow(
              label: 'Lieu',
              value: _valueOrDash(distribution.distributionLocation),
            ),
            _DetailRow(
              label: 'Bénéficiaires estimés',
              value: distribution.estimatedBeneficiaries?.toString() ?? '—',
            ),
            _DetailRow(
              label: 'Repas distribués',
              value: distribution.distributedMeals?.toString() ?? '—',
            ),
            _DetailRow(
              label: 'Poids restant',
              value: distribution.remainingWeightKg == null
                  ? '—'
                  : '${formatDistributionNumber(distribution.remainingWeightKg!)} kg',
            ),
            _DetailRow(
              label: 'Horaires',
              value: _distributionSchedule(distribution),
            ),
            _DetailRow(
              label: 'Incident',
              value: _valueOrDash(distribution.incidentComment),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Commentaire de fin',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (widget.canEditComment)
                IconButton(
                  key: const ValueKey('edit-closing-comment'),
                  tooltip: 'Modifier le commentaire de fin',
                  onPressed: _editClosingComment,
                  icon: const Icon(Icons.edit_outlined),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(_valueOrDash(report.closingComment)),
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              key: const ValueKey('export-maraude-report'),
              onPressed: _isExporting ? null : _export,
              icon: _isExporting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('Exporter le bilan'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editClosingComment() async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => _ClosingCommentDialog(
        initialValue: widget.concert.closingComment,
        onSubmit: (value) => ref
            .read(concertRepositoryProvider)
            .updateClosingComment(widget.concert.id, value),
      ),
    );
    if (saved != true || !mounted) return;
    ref.invalidate(concertDetailsProvider(widget.concert.id));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Commentaire de fin enregistré.')),
    );
  }

  Future<void> _export() async {
    setState(() => _isExporting = true);
    try {
      await ref.read(maraudeReportPdfServiceProvider).export(_report);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Export du bilan lancé.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d’exporter le bilan.')),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }
}

class _ClosingCommentDialog extends StatefulWidget {
  const _ClosingCommentDialog({required this.onSubmit, this.initialValue});

  final String? initialValue;
  final Future<void> Function(String? value) onSubmit;

  @override
  State<_ClosingCommentDialog> createState() => _ClosingCommentDialogState();
}

class _ClosingCommentDialogState extends State<_ClosingCommentDialog> {
  late final TextEditingController _controller;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Commentaire de fin'),
      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const ValueKey('closing-comment-field'),
              controller: _controller,
              enabled: !_isSubmitting,
              autofocus: true,
              maxLines: 5,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              decoration: const InputDecoration(
                labelText: 'Commentaire',
                hintText: 'Optionnel',
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Semantics(
                liveRegion: true,
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting
              ? null
              : () => Navigator.of(context).pop(false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Enregistrer'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      await widget.onSubmit(_controller.text);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = 'Impossible d’enregistrer le commentaire de fin.';
      });
    }
  }
}

String _distributionSchedule(MaraudeDistribution distribution) {
  final start = distribution.distributionStartedAt;
  final end = distribution.distributionCompletedAt;
  if (start == null && end == null) return '—';
  final startLabel = start == null
      ? 'Début non renseigné'
      : formatFrenchDateTime(start).replaceFirst('\n', ' à ');
  final endLabel = end == null
      ? 'Fin non renseignée'
      : formatFrenchDateTime(end).replaceFirst('\n', ' à ');
  return '$startLabel\n$endLabel';
}

class _DetailHeader extends StatelessWidget {
  const _DetailHeader({
    required this.concert,
    required this.onEdit,
    required this.onDelete,
  });

  final Concert concert;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconButton(
          tooltip: 'Retour',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/maraudes');
            }
          },
          icon: const Icon(Icons.arrow_back),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                concert.artist,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _InlineInformation(
                    icon: Icons.location_on_outlined,
                    text: concert.venueName ?? '—',
                  ),
                  _InlineInformation(
                    icon: Icons.calendar_today_outlined,
                    text: formatLongFrenchDate(concert.date),
                  ),
                  Chip(
                    visualDensity: VisualDensity.compact,
                    label: Text(_statusLabel(concert.status)),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (onEdit != null || onDelete != null)
          PopupMenuButton<_DetailAction>(
            tooltip: 'Actions',
            onSelected: (action) {
              switch (action) {
                case _DetailAction.edit:
                  onEdit?.call();
                case _DetailAction.delete:
                  onDelete?.call();
              }
            },
            itemBuilder: (context) => [
              if (onEdit != null)
                const PopupMenuItem(
                  value: _DetailAction.edit,
                  child: ListTile(
                    leading: Icon(Icons.edit_outlined),
                    title: Text('Modifier'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              if (onDelete != null)
                const PopupMenuItem(
                  value: _DetailAction.delete,
                  child: ListTile(
                    leading: Icon(Icons.delete_outline),
                    title: Text('Supprimer'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

enum _DetailAction { edit, delete }

class _InformationSection extends StatelessWidget {
  const _InformationSection({required this.concert});

  final Concert concert;

  @override
  Widget build(BuildContext context) {
    final cateringClosesAt = concert.cateringClosesAt;
    return _SectionCard(
      title: 'Informations',
      icon: Icons.info_outline,
      child: Column(
        children: [
          _DetailRow(label: 'Artiste', value: concert.artist),
          _DetailRow(label: 'Date', value: formatLongFrenchDate(concert.date)),
          _DetailRow(
            label: 'Producteur',
            value: concert.promoterOrganizationName ?? '—',
          ),
          _DetailRow(label: 'Notes', value: concert.notes ?? '—'),
          _DetailRow(
            label: 'Fermeture du catering',
            value: cateringClosesAt == null
                ? '—'
                : formatDatabaseTime(cateringClosesAt),
          ),
          _DetailRow(
            label: 'Arrivée recommandée',
            value: cateringClosesAt == null
                ? '—'
                : recommendedArrivalFromDatabase(cateringClosesAt),
            showDivider: false,
          ),
        ],
      ),
    );
  }
}

class _VenueSection extends StatelessWidget {
  const _VenueSection({required this.concert});

  final Concert concert;

  @override
  Widget build(BuildContext context) {
    final venue = concert.venue;
    return _SectionCard(
      title: 'Salle',
      icon: Icons.location_on_outlined,
      child: Column(
        children: [
          _DetailRow(label: 'Nom', value: venue?.name ?? '—'),
          _DetailRow(label: 'Adresse', value: venue?.publicAddressLine1 ?? '—'),
          _DetailRow(
            label: 'Complément',
            value: venue?.publicAddressLine2 ?? '—',
          ),
          _DetailRow(label: 'Ville', value: venue?.city ?? '—'),
          _DetailRow(label: 'Code postal', value: venue?.postalCode ?? '—'),
          const Divider(height: 24),
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.lock_outline, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Informations d’accès disponibles selon vos autorisations.',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

enum _ApplicationFilter {
  all('Tous'),
  selected('Sélectionnés'),
  pending('En attente'),
  withdrawn('Désistés'),
  notSelected('Non sélectionnés');

  const _ApplicationFilter(this.label);

  final String label;
}

extension on _ApplicationFilter {
  bool matches(ConcertVolunteerStatus status) {
    return switch (this) {
      _ApplicationFilter.all => true,
      _ApplicationFilter.selected => status == ConcertVolunteerStatus.selected,
      _ApplicationFilter.pending => status == ConcertVolunteerStatus.pending,
      _ApplicationFilter.withdrawn =>
        status == ConcertVolunteerStatus.withdrawn,
      _ApplicationFilter.notSelected =>
        status == ConcertVolunteerStatus.notSelected,
    };
  }
}

class _VolunteersSection extends ConsumerStatefulWidget {
  const _VolunteersSection({required this.concertId});

  final String concertId;

  @override
  ConsumerState<_VolunteersSection> createState() => _VolunteersSectionState();
}

class _VolunteersSectionState extends ConsumerState<_VolunteersSection> {
  static const _minimumTeamSize = 4;

  bool _isSubmitting = false;
  bool _isSavingTeam = false;
  bool _teamDirty = false;
  int _mobileTeamView = 0;
  final Set<String> _updatingApplications = {};
  final Map<String, MaraudeRole> _draftTeamRoles = {};
  String? _serverTeamSignature;
  final TextEditingController _searchController = TextEditingController();
  _ApplicationFilter _filter = _ApplicationFilter.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final section = ref.watch(
      concertVolunteerSectionProvider(widget.concertId),
    );

    return _SectionCard(
      title: 'Bénévoles',
      icon: Icons.groups_outlined,
      child: section.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Impossible de charger les candidatures.'),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => ref.invalidate(
                concertVolunteerSectionProvider(widget.concertId),
              ),
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
            ),
          ],
        ),
        data: _buildContent,
      ),
    );
  }

  Widget _buildContent(ConcertVolunteerSectionData data) {
    _synchronizeTeamDraft(data.applications);
    final visibleApplications = _visibleApplications(data.applications);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _applicationCountLabel(data.counts.applicationCount),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(_selectedCountLabel(data.counts.selectedCount)),
        const SizedBox(height: 20),
        if (data.canApply) ...[
          if (data.ownApplication == null)
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton(
                onPressed: _isSubmitting ? null : _apply,
                child: _isSubmitting
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Je me propose'),
              ),
            )
          else
            _OwnApplication(
              application: data.ownApplication!,
              isSubmitting: _isSubmitting,
              onWithdraw:
                  data.ownApplication!.status ==
                      ConcertVolunteerStatus.withdrawn
                  ? null
                  : _withdraw,
              onReapply:
                  data.ownApplication!.status ==
                      ConcertVolunteerStatus.withdrawn
                  ? _reapply
                  : null,
            ),
        ],
        if (data.isAdmin) ...[
          const Divider(height: 32),
          _buildTeamBuilder(data, visibleApplications),
        ] else if (data.isPromoter && data.canViewApplications) ...[
          const Divider(height: 32),
          _PromoterApplications(applications: visibleApplications),
        ],
      ],
    );
  }

  Widget _buildTeamBuilder(
    ConcertVolunteerSectionData data,
    List<ConcertVolunteerApplication> visibleApplications,
  ) {
    final candidates = Column(
      key: const ValueKey('team-candidates-column'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Candidatures',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('volunteer-search-field'),
          controller: _searchController,
          onChanged: (_) => setState(() {}),
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            labelText: 'Rechercher',
            hintText: 'Nom, téléphone ou e-mail',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searchController.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Effacer la recherche',
                    onPressed: () {
                      _searchController.clear();
                      setState(() {});
                    },
                    icon: const Icon(Icons.clear),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final filter in _ApplicationFilter.values)
              FilterChip(
                key: ValueKey('volunteer-filter-${filter.name}'),
                label: Text(filter.label),
                selected: _filter == filter,
                onSelected: (_) => setState(() => _filter = filter),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (visibleApplications.isEmpty)
          const _FilteredApplicationsEmptyState()
        else
          for (final application in visibleApplications)
            _TeamCandidateCard(
              application: application,
              selectedRole: _draftTeamRoles[application.id],
              isUpdating: _updatingApplications.contains(application.id),
              isRoleAvailable: (role) => _isRoleAvailable(role, application.id),
              onSelect: () => _selectInDraft(application.id),
              onRemove: () => _removeFromDraft(application.id),
              onRoleChanged: (role) => _assignDraftRole(application.id, role),
              onAttendanceChanged:
                  application.status == ConcertVolunteerStatus.selected
                  ? (status) => _setAttendanceStatus(application.id, status)
                  : null,
            ),
      ],
    );

    final summary = _TeamBuilderSummary(
      applications: data.applications,
      roles: _draftTeamRoles,
      minimumTeamSize: _minimumTeamSize,
      isDirty: _teamDirty,
      isSaving: _isSavingTeam,
      attendanceCounts: data.attendanceCounts,
      onSave: _canSaveTeam ? _saveTeam : null,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 900) {
          return Row(
            key: const ValueKey('team-builder-desktop'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 2, child: candidates),
              const SizedBox(width: 24),
              SizedBox(width: 320, child: summary),
            ],
          );
        }

        return Column(
          key: const ValueKey('team-builder-mobile'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<int>(
              key: const ValueKey('team-mobile-tabs'),
              segments: const [
                ButtonSegment(value: 0, label: Text('Candidatures')),
                ButtonSegment(value: 1, label: Text('Équipe')),
              ],
              selected: {_mobileTeamView},
              onSelectionChanged: (selection) =>
                  setState(() => _mobileTeamView = selection.single),
            ),
            const SizedBox(height: 16),
            if (_mobileTeamView == 0) candidates else summary,
          ],
        );
      },
    );
  }

  bool get _canSaveTeam {
    return _teamDirty && !_isSavingTeam;
  }

  void _synchronizeTeamDraft(List<ConcertVolunteerApplication> applications) {
    final serverMembers =
        applications
            .where(
              (application) =>
                  application.status == ConcertVolunteerStatus.selected,
            )
            .map(
              (application) =>
                  '${application.id}:${application.teamRole?.databaseValue}',
            )
            .toList()
          ..sort();
    final signature = serverMembers.join('|');
    if (_serverTeamSignature == signature || _teamDirty) return;

    _serverTeamSignature = signature;
    _draftTeamRoles
      ..clear()
      ..addEntries(
        applications
            .where(
              (application) =>
                  application.status == ConcertVolunteerStatus.selected,
            )
            .map(
              (application) => MapEntry(
                application.id,
                application.teamRole ?? MaraudeRole.collectionDistribution,
              ),
            ),
      );
  }

  List<ConcertVolunteerApplication> _visibleApplications(
    List<ConcertVolunteerApplication> applications,
  ) {
    final query = _normalizeVolunteerSearch(_searchController.text);
    final visible =
        applications.where((application) {
          final effectiveStatus = _draftTeamRoles.containsKey(application.id)
              ? ConcertVolunteerStatus.selected
              : application.status == ConcertVolunteerStatus.selected
              ? ConcertVolunteerStatus.notSelected
              : application.status;
          if (!_filter.matches(effectiveStatus)) return false;
          if (query.isEmpty) return true;

          final profile = application.profile;
          final searchableValue = _normalizeVolunteerSearch(
            [
              application.displayName,
              profile?.phone,
              profile?.email,
            ].whereType<String>().join(' '),
          );
          return searchableValue.contains(query);
        }).toList()..sort((left, right) {
          final leftSelected = _draftTeamRoles.containsKey(left.id);
          final rightSelected = _draftTeamRoles.containsKey(right.id);
          if (leftSelected != rightSelected) return leftSelected ? -1 : 1;
          return _compareApplications(left, right);
        });
    return visible;
  }

  bool _isRoleAvailable(MaraudeRole role, String applicationId) {
    return true;
  }

  void _selectInDraft(String applicationId) {
    setState(() {
      _draftTeamRoles[applicationId] = MaraudeRole.collectionDistribution;
      _teamDirty = true;
    });
  }

  void _removeFromDraft(String applicationId) {
    setState(() {
      _draftTeamRoles.remove(applicationId);
      _teamDirty = true;
    });
  }

  void _assignDraftRole(String applicationId, MaraudeRole role) {
    if (!_isRoleAvailable(role, applicationId)) return;
    setState(() {
      _draftTeamRoles[applicationId] = role;
      _teamDirty = true;
    });
  }

  Future<void> _apply() async {
    setState(() => _isSubmitting = true);
    try {
      await ref
          .read(concertVolunteerRepositoryProvider)
          .apply(widget.concertId);
      ref.invalidate(concertVolunteerSectionProvider(widget.concertId));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Votre candidature a été enregistrée.\n\n'
            'Vous serez informé si vous êtes sélectionné.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      _showError('Impossible d’enregistrer votre candidature.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _withdraw() async {
    final application = ref
        .read(concertVolunteerSectionProvider(widget.concertId))
        .value
        ?.ownApplication;
    if (application == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer le désistement ?'),
        content: const Text(
          'Votre candidature restera dans l’historique avec le statut '
          '« Désisté ». Cette action ne peut pas être annulée.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Je me désiste'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isSubmitting = true);
    try {
      await ref
          .read(concertVolunteerRepositoryProvider)
          .withdraw(application.id);
      ref.invalidate(concertVolunteerSectionProvider(widget.concertId));
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Désistement enregistré.')));
    } catch (error) {
      if (!mounted) return;
      _showError('Impossible d’enregistrer votre désistement.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _reapply() async {
    setState(() => _isSubmitting = true);
    try {
      await ref
          .read(concertVolunteerRepositoryProvider)
          .reapply(widget.concertId);
      ref.invalidate(concertVolunteerSectionProvider(widget.concertId));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Votre disponibilité a été transmise.')),
      );
    } catch (error) {
      if (!mounted) return;
      _showError('Impossible de renouveler votre disponibilité.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _saveTeam() async {
    setState(() => _isSavingTeam = true);
    try {
      await ref
          .read(concertVolunteerRepositoryProvider)
          .saveTeam(
            widget.concertId,
            _draftTeamRoles.entries.map(
              (entry) => MaraudeTeamMemberDraft(
                applicationId: entry.key,
                role: entry.value,
              ),
            ),
          );
      _teamDirty = false;
      _serverTeamSignature = null;
      ref.invalidate(concertVolunteerSectionProvider(widget.concertId));
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Équipe enregistrée.')));
    } catch (error) {
      if (!mounted) return;
      _showError('Impossible d’enregistrer l’équipe.');
    } finally {
      if (mounted) setState(() => _isSavingTeam = false);
    }
  }

  Future<void> _setAttendanceStatus(
    String applicationId,
    VolunteerAttendanceStatus status,
  ) async {
    setState(() => _updatingApplications.add(applicationId));
    try {
      await ref
          .read(concertVolunteerRepositoryProvider)
          .setAttendanceStatus(applicationId, status);
      ref.invalidate(concertVolunteerSectionProvider(widget.concertId));
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Présence : ${status.label}.')));
    } catch (error) {
      if (!mounted) return;
      _showError('Impossible de modifier cette présence.');
    } finally {
      if (mounted) {
        setState(() => _updatingApplications.remove(applicationId));
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _PromoterApplications extends StatelessWidget {
  const _PromoterApplications({required this.applications});

  final List<ConcertVolunteerApplication> applications;

  @override
  Widget build(BuildContext context) {
    if (applications.isEmpty) {
      return const _FilteredApplicationsEmptyState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Candidatures',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        for (final application in applications)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundImage: application.profile?.avatarUrl == null
                    ? null
                    : NetworkImage(application.profile!.avatarUrl!),
                child: application.profile?.avatarUrl == null
                    ? const Icon(Icons.person_outline)
                    : null,
              ),
              title: Text(application.displayName),
              subtitle: Text(application.status.label),
              trailing: application.teamRole == null
                  ? null
                  : Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text(application.teamRole!.label),
                    ),
            ),
          ),
      ],
    );
  }
}

class _OwnApplication extends StatelessWidget {
  const _OwnApplication({
    required this.application,
    required this.isSubmitting,
    required this.onWithdraw,
    required this.onReapply,
  });

  final ConcertVolunteerApplication application;
  final bool isSubmitting;
  final VoidCallback? onWithdraw;
  final VoidCallback? onReapply;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          application.status.label,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (application.status == ConcertVolunteerStatus.selected) ...[
          const SizedBox(height: 6),
          if (application.teamRole != null)
            Text('Rôle : ${application.teamRole!.label}'),
          Text('Présence : ${application.effectiveAttendanceStatus!.label}'),
        ],
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: () => _showVolunteerProfileDialog(context, application),
          icon: const Icon(Icons.person_outline),
          label: const Text('Voir mon profil'),
        ),
        if (onWithdraw != null) ...[
          const SizedBox(height: 4),
          OutlinedButton(
            onPressed: isSubmitting ? null : onWithdraw,
            child: isSubmitting
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Je me désiste'),
          ),
        ],
        if (onReapply != null) ...[
          const SizedBox(height: 4),
          FilledButton(
            key: const ValueKey('reapply-to-concert'),
            onPressed: isSubmitting ? null : onReapply,
            child: isSubmitting
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Je suis de nouveau disponible'),
          ),
        ],
      ],
    );
  }
}

class _TeamBuilderSummary extends StatelessWidget {
  const _TeamBuilderSummary({
    required this.applications,
    required this.roles,
    required this.minimumTeamSize,
    required this.isDirty,
    required this.isSaving,
    required this.attendanceCounts,
    required this.onSave,
  });

  final List<ConcertVolunteerApplication> applications;
  final Map<String, MaraudeRole> roles;
  final int minimumTeamSize;
  final bool isDirty;
  final bool isSaving;
  final TeamAttendanceCounts attendanceCounts;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    final hasLeader = roles.containsValue(MaraudeRole.teamLeader);
    final isRecommendedSize = roles.length >= minimumTeamSize;
    final colors = Theme.of(context).colorScheme;

    return Card.filled(
      key: const ValueKey('team-builder-summary'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Équipe retenue',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '${roles.length} / $minimumTeamSize bénévoles',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Divider(height: 28),
            _TeamRoleSummary(
              label: 'Chef d’équipe',
              names: _namesForRole(MaraudeRole.teamLeader),
            ),
            const Divider(height: 24),
            _TeamRoleSummary(
              label: 'Communication',
              names: _namesForRole(MaraudeRole.communication),
            ),
            const Divider(height: 24),
            _TeamRoleSummary(
              label: 'Logistique',
              names: _namesForRole(MaraudeRole.logistics),
            ),
            const Divider(height: 24),
            _TeamRoleSummary(
              label: 'Récolte & distribution',
              names: _namesForRole(MaraudeRole.collectionDistribution),
            ),
            const Divider(height: 28),
            Row(
              children: [
                Icon(
                  isRecommendedSize
                      ? Icons.check_circle_outline
                      : Icons.pending_actions_outlined,
                  color: isRecommendedSize ? colors.primary : colors.tertiary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isRecommendedSize
                        ? 'Équipe enregistrable'
                        : '${roles.length} bénévole${roles.length > 1 ? 's' : ''} — '
                              '$minimumTeamSize sont généralement recommandés.',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const ValueKey('save-maraude-team'),
              onPressed: onSave,
              icon: isSaving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: Text(
                !isDirty ? 'Équipe enregistrée' : 'Enregistrer l’équipe',
              ),
            ),
            if (!hasLeader) ...[
              const SizedBox(height: 8),
              const Text(
                'Aucun rôle Chef.fe d’équipe n’est attribué. '
                'Cette recommandation ne bloque pas l’enregistrement.',
                style: TextStyle(fontSize: 12),
              ),
            ],
            if (attendanceCounts.selectedCount > 0) ...[
              const Divider(height: 28),
              _TeamAttendanceSummary(counts: attendanceCounts),
            ],
          ],
        ),
      ),
    );
  }

  List<String> _namesForRole(MaraudeRole role) {
    final applicationsById = {
      for (final application in applications) application.id: application,
    };
    return roles.entries
        .where((entry) => entry.value == role)
        .map((entry) => applicationsById[entry.key]?.displayName ?? 'Bénévole')
        .toList(growable: false);
  }
}

class _TeamRoleSummary extends StatelessWidget {
  const _TeamRoleSummary({required this.label, required this.names});

  final String label;
  final List<String> names;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 4),
        Text(names.isEmpty ? '—' : names.join('\n')),
      ],
    );
  }
}

class _FilteredApplicationsEmptyState extends StatelessWidget {
  const _FilteredApplicationsEmptyState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Center(child: Text('Aucune candidature ne correspond.')),
    );
  }
}

class _ApplicationStatusChip extends StatelessWidget {
  const _ApplicationStatusChip({required this.status});

  final ConcertVolunteerStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (backgroundColor, foregroundColor) = switch (status) {
      ConcertVolunteerStatus.selected => (
        colors.primaryContainer,
        colors.onPrimaryContainer,
      ),
      ConcertVolunteerStatus.pending => (
        colors.secondaryContainer,
        colors.onSecondaryContainer,
      ),
      ConcertVolunteerStatus.withdrawn => (
        colors.surfaceContainerHighest,
        colors.onSurfaceVariant,
      ),
      ConcertVolunteerStatus.notSelected => (
        colors.errorContainer,
        colors.onErrorContainer,
      ),
    };

    return Chip(
      visualDensity: VisualDensity.compact,
      backgroundColor: backgroundColor,
      side: BorderSide.none,
      label: Text(status.label, style: TextStyle(color: foregroundColor)),
    );
  }
}

class _TeamCandidateCard extends StatelessWidget {
  const _TeamCandidateCard({
    required this.application,
    required this.selectedRole,
    required this.isUpdating,
    required this.isRoleAvailable,
    required this.onSelect,
    required this.onRemove,
    required this.onRoleChanged,
    required this.onAttendanceChanged,
  });

  final ConcertVolunteerApplication application;
  final MaraudeRole? selectedRole;
  final bool isUpdating;
  final bool Function(MaraudeRole role) isRoleAvailable;
  final VoidCallback onSelect;
  final VoidCallback onRemove;
  final ValueChanged<MaraudeRole> onRoleChanged;
  final ValueChanged<VolunteerAttendanceStatus>? onAttendanceChanged;

  @override
  Widget build(BuildContext context) {
    final profile = application.profile;
    final statistics = application.statistics;
    final isSelected = selectedRole != null;
    final effectiveStatus = isSelected
        ? ConcertVolunteerStatus.selected
        : application.status == ConcertVolunteerStatus.selected
        ? ConcertVolunteerStatus.notSelected
        : application.status;

    return Card(
      key: ValueKey('volunteer-card-${application.id}'),
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _showVolunteerProfileDialog(context, application),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _VolunteerAvatar(profile: profile),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            application.displayName,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              _ApplicationStatusChip(status: effectiveStatus),
                              if (isSelected)
                                const Chip(
                                  visualDensity: VisualDensity.compact,
                                  avatar: Icon(
                                    Icons.assignment_ind_outlined,
                                    size: 18,
                                  ),
                                  label: Text('Rôle attribué'),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.open_in_new, size: 18),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 20,
              runSpacing: 10,
              children: [
                _CandidateFact(
                  label: 'Maraudes',
                  value: '${statistics.selectedApplications}',
                ),
                _CandidateFact(
                  label: 'Dernière participation',
                  value: _compactDateOrNone(statistics.lastSelectedDate),
                ),
                _CandidateFact(
                  label: 'Désistements',
                  value: statistics.withdrawnApplications == 0
                      ? 'Aucun'
                      : '${statistics.withdrawnApplications}',
                ),
                _CandidateFact(
                  label: 'Disponibilité',
                  value: application.status == ConcertVolunteerStatus.withdrawn
                      ? 'Non disponible'
                      : 'Confirmée',
                ),
              ],
            ),
            const Divider(height: 28),
            if (!isSelected)
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton(
                  key: ValueKey('select-volunteer-${application.id}'),
                  onPressed:
                      isUpdating ||
                          application.status == ConcertVolunteerStatus.withdrawn
                      ? null
                      : onSelect,
                  child: const Text('Sélectionner'),
                ),
              )
            else ...[
              Text(
                'Rôle dans la maraude',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 6),
              RadioGroup<MaraudeRole>(
                groupValue: selectedRole,
                onChanged: (value) {
                  if (value != null && isRoleAvailable(value)) {
                    onRoleChanged(value);
                  }
                },
                child: Column(
                  children: [
                    for (final role in MaraudeRole.values)
                      RadioListTile<MaraudeRole>(
                        key: ValueKey(
                          'team-role-${application.id}-${role.name}',
                        ),
                        value: role,
                        enabled:
                            !isUpdating &&
                            (isRoleAvailable(role) || selectedRole == role),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(role.label),
                      ),
                  ],
                ),
              ),
              if (onAttendanceChanged != null) ...[
                const SizedBox(height: 8),
                DropdownButtonFormField<VolunteerAttendanceStatus>(
                  key: ValueKey(
                    'attendance-${application.id}-'
                    '${application.effectiveAttendanceStatus}',
                  ),
                  initialValue: application.effectiveAttendanceStatus,
                  decoration: InputDecoration(
                    labelText: 'Présence',
                    prefixIcon: Icon(
                      _attendanceIcon(application.effectiveAttendanceStatus!),
                      color: _attendanceColor(
                        context,
                        application.effectiveAttendanceStatus!,
                      ),
                    ),
                  ),
                  items: [
                    for (final status in VolunteerAttendanceStatus.values)
                      DropdownMenuItem(
                        value: status,
                        child: Text(status.label),
                      ),
                  ],
                  onChanged: isUpdating
                      ? null
                      : (value) {
                          if (value != null) onAttendanceChanged!(value);
                        },
                ),
              ],
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: ValueKey('remove-volunteer-${application.id}'),
                  onPressed: isUpdating ? null : onRemove,
                  icon: const Icon(Icons.person_remove_outlined),
                  label: const Text('Retirer'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CandidateFact extends StatelessWidget {
  const _CandidateFact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 2),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _TeamAttendanceSummary extends StatelessWidget {
  const _TeamAttendanceSummary({required this.counts});

  final TeamAttendanceCounts counts;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Équipe', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text('${counts.selectedCount} sélectionnés'),
        const Divider(height: 24),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            _AttendanceCount(
              icon: Icons.check_circle_outline,
              color: Theme.of(context).colorScheme.primary,
              label: 'Présents : ${counts.presentCount}',
            ),
            _AttendanceCount(
              icon: Icons.cancel_outlined,
              color: Theme.of(context).colorScheme.error,
              label: 'Absents : ${counts.absentCount}',
            ),
            _AttendanceCount(
              icon: Icons.schedule_outlined,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              label: 'En attente : ${counts.pendingCount}',
            ),
          ],
        ),
      ],
    );
  }
}

class _AttendanceCount extends StatelessWidget {
  const _AttendanceCount({
    required this.icon,
    required this.color,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 6),
        Text(label),
      ],
    );
  }
}

IconData _attendanceIcon(VolunteerAttendanceStatus status) {
  return switch (status) {
    VolunteerAttendanceStatus.pending => Icons.schedule_outlined,
    VolunteerAttendanceStatus.present => Icons.check_circle_outline,
    VolunteerAttendanceStatus.absent => Icons.cancel_outlined,
  };
}

Color _attendanceColor(BuildContext context, VolunteerAttendanceStatus status) {
  final colors = Theme.of(context).colorScheme;
  return switch (status) {
    VolunteerAttendanceStatus.pending => colors.onSurfaceVariant,
    VolunteerAttendanceStatus.present => colors.primary,
    VolunteerAttendanceStatus.absent => colors.error,
  };
}

class _VolunteerAvatar extends StatelessWidget {
  const _VolunteerAvatar({required this.profile, this.size = 48});

  final VolunteerProfile? profile;
  final double size;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = profile?.avatarUrl?.trim();
    return ClipOval(
      child: ColoredBox(
        color: Theme.of(context).colorScheme.secondaryContainer,
        child: SizedBox.square(
          dimension: size,
          child: avatarUrl?.isNotEmpty == true
              ? Image.network(
                  avatarUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.person_outline),
                )
              : const Icon(Icons.person_outline),
        ),
      ),
    );
  }
}

Future<void> _showVolunteerProfileDialog(
  BuildContext context,
  ConcertVolunteerApplication application,
) {
  final profile = application.profile;
  final statistics = application.statistics;
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Profil bénévole'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  _VolunteerAvatar(profile: profile, size: 64),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      application.displayName,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _ProfileDetailRow(
                label: 'Date de naissance',
                value: profile?.birthDate == null
                    ? 'Non renseignée'
                    : formatLongFrenchDate(profile!.birthDate!),
              ),
              _ProfileDetailRow(
                label: 'Téléphone',
                value: _optionalValue(profile?.phone),
              ),
              _ProfileDetailRow(
                label: 'E-mail',
                value: _optionalValue(profile?.email),
              ),
              _ProfileDetailRow(
                label: 'Permis',
                value: _booleanLabel(profile?.hasDrivingLicense),
              ),
              _ProfileDetailRow(
                label: 'Port de charges lourdes',
                value: _booleanLabel(profile?.canLiftHeavyLoads),
              ),
              const SizedBox(height: 8),
              Text(
                'Expérience',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Text(_totalApplicationsLabel(statistics.totalApplications)),
              const SizedBox(height: 6),
              Text(_selectedMissionsLabel(statistics.selectedApplications)),
              const SizedBox(height: 6),
              Text(
                _notSelectedMissionsLabel(statistics.notSelectedApplications),
              ),
              const SizedBox(height: 6),
              Text(_withdrawalsLabel(statistics.withdrawnApplications)),
              const SizedBox(height: 16),
              _ProfileDetailRow(
                label: 'Dernière participation',
                value: statistics.lastSelectedDate == null
                    ? 'Aucune'
                    : formatLongFrenchDate(statistics.lastSelectedDate!),
              ),
              if (statistics.selectionRate != null) ...[
                Text('Taux de sélection : ${statistics.selectionRate} %'),
                const SizedBox(height: 6),
                Text('Taux de désistement : ${statistics.withdrawalRate} %'),
              ],
              const Divider(height: 32),
              Text(
                'Contact d’urgence',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              _ProfileDetailRow(
                label: 'Nom',
                value: _optionalValue(profile?.emergencyContactName),
              ),
              _ProfileDetailRow(
                label: 'Téléphone',
                value: _optionalValue(profile?.emergencyContactPhone),
                showDivider: false,
              ),
              const Divider(height: 32),
              Text(
                'Historique des maraudes',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              if (statistics.history.isEmpty)
                const Text('Aucun historique.')
              else
                for (final entry in statistics.history)
                  _VolunteerHistoryCard(entry: entry),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fermer'),
        ),
      ],
    ),
  );
}

class _VolunteerHistoryCard extends StatelessWidget {
  const _VolunteerHistoryCard({required this.entry});

  final VolunteerHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    return Card.outlined(
      key: ValueKey('volunteer-history-${entry.concertId}'),
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              formatLongFrenchDate(entry.concertDate),
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 6),
            Text(
              entry.artist,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on_outlined, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    entry.venueName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(entry.status.label),
          ],
        ),
      ),
    );
  }
}

class _ProfileDetailRow extends StatelessWidget {
  const _ProfileDetailRow({
    required this.label,
    required this.value,
    this.showDivider = true,
  });

  final String label;
  final String value;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 4),
        Text(value),
        if (showDivider) const Divider(height: 24),
      ],
    );
  }
}

String _applicationCountLabel(int count) {
  return '$count ${count == 1 ? 'candidature' : 'candidatures'}';
}

String _selectedCountLabel(int count) {
  return '$count ${count == 1 ? 'bénévole sélectionné' : 'bénévoles sélectionnés'}';
}

String _totalApplicationsLabel(int count) {
  return '$count ${count == 1 ? 'candidature' : 'candidatures'}';
}

String _selectedMissionsLabel(int count) {
  return '$count ${count == 1 ? 'maraude sélectionnée' : 'maraudes sélectionnées'}';
}

String _notSelectedMissionsLabel(int count) {
  return '$count ${count == 1 ? 'non-sélection' : 'non-sélections'}';
}

String _withdrawalsLabel(int count) {
  return '$count ${count == 1 ? 'désistement' : 'désistements'}';
}

int _compareApplications(
  ConcertVolunteerApplication first,
  ConcertVolunteerApplication second,
) {
  final statusComparison = _statusOrder(
    first.status,
  ).compareTo(_statusOrder(second.status));
  if (statusComparison != 0) return statusComparison;
  return _normalizeVolunteerSearch(
    first.displayName,
  ).compareTo(_normalizeVolunteerSearch(second.displayName));
}

int _statusOrder(ConcertVolunteerStatus status) {
  return switch (status) {
    ConcertVolunteerStatus.selected => 0,
    ConcertVolunteerStatus.pending => 1,
    ConcertVolunteerStatus.withdrawn => 2,
    ConcertVolunteerStatus.notSelected => 3,
  };
}

String _normalizeVolunteerSearch(String value) {
  var normalized = value.trim().toLowerCase();
  const replacements = {
    'à': 'a',
    'â': 'a',
    'ä': 'a',
    'ç': 'c',
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'ë': 'e',
    'î': 'i',
    'ï': 'i',
    'ô': 'o',
    'ö': 'o',
    'ù': 'u',
    'û': 'u',
    'ü': 'u',
    'ÿ': 'y',
    'œ': 'oe',
  };
  for (final replacement in replacements.entries) {
    normalized = normalized.replaceAll(replacement.key, replacement.value);
  }
  return normalized;
}

String _compactDateOrNone(DateTime? value) {
  if (value == null) return 'Aucune';
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  return '$day/$month';
}

String _booleanLabel(bool? value) {
  return switch (value) {
    true => 'Oui',
    false => 'Non',
    null => 'Non renseigné',
  };
}

String _optionalValue(String? value) {
  final trimmed = value?.trim();
  return trimmed?.isNotEmpty == true ? trimmed! : 'Non renseigné';
}

class _ContactsSection extends StatelessWidget {
  const _ContactsSection({required this.concert});

  final Concert concert;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Contacts sur place',
      icon: Icons.contact_phone_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ContactDetails(
            title: 'Contact tourneur',
            emptyMessage: 'Aucun contact tourneur renseigné.',
            name: concert.promoterContactName,
            phone: concert.promoterContactPhone,
            email: concert.promoterContactEmail,
          ),
          const Divider(height: 32),
          _ContactDetails(
            title: 'Contact catering',
            emptyMessage: 'Aucun contact catering renseigné.',
            name: concert.cateringContactName,
            phone: concert.cateringContactPhone,
            email: concert.cateringContactEmail,
          ),
        ],
      ),
    );
  }
}

class _ContactDetails extends StatelessWidget {
  const _ContactDetails({
    required this.title,
    required this.emptyMessage,
    required this.name,
    required this.phone,
    required this.email,
  });

  final String title;
  final String emptyMessage;
  final String? name;
  final String? phone;
  final String? email;

  bool get _isEmpty => name == null && phone == null && email == null;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        if (_isEmpty)
          Text(emptyMessage)
        else ...[
          _DetailRow(label: 'Nom', value: name ?? '—'),
          _DetailRow(label: 'Téléphone', value: phone ?? '—'),
          _DetailRow(label: 'E-mail', value: email ?? '—', showDivider: false),
        ],
      ],
    );
  }
}

class _PlaceholderSection extends StatelessWidget {
  const _PlaceholderSection({
    required this.title,
    required this.icon,
    required this.message,
  });

  final String title;
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: title,
      icon: icon,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [Text(message)],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            child,
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.showDivider = true,
  });

  final String label;
  final String value;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 4),
        SelectableText(value),
        if (showDivider) const Divider(height: 24),
      ],
    );
  }
}

class _InlineInformation extends StatelessWidget {
  const _InlineInformation({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 6),
          Flexible(child: Text(text)),
        ],
      ),
    );
  }
}

class _DetailError extends StatelessWidget {
  const _DetailError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 16),
            const Text(
              'Impossible de charger ce concert.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConcertNotFound extends StatelessWidget {
  const _ConcertNotFound();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off, size: 56),
            const SizedBox(height: 16),
            Text(
              'Concert introuvable',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Ce concert n’existe pas ou n’est pas accessible.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => context.go('/maraudes'),
              child: const Text('Retour aux maraudes'),
            ),
          ],
        ),
      ),
    );
  }
}

String _statusLabel(ConcertStatus status) {
  return switch (status) {
    ConcertStatus.planned => 'Planifié',
    ConcertStatus.confirmed => 'Confirmé',
    ConcertStatus.completed => 'Terminé',
    ConcertStatus.cancelled => 'Annulé',
  };
}
