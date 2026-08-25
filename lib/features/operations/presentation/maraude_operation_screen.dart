import 'package:club_sandwich/design_system/components/buttons/ds_primary_button.dart';
import 'package:club_sandwich/design_system/components/surfaces/ds_card.dart';
import 'package:club_sandwich/design_system/tokens/ds_spacing.dart';
import 'package:club_sandwich/design_system/tokens/ds_theme.dart';
import 'package:club_sandwich/design_system/tokens/ds_typography.dart';
import 'package:club_sandwich/features/auth/application/auth_providers.dart';
import 'package:club_sandwich/features/auth/domain/user_account.dart';
import 'package:club_sandwich/features/collections/domain/maraude_collection.dart';
import 'package:club_sandwich/features/concerts/data/concert_providers.dart';
import 'package:club_sandwich/features/concerts/domain/concert.dart';
import 'package:club_sandwich/features/encounters/data/encounter_location_service.dart';
import 'package:club_sandwich/features/encounters/data/encounter_providers.dart';
import 'package:club_sandwich/features/operations/data/maraude_operation_providers.dart';
import 'package:club_sandwich/features/operations/data/maraude_operation_repository.dart';
import 'package:club_sandwich/features/operations/domain/maraude_workflow.dart';
import 'package:club_sandwich/features/volunteers/data/concert_volunteer_providers.dart';
import 'package:club_sandwich/features/volunteers/domain/concert_volunteer_application.dart';
import 'package:club_sandwich/shared/utils/error_messages.dart';
import 'package:club_sandwich/shared/widgets/app_state_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class MaraudeOperationScreen extends ConsumerStatefulWidget {
  const MaraudeOperationScreen({required this.concertId, super.key});

  final String concertId;

  @override
  ConsumerState<MaraudeOperationScreen> createState() =>
      _MaraudeOperationScreenState();
}

