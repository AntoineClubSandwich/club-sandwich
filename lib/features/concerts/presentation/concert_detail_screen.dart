import 'package:club_sandwich/features/collections/data/maraude_collection_providers.dart';
import 'package:club_sandwich/features/collections/domain/maraude_collection.dart';
import 'package:club_sandwich/features/collections/presentation/maraude_collection_form_dialog.dart';
import 'package:club_sandwich/features/concerts/data/concert_providers.dart';
import 'package:club_sandwich/features/concerts/domain/concert.dart';
import 'package:club_sandwich/features/concerts/domain/maraude_report.dart';
import 'package:club_sandwich/features/concerts/presentation/concert_formatters.dart';
import 'package:club_sandwich/features/concerts/presentation/maraude_report_providers.dart';
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
    final canManageMaraude = volunteerSection.value?.isAdmin ?? false;
    final volunteerData = volunteerSection.value;
    final ownApplication = volunteerData?.ownApplication;
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
                    onEdit: () => _edit(context, ref),
                    onDelete: () => _delete(context, ref),
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
                        width: sectionWidth,
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
      builder: (context) => ConcertFormDialog(
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
    if (deleted && context.mounted) context.go('/concerts');
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
          if (widget.canManage)
            switch (concert.maraudeStatus) {
              MaraudeStatus.planned => FilledButton.icon(
                key: const ValueKey('start-maraude'),
                onPressed: _isSubmitting ? null : _confirmStart,
                icon: _isSubmitting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.play_arrow),
                label: const Text('Démarrer la maraude'),
              ),
              MaraudeStatus.started => FilledButton.icon(
                key: const ValueKey('complete-maraude'),
                onPressed: _isSubmitting ? null : _confirmComplete,
                icon: _isSubmitting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.stop_circle_outlined),
                label: const Text('Terminer la maraude'),
              ),
              MaraudeStatus.completed => const Text(
                'Maraude terminée',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            },
        ],
      ),
    );
  }

  Future<void> _start() async {
    await _changeStatus(
      action: () =>
          ref.read(concertRepositoryProvider).startMaraude(widget.concert.id),
      successMessage: 'Maraude démarrée.',
      errorMessage:
          'Impossible de démarrer la maraude. '
          'Vérifiez qu’au moins un bénévole sélectionné est présent.',
    );
  }

  Future<void> _complete() async {
    await _changeStatus(
      action: () => ref
          .read(concertRepositoryProvider)
          .completeMaraude(widget.concert.id),
      successMessage: 'Maraude terminée.',
      errorMessage: 'Impossible de terminer la maraude.',
    );
  }

  Future<void> _confirmStart() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Démarrer la maraude ?'),
        content: const Text(
          'L’heure réelle de début sera enregistrée. '
          'La maraude ne pourra plus revenir en préparation.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Démarrer'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) await _start();
  }

  Future<void> _confirmComplete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Terminer la maraude ?'),
        content: const Text(
          'La collecte et la distribution deviendront définitivement '
          'en lecture seule.',
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
            child: const Text('Terminer'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) await _complete();
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
      MaraudeStatus.planned => (Icons.schedule_outlined, colors.secondary),
      MaraudeStatus.started => (Icons.play_circle_outline, colors.primary),
      MaraudeStatus.completed => (Icons.check_circle_outline, colors.tertiary),
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
      widget.canManage && widget.concert.maraudeStatus == MaraudeStatus.started;

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
      canManage && concert.maraudeStatus == MaraudeStatus.started;

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
  final VoidCallback onEdit;
  final VoidCallback onDelete;

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
              context.go('/concerts');
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
        PopupMenuButton<_DetailAction>(
          tooltip: 'Actions',
          onSelected: (action) {
            switch (action) {
              case _DetailAction.edit:
                onEdit();
              case _DetailAction.delete:
                onDelete();
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: _DetailAction.edit,
              child: ListTile(
                leading: Icon(Icons.edit_outlined),
                title: Text('Modifier'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            PopupMenuItem(
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

class _VolunteersSection extends ConsumerStatefulWidget {
  const _VolunteersSection({required this.concertId});

  final String concertId;

  @override
  ConsumerState<_VolunteersSection> createState() => _VolunteersSectionState();
}

class _VolunteersSectionState extends ConsumerState<_VolunteersSection> {
  bool _isSubmitting = false;
  bool _isBulkSelecting = false;
  final Set<String> _updatingApplications = {};
  final Set<String> _selectedApplications = {};

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
    final teamApplications = data.applications
        .where(
          (application) =>
              application.status == ConcertVolunteerStatus.selected,
        )
        .toList(growable: false);
    final otherApplications = data.applications
        .where(
          (application) =>
              application.status != ConcertVolunteerStatus.selected,
        )
        .toList(growable: false);

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
                data.ownApplication!.status == ConcertVolunteerStatus.withdrawn
                ? null
                : _withdraw,
          ),
        if (data.isAdmin) ...[
          const Divider(height: 32),
          _TeamAttendanceSummary(counts: data.attendanceCounts),
          const SizedBox(height: 12),
          if (teamApplications.isEmpty)
            const Text('Aucun bénévole sélectionné.')
          else
            for (final application in teamApplications)
              _AdminApplication(
                application: application,
                isUpdating: _updatingApplications.contains(application.id),
                isChosen: false,
                onSelectionChanged: (_) {},
                onStatusChanged: (status) => _setStatus(application.id, status),
                onRoleChanged: (role) => _setTeamRole(application.id, role),
                onAttendanceChanged: (status) =>
                    _setAttendanceStatus(application.id, status),
              ),
          const Divider(height: 32),
          Text('Candidatures', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: _selectedApplications.isEmpty || _isBulkSelecting
                  ? null
                  : _selectVolunteers,
              icon: _isBulkSelecting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.group_add_outlined),
              label: const Text('Sélectionner les bénévoles'),
            ),
          ),
          const SizedBox(height: 12),
          if (otherApplications.isEmpty)
            const Text('Aucune candidature.')
          else
            for (final application in otherApplications)
              _AdminApplication(
                application: application,
                isUpdating: _updatingApplications.contains(application.id),
                isChosen: _selectedApplications.contains(application.id),
                onSelectionChanged: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedApplications.add(application.id);
                    } else {
                      _selectedApplications.remove(application.id);
                    }
                  });
                },
                onStatusChanged: (status) => _setStatus(application.id, status),
                onRoleChanged: (role) => _setTeamRole(application.id, role),
                onAttendanceChanged: (status) =>
                    _setAttendanceStatus(application.id, status),
              ),
        ],
      ],
    );
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

  Future<void> _setStatus(
    String applicationId,
    ConcertVolunteerStatus status,
  ) async {
    setState(() => _updatingApplications.add(applicationId));
    try {
      await ref
          .read(concertVolunteerRepositoryProvider)
          .setStatus(applicationId, status);
      _selectedApplications.remove(applicationId);
      ref.invalidate(concertVolunteerSectionProvider(widget.concertId));
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Candidature : ${status.label}.')));
    } catch (error) {
      if (!mounted) return;
      _showError('Impossible de modifier cette candidature.');
    } finally {
      if (mounted) {
        setState(() => _updatingApplications.remove(applicationId));
      }
    }
  }

  Future<void> _selectVolunteers() async {
    setState(() => _isBulkSelecting = true);
    try {
      await ref
          .read(concertVolunteerRepositoryProvider)
          .selectVolunteers(widget.concertId, _selectedApplications);
      _selectedApplications.clear();
      ref.invalidate(concertVolunteerSectionProvider(widget.concertId));
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Bénévoles sélectionnés.')));
    } catch (error) {
      if (!mounted) return;
      _showError('Impossible de sélectionner ces bénévoles.');
    } finally {
      if (mounted) setState(() => _isBulkSelecting = false);
    }
  }

  Future<void> _setTeamRole(String applicationId, MaraudeRole role) async {
    setState(() => _updatingApplications.add(applicationId));
    try {
      await ref
          .read(concertVolunteerRepositoryProvider)
          .setTeamRole(applicationId, role);
      ref.invalidate(concertVolunteerSectionProvider(widget.concertId));
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Rôle : ${role.label}.')));
    } on TeamLeaderAlreadyAssignedException {
      if (!mounted) return;
      _showError('Un chef d’équipe est déjà attribué à ce concert.');
    } catch (error) {
      if (!mounted) return;
      _showError('Impossible de modifier ce rôle.');
    } finally {
      if (mounted) {
        setState(() => _updatingApplications.remove(applicationId));
      }
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

class _OwnApplication extends StatelessWidget {
  const _OwnApplication({
    required this.application,
    required this.isSubmitting,
    required this.onWithdraw,
  });

  final ConcertVolunteerApplication application;
  final bool isSubmitting;
  final VoidCallback? onWithdraw;

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
      ],
    );
  }
}

