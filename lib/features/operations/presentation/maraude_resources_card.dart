import 'package:club_sandwich/features/consumables/data/consumable_providers.dart';
import 'package:club_sandwich/features/consumables/domain/consumable.dart';
import 'package:club_sandwich/features/equipment/data/equipment_providers.dart';
import 'package:club_sandwich/features/equipment/domain/equipment_asset.dart';
import 'package:club_sandwich/features/operations/data/maraude_operation_providers.dart';
import 'package:club_sandwich/features/operations/domain/maraude_workflow.dart';
import 'package:club_sandwich/shared/utils/error_messages.dart';
import 'package:club_sandwich/shared/widgets/app_state_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MaraudeResourcesCard extends ConsumerWidget {
  const MaraudeResourcesCard({
    required this.concertId,
    required this.canManage,
    required this.canEditPlan,
    super.key,
  });

  final String concertId;
  final bool canManage;
  final bool canEditPlan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bundle = ref.watch(maraudeOperationBundleProvider(concertId));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: bundle.when(
          loading: () =>
              const AppLoadingState(label: 'Chargement des ressources'),
          error: (error, _) => AppErrorState(
            message: describeError(
              error,
              'Impossible de charger les ressources prévues.',
            ),
            onRetry: () =>
                ref.invalidate(maraudeOperationBundleProvider(concertId)),
          ),
          data: (data) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.inventory_2_outlined),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Ressources prévues',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  if (canManage && canEditPlan)
                    OutlinedButton.icon(
                      onPressed: () => _edit(context, ref, data),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Planifier'),
                    ),
                ],
              ),
              const Divider(height: 28),
              Text(
                'Consommables',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (data.consumables.isEmpty)
                const Text('Aucun consommable prévu.'),
              for (final item in data.consumables)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(item.name),
                  trailing: Text(
                    '${_number(item.actualQuantity ?? item.plannedQuantity)} ${item.unit.label}${(item.actualQuantity ?? item.plannedQuantity) > 1 ? 's' : ''}',
                  ),
                ),
              const SizedBox(height: 12),
              Text('Matériel', style: Theme.of(context).textTheme.titleMedium),
              if (data.equipment.isEmpty) const Text('Aucun matériel prévu.'),
              for (final item in data.equipment)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(item.name),
                  subtitle: Text(
                    item.locationName ?? 'Emplacement non renseigné',
                  ),
                  trailing: Text(
                    '${item.takenQuantity ?? item.plannedQuantity}',
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    MaraudeOperationBundle bundle,
  ) async {
    final consumables = await ref.read(consumablesProvider.future);
    final equipment = await ref.read(equipmentAssetsProvider.future);
    if (!context.mounted) return;
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => _ResourcePlanDialog(
        concertId: concertId,
        consumables: consumables,
        equipment: equipment,
        bundle: bundle,
      ),
    );
    if (saved == true) {
      ref.invalidate(maraudeOperationBundleProvider(concertId));
    }
  }
}

class _ResourcePlanDialog extends ConsumerStatefulWidget {
  const _ResourcePlanDialog({
    required this.concertId,
    required this.consumables,
    required this.equipment,
    required this.bundle,
  });

  final String concertId;
  final List<Consumable> consumables;
  final List<EquipmentAsset> equipment;
  final MaraudeOperationBundle bundle;

  @override
  ConsumerState<_ResourcePlanDialog> createState() =>
      _ResourcePlanDialogState();
}

class _ResourcePlanDialogState extends ConsumerState<_ResourcePlanDialog> {
  late final Map<String, TextEditingController> _consumables = {
    for (final item in widget.consumables)
      item.id: TextEditingController(
        text: _number(
          widget.bundle.consumables
                  .where((entry) => entry.consumableId == item.id)
                  .firstOrNull
                  ?.plannedQuantity ??
              0,
        ),
      ),
  };
  late final Map<String, TextEditingController> _equipment = {
    for (final item in widget.equipment)
      item.id: TextEditingController(
        text:
            '${widget.bundle.equipment.where((entry) => entry.equipmentId == item.id).firstOrNull?.plannedQuantity ?? 0}',
      ),
  };
  var _saving = false;

  @override
  void dispose() {
    for (final controller in [..._consumables.values, ..._equipment.values]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final consumables = <String, double>{};
    final equipment = <String, int>{};
    for (final entry in _consumables.entries) {
      final value = double.tryParse(entry.value.text.replaceAll(',', '.'));
      if (value == null || value < 0) {
        return _showError('Une quantité de consommable est invalide.');
      }
      if (value > 0) consumables[entry.key] = value;
    }
    for (final entry in _equipment.entries) {
      final value = int.tryParse(entry.value.text);
      if (value == null || value < 0) {
        return _showError('Une quantité de matériel est invalide.');
      }
      if (value > 0) equipment[entry.key] = value;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(maraudeOperationRepositoryProvider)
          .planResources(
            concertId: widget.concertId,
            consumables: consumables,
            equipment: equipment,
          );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      _showError(describeError(error, 'Planification impossible.'));
      setState(() => _saving = false);
    }
  }

  void _showError(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Ressources de la maraude'),
    content: SizedBox(
      width: 620,
      height: MediaQuery.sizeOf(context).height * .68,
      child: ListView(
        children: [
          Text('Consommables', style: Theme.of(context).textTheme.titleMedium),
          for (final item in widget.consumables)
            _PlanRow(
              label:
                  '${item.name} · ${_number(item.currentQuantity)} ${item.unit.label} en stock',
              controller: _consumables[item.id]!,
            ),
          const Divider(height: 32),
          Text('Matériel', style: Theme.of(context).textTheme.titleMedium),
          for (final item in widget.equipment)
            _PlanRow(
              label: '${item.name} · ${item.quantityTotal} disponible(s)',
              controller: _equipment[item.id]!,
              integer: true,
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context),
        child: const Text('Annuler'),
      ),
      FilledButton(
        onPressed: _saving ? null : _save,
        child: Text(_saving ? 'Enregistrement…' : 'Enregistrer'),
      ),
    ],
  );
}

class _PlanRow extends StatelessWidget {
  const _PlanRow({
    required this.label,
    required this.controller,
    this.integer = false,
  });
  final String label;
  final TextEditingController controller;
  final bool integer;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: TextField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(decimal: !integer),
      decoration: InputDecoration(labelText: label),
    ),
  );
}

String _number(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toStringAsFixed(2).replaceAll('.', ',');