class _MaraudeOperationScreenState
    extends ConsumerState<MaraudeOperationScreen> {
  MaraudeOperationalStep? _viewedStep;
  final Map<String, TextEditingController> _preparationControllers = {};
  final Map<String, TextEditingController> _returnControllers = {};
  final Map<String, EquipmentIncidentType?> _incidents = {};
  final Map<String, TextEditingController> _incidentNotes = {};
  final _distributed = TextEditingController();
  final _remaining = TextEditingController();
  final _beneficiaries = TextEditingController();
  final _distributionComment = TextEditingController();
  var _distributionInitialized = false;
  var _saving = false;
  var _recordingEncounter = false;

  @override
  void dispose() {
    for (final controller in [
      ..._preparationControllers.values,
      ..._returnControllers.values,
      ..._incidentNotes.values,
      _distributed,
      _remaining,
      _beneficiaries,
      _distributionComment,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bundle = ref.watch(maraudeOperationBundleProvider(widget.concertId));
    final concert = ref.watch(concertDetailsProvider(widget.concertId));
    final volunteerData = ref
        .watch(concertVolunteerSectionProvider(widget.concertId))
        .value;
    final account = ref.watch(currentUserContextProvider).value;
    final ownApplication = volunteerData?.ownApplication;
    final canClose =
        account?.role == AppUserRole.admin ||
        (ownApplication?.status == ConcertVolunteerStatus.selected &&
            ownApplication?.confirmationStatus ==
                VolunteerConfirmationStatus.confirmed &&
            ownApplication?.teamRole == MaraudeRole.teamLeader);

    return Theme(
      data: DsTheme.light,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F7F8),
        appBar: AppBar(
          title: const Text('Maraude en cours'),
          leading: IconButton(
            tooltip: 'Retour à la fiche',
            onPressed: () => context.go('/maraudes/${widget.concertId}'),
            icon: const Icon(Icons.arrow_back),
          ),
          actions: [
            TextButton.icon(
              onPressed: concert.value == null
                  ? null
                  : () => _showInfo(concert.value!),
              icon: const Icon(Icons.info_outline),
              label: const Text('Infos maraude'),
            ),
            const SizedBox(width: DsSpacing.sm),
          ],
        ),
        body: bundle.when(
          loading: () =>
              const AppLoadingState(label: 'Chargement du parcours terrain'),
          error: (error, _) => AppErrorState(
            message: describeError(
              error,
              'Impossible de charger le parcours terrain.',
            ),
            onRetry: () => ref.invalidate(
              maraudeOperationBundleProvider(widget.concertId),
            ),
          ),
          data: (data) {
            final operation = data.operation;
            if (operation == null) {
              return const AppEmptyState(
                title: 'Maraude non démarrée',
                message: 'Démarrez la maraude depuis sa fiche.',
                icon: Icons.play_circle_outline,
              );
            }
            _initializeControllers(data);
            final viewed = _viewedStep ?? operation.currentStep;
            return Column(
              children: [
                _StepProgress(
                  current: operation.currentStep,
                  viewed: viewed,
                  onSelected: (step) => setState(() => _viewedStep = step),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      DsSpacing.lg,
                      DsSpacing.lg,
                      DsSpacing.lg,
                      96,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 760),
                        child: _buildStep(
                          data,
                          viewed,
                          operation.currentStep,
                          canClose,
                          concert.value,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _initializeControllers(MaraudeOperationBundle data) {
    for (final item in data.consumables) {
      _preparationControllers.putIfAbsent(
        'c-${item.id}',
        () => TextEditingController(
          text: _number(item.actualQuantity ?? item.plannedQuantity),
        ),
      );
    }
    for (final item in data.equipment) {
      _preparationControllers.putIfAbsent(
        'e-${item.id}',
        () => TextEditingController(
          text: '${item.takenQuantity ?? item.plannedQuantity}',
        ),
      );
      _returnControllers.putIfAbsent(
        item.id,
        () => TextEditingController(
          text: '${item.returnedQuantity ?? item.takenQuantity ?? 0}',
        ),
      );
      _incidentNotes.putIfAbsent(
        item.id,
        () => TextEditingController(text: item.incidentNote),
      );
      _incidents.putIfAbsent(item.id, () => item.incidentType);
    }
    if (!_distributionInitialized) {
      _distributed.text = '${data.distribution?.distributedBoxes ?? 0}';
      _remaining.text =
          '${data.distribution?.remainingBoxes ?? data.totalCollectedBoxes}';
      _beneficiaries.text = '${data.distribution?.estimatedBeneficiaries ?? 0}';
      _distributionComment.text = data.distribution?.incidentComment ?? '';
      _distributionInitialized = true;
    }
  }

  Widget _buildStep(
    MaraudeOperationBundle data,
    MaraudeOperationalStep viewed,
    MaraudeOperationalStep current,
    bool canClose,
    Concert? concert,
  ) => switch (viewed) {
    MaraudeOperationalStep.preparation => _PreparationStep(
      data: data,
      controllers: _preparationControllers,
      saving: _saving,
      active: current == viewed,
      onValidate: () => _validatePreparation(data),
    ),
    MaraudeOperationalStep.collection => _CollectionStep(
      data: data,
      saving: _saving,
      active: current == viewed,
      onAdd: () => _editCollection(data),
      onEdit: (line) => _editCollection(data, line),
      onDelete: _deleteCollection,
      onValidate: () => _validateStep(viewed),
    ),
    MaraudeOperationalStep.distribution => _DistributionStep(
      data: data,
      distributed: _distributed,
      remaining: _remaining,
      beneficiaries: _beneficiaries,
      comment: _distributionComment,
      saving: _saving,
      recordingEncounter: _recordingEncounter,
      active: current == viewed,
      onDistributedChanged: () {
        final distributed = int.tryParse(_distributed.text);
        if (distributed != null && distributed <= data.totalCollectedBoxes) {
          _remaining.text = '${data.totalCollectedBoxes - distributed}';
        }
      },
      onRecordEncounter: _recordEncounter,
      onSave: () => _saveDistribution(data, validate: current == viewed),
    ),
    MaraudeOperationalStep.equipmentReturn => _EquipmentReturnStep(
      data: data,
      returnControllers: _returnControllers,
      incidents: _incidents,
      incidentNotes: _incidentNotes,
      saving: _saving,
      active: current == viewed,
      onIncidentChanged: (id, value) => setState(() => _incidents[id] = value),
      onSave: () => _saveReturns(data, validate: current == viewed),
    ),
    MaraudeOperationalStep.summary => _SummaryStep(
      data: data,
      concert: concert,
      canClose: canClose,
      saving: _saving,
      onClose: _complete,
    ),
  };

  Future<void> _validatePreparation(MaraudeOperationBundle data) => _run(
    () => ref
        .read(maraudeOperationRepositoryProvider)
        .validatePreparation(
          concertId: widget.concertId,
          consumableQuantities: {
            for (final item in data.consumables)
              item.id: _parseDouble(
                _preparationControllers['c-${item.id}']!.text,
              ),
          },
          equipmentQuantities: {
            for (final item in data.equipment)
              item.id: _parseInt(_preparationControllers['e-${item.id}']!.text),
          },
        ),
    'Préparation validée.',
  );

  Future<void> _validateStep(MaraudeOperationalStep step) => _run(
    () => ref
        .read(maraudeOperationRepositoryProvider)
        .validateStep(widget.concertId, step),
    '${step.label} validée.',
  );

  Future<void> _editCollection(
    MaraudeOperationBundle data, [
    MaraudeCollection? line,
  ]) async {
    final result = await showDialog<_CollectionInput>(
      context: context,
      builder: (context) => _CollectionDialog(line: line),
    );
    if (result == null) return;
    await _run(
      () => ref
          .read(maraudeOperationRepositoryProvider)
          .saveCollection(
            concertId: widget.concertId,
            collectionId: line?.id,
            description: result.description,
            boxCount: result.boxes,
            weightKg: result.weightKg,
          ),
      line == null ? 'Plat ajouté.' : 'Plat modifié.',
    );
  }

  Future<void> _deleteCollection(MaraudeCollection line) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer ce plat ?'),
        content: Text(
          '${line.description ?? 'Ce plat'} sera retiré de la collecte.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _run(
      () => ref
          .read(maraudeOperationRepositoryProvider)
          .deleteCollection(line.id),
      'Plat supprimé.',
    );
  }

  Future<void> _saveDistribution(
    MaraudeOperationBundle data, {
    required bool validate,
  }) async {
    await _run(() async {
      await ref
          .read(maraudeOperationRepositoryProvider)
          .saveDistribution(
            concertId: widget.concertId,
            collectedBoxes: data.totalCollectedBoxes,
            distributedBoxes: _parseInt(_distributed.text),
            remainingBoxes: _parseInt(_remaining.text),
            beneficiaries: _parseInt(_beneficiaries.text),
            comment: _distributionComment.text,
          );
      if (validate) {
        await ref
            .read(maraudeOperationRepositoryProvider)
            .validateStep(
              widget.concertId,
              MaraudeOperationalStep.distribution,
            );
      }
    }, validate ? 'Distribution validée.' : 'Corrections enregistrées.');
  }

  Future<void> _recordEncounter() async {
    if (_recordingEncounter) return;
    setState(() => _recordingEncounter = true);
    try {
      final position = await ref
          .read(encounterLocationServiceProvider)
          .currentPosition();
      await ref
          .read(encounterRepositoryProvider)
          .record(
            maraudeId: widget.concertId,
            latitude: position.latitude,
            longitude: position.longitude,
            accuracy: position.accuracy,
          );
      ref.invalidate(maraudeOperationBundleProvider(widget.concertId));
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Rencontre enregistrée ✓')));
    } on EncounterLocationException catch (error) {
      if (!mounted) return;
      final message = switch (error.failure) {
        EncounterLocationFailure.serviceDisabled =>
          'La localisation est désactivée. Activez-la puis réessayez.',
        EncounterLocationFailure.permissionDenied =>
          'Autorisez la localisation dans votre navigateur puis réessayez.',
        EncounterLocationFailure.unavailable =>
          'Impossible d’obtenir une position suffisamment précise. Réessayez.',
      };
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            describeError(
              error,
              'Impossible d’enregistrer la rencontre. Vérifiez votre connexion et réessayez.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _recordingEncounter = false);
    }
  }

  Future<void> _saveReturns(
    MaraudeOperationBundle data, {
    required bool validate,
  }) => _run(() async {
    await ref
        .read(maraudeOperationRepositoryProvider)
        .recordEquipmentReturn(
          concertId: widget.concertId,
          returns: [
            for (final item in data.equipment)
              EquipmentReturnDraft(
                allocationId: item.id,
                returnedQuantity: _parseInt(_returnControllers[item.id]!.text),
                incidentType: _incidents[item.id],
                incidentNote: _incidentNotes[item.id]!.text,
              ),
          ],
        );
    if (validate) {
      await ref
          .read(maraudeOperationRepositoryProvider)
          .validateStep(
            widget.concertId,
            MaraudeOperationalStep.equipmentReturn,
          );
    }
  }, validate ? 'Retour matériel validé.' : 'Corrections enregistrées.');

  Future<void> _complete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clôturer la maraude ?'),
        content: const Text(
          'Les données opérationnelles seront archivées et la maraude passera à l’état Terminée.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clôturer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _run(
      () => ref
          .read(maraudeOperationRepositoryProvider)
          .complete(widget.concertId),
      'Maraude clôturée.',
    );
    ref.invalidate(concertDetailsProvider(widget.concertId));
    if (mounted) context.go('/maraudes/${widget.concertId}');
  }

  Future<void> _run(Future<void> Function() action, String success) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await action();
      ref.invalidate(maraudeOperationBundleProvider(widget.concertId));
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(success)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(describeError(error, 'Enregistrement impossible.')),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _showInfo(Concert concert) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      maxChildSize: 0.95,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.all(DsSpacing.xl),
        children: [
          Text('Infos maraude', style: DsTypography.h2),
          const SizedBox(height: DsSpacing.lg),
          _InfoRow('Artiste', concert.artist),
          _InfoRow('Salle', concert.venueName ?? '—'),
          _InfoRow('Adresse', concert.venue?.formattedAddress ?? '—'),
          _InfoRow('Accès', concert.venue?.accessInstructions ?? '—'),
          _InfoRow('Fermeture catering', concert.cateringClosesAt ?? '—'),
          _InfoRow(
            'Contact tourneur',
            [
              concert.promoterContactName,
              concert.promoterContactPhone,
            ].whereType<String>().join(' · ').ifEmpty('—'),
          ),
          _InfoRow('Organisation', concert.promoterOrganizationName ?? '—'),
          _InfoRow('Consignes', concert.notes ?? '—'),
        ],
      ),
    ),
  );
}

class _StepProgress extends StatelessWidget {
  const _StepProgress({
    required this.current,
    required this.viewed,
    required this.onSelected,
  });
  final MaraudeOperationalStep current;
  final MaraudeOperationalStep viewed;
  final ValueChanged<MaraudeOperationalStep> onSelected;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    elevation: 1,
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(DsSpacing.md),
      child: Row(
        children: [
          for (final step in MaraudeOperationalStep.values) ...[
            ChoiceChip(
              label: Text(step.label),
              avatar: Icon(
                step.index < current.index
                    ? Icons.check_circle
                    : Icons.circle_outlined,
                size: 18,
              ),
              selected: step == viewed,
              onSelected: step.index <= current.index
                  ? (_) => onSelected(step)
                  : null,
            ),
            if (step != MaraudeOperationalStep.values.last)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: Icon(Icons.chevron_right),
              ),
          ],
        ],
      ),
    ),
  );
}

class _PreparationStep extends StatelessWidget {
  const _PreparationStep({
    required this.data,
    required this.controllers,
    required this.saving,
    required this.active,
    required this.onValidate,
  });
  final MaraudeOperationBundle data;
  final Map<String, TextEditingController> controllers;
  final bool saving;
  final bool active;
  final VoidCallback onValidate;

  @override
  Widget build(BuildContext context) => _StepCard(
    title: '1. Préparation',
    subtitle: 'Confirmez les ressources réellement emportées.',
    children: [
      Text('Consommables', style: DsTypography.h3),
      if (data.consumables.isEmpty) const Text('Aucun consommable prévu.'),
      for (final item in data.consumables)
        _QuantityRow(
          label:
              '${item.name} · stock ${_number(item.availableQuantity)} ${item.unit.label}',
          controller: controllers['c-${item.id}']!,
          enabled: active,
        ),
      const SizedBox(height: DsSpacing.lg),
      Text('Matériel', style: DsTypography.h3),
      if (data.equipment.isEmpty) const Text('Aucun matériel prévu.'),
      for (final item in data.equipment)
        _QuantityRow(
          label: '${item.name} · ${item.quantityTotal} disponibles',
          controller: controllers['e-${item.id}']!,
          enabled: active,
          integer: true,
        ),
      const SizedBox(height: DsSpacing.xl),
      DsPrimaryButton(
        label: active ? 'Valider et continuer' : 'Préparation validée',
        icon: Icons.arrow_forward,
        isLoading: saving,
        isFullWidth: true,
        onPressed: active ? onValidate : null,
      ),
    ],
  );
}

class _CollectionStep extends StatelessWidget {
  const _CollectionStep({
    required this.data,
    required this.saving,
    required this.active,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    required this.onValidate,
  });
  final MaraudeOperationBundle data;
  final bool saving;
  final bool active;
  final VoidCallback onAdd;
  final ValueChanged<MaraudeCollection> onEdit;
  final ValueChanged<MaraudeCollection> onDelete;
  final VoidCallback onValidate;

  @override
  Widget build(BuildContext context) => _StepCard(
    title: '2. Collecte catering',
    subtitle:
        '${data.totalCollectedBoxes} boîtes · ${_number(data.totalCollectedWeight)} kg',
    children: [
      for (final line in data.collections)
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(line.description ?? 'Plat'),
          subtitle: Text(
            '${_number(line.quantity)} boîtes · ${_number(line.weightKg ?? 0)} kg',
          ),
          trailing: Wrap(
            children: [
              IconButton(
                tooltip: 'Modifier',
                onPressed: () => onEdit(line),
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                tooltip: 'Supprimer',
                onPressed: () => onDelete(line),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ),
      OutlinedButton.icon(
        onPressed: onAdd,
        icon: const Icon(Icons.add),
        label: const Text('Ajouter un plat'),
      ),
      const SizedBox(height: DsSpacing.xl),
      DsPrimaryButton(
        label: active ? 'Valider la collecte' : 'Collecte validée',
        icon: Icons.arrow_forward,
        isLoading: saving,
        isFullWidth: true,
        onPressed: active && data.collections.isNotEmpty ? onValidate : null,
      ),
    ],
  );
}

class _DistributionStep extends StatelessWidget {
  const _DistributionStep({
    required this.data,
    required this.distributed,
    required this.remaining,
    required this.beneficiaries,
    required this.comment,
    required this.saving,
    required this.recordingEncounter,
    required this.active,
    required this.onDistributedChanged,
    required this.onRecordEncounter,
    required this.onSave,
  });
  final MaraudeOperationBundle data;
  final TextEditingController distributed;
  final TextEditingController remaining;
  final TextEditingController beneficiaries;
  final TextEditingController comment;
  final bool saving;
  final bool recordingEncounter;
  final bool active;
  final VoidCallback onDistributedChanged;
  final VoidCallback onRecordEncounter;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) => _StepCard(
    title: '3. Distribution',
    subtitle: '${data.totalCollectedBoxes} boîtes collectées',
    children: [
      _QuantityRow(
        label: 'Boîtes distribuées',
        controller: distributed,
        integer: true,
        onChanged: (_) => onDistributedChanged(),
      ),
      _QuantityRow(
        label: 'Bénéficiaires',
        controller: beneficiaries,
        integer: true,
      ),
      _QuantityRow(
        label: 'Boîtes restantes',
        controller: remaining,
        integer: true,
      ),
      TextField(
        controller: comment,
        maxLines: 3,
        decoration: const InputDecoration(
          labelText: 'Commentaire ou incident (optionnel)',
        ),
      ),
      const Divider(height: DsSpacing.xl),
      Text('Rencontres', style: DsTypography.h3),
      const SizedBox(height: DsSpacing.xs),
      Text(
        '${data.encounterCount} ${data.encounterCount == 1 ? 'rencontre enregistrée' : 'rencontres enregistrées'}',
      ),
      const SizedBox(height: DsSpacing.md),
      DsPrimaryButton(
        label: 'Enregistrer une rencontre',
        icon: Icons.add_location_alt_outlined,
        isLoading: recordingEncounter,
        isFullWidth: true,
        onPressed: active && !recordingEncounter ? onRecordEncounter : null,
      ),
      const SizedBox(height: DsSpacing.xl),
      DsPrimaryButton(
        label: active
            ? 'Terminer la distribution'
            : 'Enregistrer les corrections',
        icon: active ? Icons.arrow_forward : Icons.save_outlined,
        isLoading: saving,
        isFullWidth: true,
        onPressed: onSave,
      ),
    ],
  );
}

class _EquipmentReturnStep extends StatelessWidget {
  const _EquipmentReturnStep({
    required this.data,
    required this.returnControllers,
    required this.incidents,
    required this.incidentNotes,
    required this.saving,
    required this.active,
    required this.onIncidentChanged,
    required this.onSave,
  });
  final MaraudeOperationBundle data;
  final Map<String, TextEditingController> returnControllers;
  final Map<String, EquipmentIncidentType?> incidents;
  final Map<String, TextEditingController> incidentNotes;
  final bool saving;
  final bool active;
  final void Function(String, EquipmentIncidentType?) onIncidentChanged;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) => _StepCard(
    title: '4. Retour matériel',
    subtitle: 'Confirmez les quantités retournées et signalez les incidents.',
    children: [
      if (data.equipment.isEmpty) const Text('Aucun matériel à retourner.'),
      for (final item in data.equipment) ...[
        Text(item.name, style: DsTypography.h3),
        _QuantityRow(
          label: '${item.takenQuantity ?? 0} emporté(s)',
          controller: returnControllers[item.id]!,
          integer: true,
        ),
        DropdownButtonFormField<EquipmentIncidentType?>(
          initialValue: incidents[item.id],
          decoration: const InputDecoration(labelText: 'Problème éventuel'),
          items: [
            const DropdownMenuItem(value: null, child: Text('Aucun problème')),
            for (final incident in EquipmentIncidentType.values)
              DropdownMenuItem(value: incident, child: Text(incident.label)),
          ],
          onChanged: (value) => onIncidentChanged(item.id, value),
        ),
        if (incidents[item.id] != null) ...[
          const SizedBox(height: DsSpacing.sm),
          TextField(
            controller: incidentNotes[item.id],
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Note d’incident'),
          ),
        ],
        const Divider(height: DsSpacing.xl),
      ],
      DsPrimaryButton(
        label: active ? 'Valider le retour' : 'Enregistrer les corrections',
        icon: active ? Icons.arrow_forward : Icons.save_outlined,
        isLoading: saving,
        isFullWidth: true,
        onPressed: onSave,
      ),
    ],
  );
}

class _SummaryStep extends StatelessWidget {
  const _SummaryStep({
    required this.data,
    required this.concert,
    required this.canClose,
    required this.saving,
    required this.onClose,
  });
  final MaraudeOperationBundle data;
  final Concert? concert;
  final bool canClose;
  final bool saving;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final distribution = data.distribution;
    final duration = concert?.actualStartAt == null
        ? '—'
        : _duration(DateTime.now().difference(concert!.actualStartAt!));
    final incidents = data.equipment
        .where((item) => item.incidentType != null)
        .length;
    return _StepCard(
      title: '5. Bilan',
      subtitle: 'Vérifiez les informations avant la clôture.',
      children: [
        _InfoRow('Durée', duration),
        _InfoRow('Poids collecté', '${_number(data.totalCollectedWeight)} kg'),
        _InfoRow('Boîtes collectées', '${data.totalCollectedBoxes}'),
        _InfoRow(
          'Boîtes distribuées',
          '${distribution?.distributedBoxes ?? 0}',
        ),
        _InfoRow('Boîtes restantes', '${distribution?.remainingBoxes ?? 0}'),
        _InfoRow(
          'Bénéficiaires',
          '${distribution?.estimatedBeneficiaries ?? 0}',
        ),
        _InfoRow('Rencontres géolocalisées', '${data.encounterCount}'),
        _InfoRow('Incidents matériels', '$incidents'),
        const SizedBox(height: DsSpacing.xl),
        if (canClose)
          DsPrimaryButton(
            label: 'Clôturer la maraude',
            icon: Icons.check_circle_outline,
            isLoading: saving,
            isFullWidth: true,
            onPressed: onClose,
          )
        else
          const Text(
            'Seul le Chef d’équipe ou un administrateur peut clôturer la maraude.',
          ),
      ],
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.title,
    required this.subtitle,
    required this.children,
  });
  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => DsCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: DsTypography.h2),
        const SizedBox(height: DsSpacing.xs),
        Text(subtitle),
        const Divider(height: DsSpacing.xl),
        ...children,
      ],
    ),
  );
}

