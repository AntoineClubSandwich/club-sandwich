import 'package:club_sandwich/design_system/components/buttons/ds_primary_button.dart';
import 'package:club_sandwich/design_system/components/buttons/ds_secondary_button.dart';
import 'package:club_sandwich/design_system/components/surfaces/ds_card.dart';
import 'package:club_sandwich/design_system/tokens/ds_spacing.dart';
import 'package:club_sandwich/design_system/tokens/ds_theme.dart';
import 'package:club_sandwich/design_system/tokens/ds_typography.dart';
import 'package:club_sandwich/features/auth/application/auth_providers.dart';
import 'package:club_sandwich/features/auth/domain/user_account.dart';
import 'package:club_sandwich/features/collections/domain/maraude_collection.dart';
import 'package:club_sandwich/features/concerts/data/concert_providers.dart';
import 'package:club_sandwich/features/concerts/domain/concert.dart';
import 'package:club_sandwich/features/consumables/domain/consumable.dart';
import 'package:club_sandwich/features/encounters/data/encounter_location_service.dart';
import 'package:club_sandwich/features/encounters/data/encounter_providers.dart';
import 'package:club_sandwich/features/operations/data/maraude_operation_providers.dart';
import 'package:club_sandwich/features/operations/data/maraude_operation_repository.dart';
import 'package:club_sandwich/features/operations/domain/maraude_workflow.dart';
import 'package:club_sandwich/features/volunteers/data/concert_volunteer_providers.dart';
import 'package:club_sandwich/features/volunteers/domain/concert_volunteer_application.dart';
import 'package:club_sandwich/shared/utils/error_messages.dart';
import 'package:club_sandwich/features/venues/domain/venue.dart';
import 'package:club_sandwich/shared/widgets/app_state_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

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
  final Map<String, TextEditingController> _distributionControllers = {};
  final ScrollController _stepScrollController = ScrollController();
  final _beneficiaries = TextEditingController();
  final _distributionComment = TextEditingController();
  var _distributionInitialized = false;
  var _equipmentConfirmed = false;
  var _saving = false;
  var _recordingEncounter = false;

  @override
  void dispose() {
    for (final controller in [
      ..._preparationControllers.values,
      ..._distributionControllers.values,
      _beneficiaries,
      _distributionComment,
    ]) {
      controller.dispose();
    }
    _stepScrollController.dispose();
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
                    controller: _stepScrollController,
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
    if (!_distributionInitialized) {
      final boxAllocations = data.consumables
          .where((item) => item.unit == InventoryUnit.box)
          .toList(growable: false);
      for (final item in boxAllocations) {
        // What went back to the stock: nothing until the distribution has
        // been saved once, so the field starts at 0 and the volunteers
        // count the boxes left in the bags.
        var returned = 0;
        if (item.distributedQuantity != null) {
          returned = item.remainingBoxes;
        } else if (boxAllocations.length == 1) {
          final legacyTotal = data.distribution?.distributedBoxes;
          if (legacyTotal != null) {
            returned =
                item.preparedBoxes -
                (legacyTotal > item.preparedBoxes
                    ? item.preparedBoxes
                    : legacyTotal);
          }
        }
        _distributionControllers[item.id] = TextEditingController(
          text: '$returned',
        );
      }
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
      equipmentConfirmed: _equipmentConfirmed,
      onConfirmEquipment: () => setState(() => _equipmentConfirmed = true),
      onValidate: () => _validatePreparation(data),
      onAddConsumable: () => _addConsumable(data),
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
      controllers: _distributionControllers,
      beneficiaries: _beneficiaries,
      comment: _distributionComment,
      saving: _saving,
      recordingEncounter: _recordingEncounter,
      active: current == viewed,
      onReturnedChanged: () => setState(() {}),
      onRecordEncounter: _recordEncounter,
      onSave: () => _saveDistribution(data, validate: current == viewed),
    ),
    MaraudeOperationalStep.equipmentReturn => _EquipmentReturnStep(
      data: data,
      saving: _saving,
      active: current == viewed,
      onConfirm: (problems) => _confirmEquipmentReturn(data, problems),
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
          // Confirming "tout le matériel" means the planned equipment was
          // taken - the quantities are no longer typed in by hand.
          equipmentQuantities: {
            for (final item in data.equipment)
              item.id: item.plannedQuantity > item.quantityTotal
                  ? item.quantityTotal
                  : item.plannedQuantity,
          },
        ),
    'Préparation validée.',
    nextStep: MaraudeOperationalStep.collection,
  );

  Future<void> _addConsumable(MaraudeOperationBundle data) async {
    final catalog = await ref
        .read(maraudeOperationRepositoryProvider)
        .fetchConsumableCatalog(widget.concertId);
    if (!mounted) return;
    final existingIds = data.consumables
        .map((item) => item.consumableId)
        .toSet();
    final available = catalog
        .where((item) => !existingIds.contains(item.id))
        .toList(growable: false);
    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            catalog.isEmpty
                ? 'Aucun consommable disponible dans le stock.'
                : 'Tous les consommables du stock sont déjà listés.',
          ),
        ),
      );
      return;
    }
    final picked =
        await showDialog<_PickedResource<MaraudeResourceCatalogConsumable>>(
          context: context,
          builder: (_) => _AddResourceDialog<MaraudeResourceCatalogConsumable>(
            title: 'Ajouter un consommable',
            items: available,
            labelFor: (item) =>
                '${item.name} · ${_number(item.currentQuantity)} ${item.unit.label} en stock',
            integer: false,
          ),
        );
    if (picked == null) return;
    await _run(
      () => ref
          .read(maraudeOperationRepositoryProvider)
          .addResourceAllocation(
            concertId: widget.concertId,
            consumableId: picked.item.id,
            quantity: picked.quantity,
          ),
      '${picked.item.name} ajouté.',
    );
  }

  Future<void> _validateStep(MaraudeOperationalStep step) => _run(
    () => ref
        .read(maraudeOperationRepositoryProvider)
        .validateStep(widget.concertId, step),
    '${step.label} validée.',
    nextStep: switch (step) {
      MaraudeOperationalStep.preparation => MaraudeOperationalStep.collection,
      MaraudeOperationalStep.collection => MaraudeOperationalStep.distribution,
      MaraudeOperationalStep.distribution =>
        MaraudeOperationalStep.equipmentReturn,
      MaraudeOperationalStep.equipmentReturn => MaraudeOperationalStep.summary,
      MaraudeOperationalStep.summary => null,
    },
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
            averageWeightKg: result.averageWeightKg,
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
    final boxAllocations = data.consumables.where(
      (item) => item.unit == InventoryUnit.box,
    );
    final returnedByAllocation = <String, int>{};
    for (final item in boxAllocations) {
      final returned = _parseInt(_distributionControllers[item.id]!.text);
      if (returned > item.preparedBoxes) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${item.name} : les boîtes remises au stock ne peuvent pas '
              'dépasser les ${item.preparedBoxes} emportées.',
            ),
          ),
        );
        return;
      }
      returnedByAllocation[item.id] = returned;
    }
    await _run(
      () async {
        await ref
            .read(maraudeOperationRepositoryProvider)
            .saveDistribution(
              concertId: widget.concertId,
              returnedBoxesByAllocation: returnedByAllocation,
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
      },
      validate ? 'Distribution validée.' : 'Corrections enregistrées.',
      nextStep: validate ? MaraudeOperationalStep.equipmentReturn : null,
    );
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

  /// "Le matériel est-il restitué et propre ?" - answering OUI records
  /// everything taken as returned, with no incident, then closes the step.
  /// [problems] holds the incidents reported instead (by allocation id).
  Future<void> _confirmEquipmentReturn(
    MaraudeOperationBundle data,
    Map<String, _EquipmentProblem> problems,
  ) => _run(
    () async {
      await ref
          .read(maraudeOperationRepositoryProvider)
          .recordEquipmentReturn(
            concertId: widget.concertId,
            returns: [
              for (final item in data.equipment)
                EquipmentReturnDraft(
                  allocationId: item.id,
                  returnedQuantity: item.takenQuantity ?? 0,
                  incidentType: problems[item.id]?.type,
                  incidentNote: problems[item.id]?.note,
                ),
            ],
          );
      await ref
          .read(maraudeOperationRepositoryProvider)
          .validateStep(
            widget.concertId,
            MaraudeOperationalStep.equipmentReturn,
          );
    },
    'Retour matériel validé.',
    nextStep: MaraudeOperationalStep.summary,
  );

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

  Future<void> _run(
    Future<void> Function() action,
    String success, {
    MaraudeOperationalStep? nextStep,
  }) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await action();
      ref.invalidate(maraudeOperationBundleProvider(widget.concertId));
      if (!mounted) return;
      if (nextStep != null) {
        setState(() => _viewedStep = nextStep);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_stepScrollController.hasClients) {
            _stepScrollController.jumpTo(0);
          }
        });
      }
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
          _InfoRow('Salle', concert.venueName ?? '-'),
          _InfoRow('Adresse', concert.venue?.formattedAddress ?? '-'),
          if (concert.venue?.formattedArtistEntrance case final entrance?)
            _InfoRow('Entrée artiste', entrance),
          _InfoRow('Accès', concert.venue?.accessInstructions ?? '-'),
          if (_mapsQuery(concert.venue) case final query?) ...[
            const SizedBox(height: DsSpacing.sm),
            DsSecondaryButton(
              onPressed: () => _openInMaps(query),
              icon: Icons.directions_outlined,
              label: 'Ouvrir l’itinéraire',
            ),
            const SizedBox(height: DsSpacing.sm),
          ],
          _InfoRow('Fermeture catering', concert.cateringClosesAt ?? '-'),
          _InfoRow(
            'Contact tourneur',
            [
              concert.promoterContactName,
              concert.promoterContactPhone,
            ].whereType<String>().join(' · ').ifEmpty('-'),
          ),
          _InfoRow('Organisation', concert.promoterOrganizationName ?? '-'),
          _InfoRow('Consignes', concert.notes ?? '-'),
        ],
      ),
    ),
  );

  String? _mapsQuery(Venue? venue) {
    if (venue == null) return null;
    return venue.formattedArtistEntrance ?? venue.formattedAddress;
  }

  Future<void> _openInMaps(String query) async {
    final url = Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': query,
    });
    final opened = await launchUrl(url, webOnlyWindowName: '_blank');
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d’ouvrir l’itinéraire.')),
      );
    }
  }
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
    required this.equipmentConfirmed,
    required this.onConfirmEquipment,
    required this.onValidate,
    required this.onAddConsumable,
  });
  final MaraudeOperationBundle data;
  final Map<String, TextEditingController> controllers;
  final bool saving;
  final bool active;
  final bool equipmentConfirmed;
  final VoidCallback onConfirmEquipment;
  final VoidCallback onValidate;
  final VoidCallback onAddConsumable;

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
      if (active) ...[
        const SizedBox(height: DsSpacing.sm),
        OutlinedButton.icon(
          onPressed: onAddConsumable,
          icon: const Icon(Icons.add),
          label: const Text('Ajouter un consommable'),
        ),
      ],
      const SizedBox(height: DsSpacing.lg),
      Text('Matériel', style: DsTypography.h3),
      const SizedBox(height: DsSpacing.xs),
      _YesConfirmation(
        question: 'Avez-vous bien tout le matériel nécessaire ?',
        hint: _equipmentDefinition,
        confirmed: equipmentConfirmed || !active,
        enabled: active,
        onConfirm: onConfirmEquipment,
      ),
      const SizedBox(height: DsSpacing.xl),
      DsPrimaryButton(
        label: active ? 'Valider et continuer' : 'Préparation validée',
        icon: Icons.arrow_forward,
        isLoading: saving,
        isFullWidth: true,
        onPressed: active && equipmentConfirmed ? onValidate : null,
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
    required this.controllers,
    required this.beneficiaries,
    required this.comment,
    required this.saving,
    required this.recordingEncounter,
    required this.active,
    required this.onReturnedChanged,
    required this.onRecordEncounter,
    required this.onSave,
  });
  final MaraudeOperationBundle data;
  final Map<String, TextEditingController> controllers;
  final TextEditingController beneficiaries;
  final TextEditingController comment;
  final bool saving;
  final bool recordingEncounter;
  final bool active;
  final VoidCallback onReturnedChanged;
  final VoidCallback onRecordEncounter;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final boxAllocations = data.consumables
        .where((item) => item.unit == InventoryUnit.box)
        .toList(growable: false);
    return _StepCard(
      title: '3. Distribution',
      subtitle:
          '${data.totalPreparedBoxes} boîtes emportées · '
          '${boxAllocations.length} ${boxAllocations.length == 1 ? 'référence' : 'références'}',
      children: [
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
        const Divider(height: DsSpacing.xl),
        Text('Fin de distribution', style: DsTypography.h3),
        const SizedBox(height: DsSpacing.xs),
        const Text(
          'Une fois la distribution terminée, comptez les boîtes qui restent '
          'dans les sacs et remettez-les au stock. Les boîtes distribuées '
          'sont calculées automatiquement.',
        ),
        const SizedBox(height: DsSpacing.md),
        if (boxAllocations.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: DsSpacing.md),
            child: Text(
              'Aucune boîte n’a été emportée pendant la préparation.',
            ),
          ),
        for (final item in boxAllocations)
          _ConsumableReturnRow(
            item: item,
            controller: controllers[item.id]!,
            onChanged: onReturnedChanged,
          ),
        const Divider(height: DsSpacing.xl),
        _QuantityRow(
          label: 'Bénéficiaires',
          controller: beneficiaries,
          integer: true,
        ),
        TextField(
          controller: comment,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Commentaire ou incident (optionnel)',
          ),
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
}