class _AdminApplication extends StatelessWidget {
  const _AdminApplication({
    required this.application,
    required this.isUpdating,
    required this.isChosen,
    required this.onSelectionChanged,
    required this.onStatusChanged,
    required this.onRoleChanged,
    required this.onAttendanceChanged,
  });

  final ConcertVolunteerApplication application;
  final bool isUpdating;
  final bool isChosen;
  final ValueChanged<bool> onSelectionChanged;
  final ValueChanged<ConcertVolunteerStatus> onStatusChanged;
  final ValueChanged<MaraudeRole> onRoleChanged;
  final ValueChanged<VolunteerAttendanceStatus> onAttendanceChanged;

  @override
  Widget build(BuildContext context) {
    final profile = application.profile;
    final phone = profile?.phone?.trim();
    final statistics = application.statistics;

    return Card(
      key: ValueKey('volunteer-card-${application.id}'),
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showVolunteerProfileDialog(context, application),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (application.status !=
                      ConcertVolunteerStatus.selected) ...[
                    Checkbox(
                      value: isChosen,
                      onChanged:
                          isUpdating ||
                              application.status ==
                                  ConcertVolunteerStatus.withdrawn
                          ? null
                          : (value) => onSelectionChanged(value ?? false),
                      semanticLabel: 'Sélectionner ${application.displayName}',
                    ),
                    const SizedBox(width: 4),
                  ],
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
                        Chip(
                          visualDensity: VisualDensity.compact,
                          label: Text(application.status.label),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (phone?.isNotEmpty == true) ...[
                const SizedBox(height: 12),
                _ProfileIconLine(icon: Icons.phone_outlined, text: phone!),
              ],
              const SizedBox(height: 8),
              _ProfileIconLine(
                icon: Icons.directions_car_outlined,
                text: 'Permis : ${_booleanLabel(profile?.hasDrivingLicense)}',
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 6,
                children: [
                  Text(_totalApplicationsLabel(statistics.totalApplications)),
                  Text(_selectedMissionsLabel(statistics.selectedApplications)),
                  Text(_withdrawalsLabel(statistics.withdrawnApplications)),
                ],
              ),
              const SizedBox(height: 12),
              if (application.status == ConcertVolunteerStatus.selected) ...[
                DropdownButtonFormField<MaraudeRole>(
                  key: ValueKey(
                    'team-role-${application.id}-${application.teamRole}',
                  ),
                  initialValue: application.teamRole,
                  decoration: const InputDecoration(
                    labelText: 'Rôle dans la maraude',
                    hintText: 'Aucun rôle attribué',
                  ),
                  items: [
                    for (final role in MaraudeRole.values)
                      DropdownMenuItem(value: role, child: Text(role.label)),
                  ],
                  onChanged: isUpdating
                      ? null
                      : (role) {
                          if (role != null) onRoleChanged(role);
                        },
                ),
                const SizedBox(height: 12),
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
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _attendanceIcon(status),
                              color: _attendanceColor(context, status),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(status.label),
                          ],
                        ),
                      ),
                  ],
                  onChanged: isUpdating
                      ? null
                      : (status) {
                          if (status != null) onAttendanceChanged(status);
                        },
                ),
                const SizedBox(height: 12),
              ],
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    onPressed:
                        isUpdating ||
                            application.status ==
                                ConcertVolunteerStatus.notSelected ||
                            application.status ==
                                ConcertVolunteerStatus.withdrawn
                        ? null
                        : () => onStatusChanged(
                            ConcertVolunteerStatus.notSelected,
                          ),
                    child: const Text('Ne pas sélectionner'),
                  ),
                ],
              ),
            ],
          ),
        ),
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

class _ProfileIconLine extends StatelessWidget {
  const _ProfileIconLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 8),
        Flexible(child: Text(text)),
      ],
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
              onPressed: () => context.go('/concerts'),
              child: const Text('Retour aux concerts'),
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