class _QuantityRow extends StatelessWidget {
  const _QuantityRow({
    required this.label,
    required this.controller,
    this.enabled = true,
    this.integer = false,
    this.onChanged,
  });
  final String label;
  final TextEditingController controller;
  final bool enabled;
  final bool integer;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: DsSpacing.md),
    child: TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: TextInputType.numberWithOptions(decimal: !integer),
      onChanged: onChanged,
      decoration: InputDecoration(labelText: label),
    ),
  );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: DsSpacing.sm),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 170,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(child: Text(value)),
      ],
    ),
  );
}

class _CollectionInput {
  const _CollectionInput(this.description, this.boxes, this.weightKg);
  final String description;
  final int boxes;
  final double weightKg;
}

class _CollectionDialog extends StatefulWidget {
  const _CollectionDialog({this.line});
  final MaraudeCollection? line;

  @override
  State<_CollectionDialog> createState() => _CollectionDialogState();
}

class _CollectionDialogState extends State<_CollectionDialog> {
  final _key = GlobalKey<FormState>();
  late final _description = TextEditingController(
    text: widget.line?.description,
  );
  late final _boxes = TextEditingController(
    text: widget.line == null ? '' : '${widget.line!.quantity.round()}',
  );
  late final _weight = TextEditingController(
    text: widget.line == null ? '' : _number(widget.line!.weightKg ?? 0),
  );