class _ConsumableReturnRow extends StatelessWidget {
  const _ConsumableReturnRow({
    required this.item,
    required this.controller,
    required this.onChanged,
  });

  final MaraudeConsumableAllocation item;
  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final returned = int.tryParse(controller.text) ?? 0;
    final distributed = item.preparedBoxes - returned;
    return Padding(
      padding: const EdgeInsets.only(bottom: DsSpacing.md),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(DsSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(item.name, style: DsTypography.h3),
              const SizedBox(height: DsSpacing.xs),
              Text(
                '${item.preparedBoxes} ${item.preparedBoxes == 1 ? 'boîte emportée' : 'boîtes emportées'}',
              ),
              const SizedBox(height: DsSpacing.md),
              _QuantityRow(
                key: ValueKey('returned-${item.id}'),
                label: 'Boîtes remises au stock',
                controller: controller,
                integer: true,
                onChanged: (_) => onChanged(),
              ),
              Text(
                '${distributed < 0 ? 0 : distributed} '
                '${distributed == 1 ? 'boîte distribuée' : 'boîtes distribuées'}',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EquipmentProblem {
  const _EquipmentProblem(this.type, this.note);
  final EquipmentIncidentType type;
  final String note;
}

class _EquipmentReturnStep extends StatefulWidget {
  const _EquipmentReturnStep({
    required this.data,
    required this.saving,
    required this.active,
    required this.onConfirm,
  });
  final MaraudeOperationBundle data;
  final bool saving;
  final bool active;
  final ValueChanged<Map<String, _EquipmentProblem>> onConfirm;

  @override
  State<_EquipmentReturnStep> createState() => _EquipmentReturnStepState();
}

class _EquipmentReturnStepState extends State<_EquipmentReturnStep> {
  var _reporting = false;
  final Map<String, EquipmentIncidentType?> _types = {};
  final Map<String, TextEditingController> _notes = {};

  @override
  void dispose() {
    for (final controller in _notes.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Map<String, _EquipmentProblem> _problems() => {
    for (final entry in _types.entries)
      if (entry.value != null)
        entry.key: _EquipmentProblem(
          entry.value!,
          _notes[entry.key]?.text.trim() ?? '',
        ),
  };

  @override
  Widget build(BuildContext context) {
    final problems = _problems();
    final canReport = widget.active && widget.data.equipment.isNotEmpty;
    return _StepCard(
      title: '4. Retour matériel',
      subtitle: 'Vérifiez le matériel avant de clôturer la maraude.',
      children: [
        _YesConfirmation(
          question: 'Le matériel est-il restitué et propre ?',
          hint: _equipmentDefinition,
          confirmed: !widget.active,
          enabled: widget.active && !_reporting,
          isLoading: widget.saving && !_reporting,
          onConfirm: () => widget.onConfirm(const {}),
        ),
        if (canReport && !_reporting) ...[
          const SizedBox(height: DsSpacing.md),
          DsSecondaryButton(
            label: 'Signaler un problème',
            icon: Icons.report_problem_outlined,
            isFullWidth: true,
            onPressed: () => setState(() => _reporting = true),
          ),
        ],
        if (canReport && _reporting) ...[
          const Divider(height: DsSpacing.xl),
          Text('Quel matériel pose problème ?', style: DsTypography.h3),
          const SizedBox(height: DsSpacing.sm),
          for (final item in widget.data.equipment) ...[
            Text(item.name, style: DsTypography.h3),
            const SizedBox(height: DsSpacing.xs),
            DropdownButtonFormField<EquipmentIncidentType?>(
              initialValue: _types[item.id],
              decoration: const InputDecoration(labelText: 'Problème éventuel'),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('Aucun problème'),
                ),
                for (final incident in EquipmentIncidentType.values)
                  DropdownMenuItem(
                    value: incident,
                    child: Text(incident.label),
                  ),
              ],
              onChanged: (value) => setState(() => _types[item.id] = value),
            ),
            if (_types[item.id] != null) ...[
              const SizedBox(height: DsSpacing.sm),
              TextField(
                controller: _notes.putIfAbsent(
                  item.id,
                  () => TextEditingController(),
                ),
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Précisions (quantité, état…)',
                ),
              ),
            ],
            const SizedBox(height: DsSpacing.lg),
          ],
          DsPrimaryButton(
            label: 'Valider le retour avec ces problèmes',
            icon: Icons.arrow_forward,
            isLoading: widget.saving,
            isFullWidth: true,
            // Re-read at tap time: typing in a note doesn't rebuild.
            onPressed: problems.isEmpty
                ? null
                : () => widget.onConfirm(_problems()),
          ),
          const SizedBox(height: DsSpacing.sm),
          TextButton(
            onPressed: widget.saving
                ? null
                : () => setState(() => _reporting = false),
            child: const Text('Annuler'),
          ),
        ],
      ],
    );
  }
}

/// A yes/no question where only "OUI" is offered: the volunteers must
/// actively answer it before moving on.
/// What "le matériel" means for the volunteers, shown under both equipment
/// questions so nobody reads it as only the fixed assets of the stock.
const _equipmentDefinition =
    'Le matériel, ce sont les sacs, les cabas et le pack logistique de base '
    '(gants, masques, nettoyant pour les mains, trousse de secours, '
    'petits sacs…).';

class _YesConfirmation extends StatelessWidget {
  const _YesConfirmation({
    required this.question,
    required this.confirmed,
    required this.enabled,
    required this.onConfirm,
    this.hint,
    this.isLoading = false,
  });
  final String question;
  final String? hint;
  final bool confirmed;
  final bool enabled;
  final bool isLoading;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(question, style: DsTypography.h3),
      if (hint != null) ...[const SizedBox(height: DsSpacing.xs), Text(hint!)],
      const SizedBox(height: DsSpacing.md),
      if (confirmed)
        DsPrimaryButton(
          label: 'OUI ✓',
          icon: Icons.check_circle_outline,
          isFullWidth: true,
          onPressed: null,
        )
      else
        DsPrimaryButton(
          label: 'OUI',
          isLoading: isLoading,
          isFullWidth: true,
          onPressed: enabled ? onConfirm : null,
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
        ? '-'
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
        _InfoRow('Boîtes emportées', '${data.totalPreparedBoxes}'),
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
    super.key,
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
  const _CollectionInput(this.description, this.boxes, this.averageWeightKg);
  final String description;
  final int boxes;
  final double averageWeightKg;
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
    text: widget.line == null ? '' : _number(widget.line!.averageWeightKg ?? 0),
  );

  @override
  void dispose() {
    _description.dispose();
    _boxes.dispose();
    _weight.dispose();
    super.dispose();
  }

  String _calculatedTotalLabel() {
    final boxes = int.tryParse(_boxes.text.trim());
    final average = double.tryParse(_weight.text.trim().replaceAll(',', '.'));
    if (boxes == null || average == null) return '-';
    return '${_number(boxes * average)} kg';
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
              onChanged: (_) => setState(() {}),
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
              decoration: const InputDecoration(
                labelText: 'Poids moyen d’une boîte (kg)',
                hintText: 'Ex. : 0,45',
              ),
              onChanged: (_) => setState(() {}),
              validator: (value) => _tryDouble(value ?? '') <= 0
                  ? 'Saisissez un poids supérieur à zéro'
                  : null,
            ),
            const SizedBox(height: DsSpacing.sm),
            Text(
              'Poids total calculé : ${_calculatedTotalLabel()}',
              style: Theme.of(context).textTheme.titleSmall,
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

class _PickedResource<T> {
  const _PickedResource(this.item, this.quantity);
  final T item;
  final double quantity;
}

class _AddResourceDialog<T> extends StatefulWidget {
  const _AddResourceDialog({
    required this.title,
    required this.items,
    required this.labelFor,
    required this.integer,
  });

  final String title;
  final List<T> items;
  final String Function(T item) labelFor;
  final bool integer;

  @override
  State<_AddResourceDialog<T>> createState() => _AddResourceDialogState<T>();
}

class _AddResourceDialogState<T> extends State<_AddResourceDialog<T>> {
  T? _selected;
  final _quantityController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  void _confirm() {
    if (_selected == null) {
      setState(() => _error = 'Choisissez un élément.');
      return;
    }
    final quantity = widget.integer
        ? (int.tryParse(_quantityController.text.trim())?.toDouble() ?? -1)
        : _tryDouble(_quantityController.text);
    if (quantity <= 0) {
      setState(() => _error = 'Saisissez une quantité valide.');
      return;
    }
    Navigator.pop(context, _PickedResource<T>(_selected as T, quantity));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: SizedBox(
      width: 480,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<T>(
            initialValue: _selected,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Élément'),
            items: [
              for (final item in widget.items)
                DropdownMenuItem(
                  value: item,
                  child: Text(
                    widget.labelFor(item),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (value) => setState(() {
              _selected = value;
              _error = null;
            }),
          ),
          const SizedBox(height: DsSpacing.md),
          TextField(
            controller: _quantityController,
            keyboardType: TextInputType.numberWithOptions(
              decimal: !widget.integer,
            ),
            decoration: const InputDecoration(labelText: 'Quantité emportée'),
          ),
          if (_error != null) ...[
            const SizedBox(height: DsSpacing.sm),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Annuler'),
      ),
      FilledButton(onPressed: _confirm, child: const Text('Ajouter')),
    ],
  );
}