  @override
  void dispose() {
    _description.dispose();
    _boxes.dispose();
    _weight.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.line == null ? 'Ajouter un plat' : 'Modifier le plat'),
    content: SizedBox(
      width: 480,
      child: Form(
        key: _key,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _description,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Nom ou type de plat',
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Champ obligatoire'
                  : null,
            ),
            const SizedBox(height: DsSpacing.md),
            TextFormField(
              controller: _boxes,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Nombre de boîtes'),
              validator: (value) => (int.tryParse(value ?? '') ?? 0) <= 0
                  ? 'Saisissez au moins une boîte'
                  : null,
            ),
            const SizedBox(height: DsSpacing.md),
            TextFormField(
              controller: _weight,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Poids total (kg)'),
              validator: (value) => _tryDouble(value ?? '') <= 0
                  ? 'Saisissez un poids supérieur à zéro'
                  : null,
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Annuler'),
      ),
      FilledButton(
        onPressed: () {
          if (!_key.currentState!.validate()) return;
          Navigator.pop(
            context,
            _CollectionInput(
              _description.text.trim(),
              int.parse(_boxes.text),
              _tryDouble(_weight.text),
            ),
          );
        },
        child: const Text('Enregistrer'),
      ),
    ],
  );
}

int _parseInt(String value) {
  final parsed = int.tryParse(value.trim());
  if (parsed == null || parsed < 0) {
    throw const FormatException('Saisissez une quantité valide.');
  }
  return parsed;
}

double _parseDouble(String value) {
  final parsed = double.tryParse(value.trim().replaceAll(',', '.'));
  if (parsed == null || parsed < 0) {
    throw const FormatException('Saisissez une quantité valide.');
  }
  return parsed;
}

double _tryDouble(String value) =>
    double.tryParse(value.trim().replaceAll(',', '.')) ?? -1;
String _number(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toStringAsFixed(2).replaceAll('.', ',');
String _duration(Duration duration) =>
    '${duration.inHours} h ${(duration.inMinutes % 60).toString().padLeft(2, '0')}';

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
