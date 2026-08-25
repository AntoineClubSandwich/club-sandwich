import 'package:club_sandwich/design_system/components/buttons/ds_primary_button.dart';
import 'package:club_sandwich/design_system/components/indicators/ds_badge.dart';
import 'package:club_sandwich/design_system/components/indicators/ds_semantic_variant.dart';
import 'package:club_sandwich/design_system/components/surfaces/ds_card.dart';
import 'package:club_sandwich/design_system/tokens/ds_spacing.dart';
import 'package:club_sandwich/design_system/tokens/ds_theme.dart';
import 'package:club_sandwich/design_system/tokens/ds_typography.dart';
import 'package:club_sandwich/features/consumables/data/consumable_providers.dart';
import 'package:club_sandwich/features/consumables/domain/consumable.dart';
import 'package:club_sandwich/features/equipment/data/equipment_providers.dart';
import 'package:club_sandwich/features/equipment/domain/equipment_asset.dart';
import 'package:club_sandwich/features/stock/presentation/stock_location_dialog.dart';
import 'package:club_sandwich/shared/utils/error_messages.dart';
import 'package:club_sandwich/shared/widgets/app_state_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ConsumablesScreen extends ConsumerStatefulWidget {
  const ConsumablesScreen({this.embedded = false, super.key});

  final bool embedded;

  @override
  ConsumerState<ConsumablesScreen> createState() => _ConsumablesScreenState();
}

class _ConsumablesScreenState extends ConsumerState<ConsumablesScreen> {
  var _purchaseOnly = false;
  var _query = '';

  @override
  Widget build(BuildContext context) {
    final asyncItems = ref.watch(consumablesProvider);
    final content = asyncItems.when(
      loading: () =>
          const AppLoadingState(label: 'Chargement des consommables'),
      error: (error, _) => AppErrorState(
        message: describeError(
          error,
          'Impossible de charger les consommables.',
        ),
        onRetry: () => ref.invalidate(consumablesProvider),
      ),
      data: (items) {
        final normalized = _query.trim().toLowerCase();
        final filtered = items
            .where((item) {
              if (_purchaseOnly && !item.shouldBuy) return false;
              return normalized.isEmpty ||
                  item.name.toLowerCase().contains(normalized) ||
                  item.category.toLowerCase().contains(normalized);
            })
            .toList(growable: false);
        return ListView(
          padding: const EdgeInsets.all(DsSpacing.xl),
          children: [
            _Header(
              count: items.length,
              purchaseCount: items.where((item) => item.shouldBuy).length,
              onCreate: () => _openEditor(),
            ),
            const SizedBox(height: DsSpacing.lg),
            Wrap(
              spacing: DsSpacing.md,
              runSpacing: DsSpacing.md,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 320,
                  child: TextField(
                    onChanged: (value) => setState(() => _query = value),
                    decoration: const InputDecoration(
                      hintText: 'Rechercher un consommable',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
                FilterChip(
                  label: const Text('À acheter'),
                  selected: _purchaseOnly,
                  onSelected: (value) => setState(() => _purchaseOnly = value),
                ),
              ],
            ),
            const SizedBox(height: DsSpacing.lg),
            if (filtered.isEmpty)
              const AppEmptyState(
                title: 'Aucun consommable',
                message: 'Ajoutez un consommable ou modifiez les filtres.',
                icon: Icons.shopping_basket_outlined,
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth >= 1100
                      ? (constraints.maxWidth - DsSpacing.lg) / 2
                      : constraints.maxWidth;
                  return Wrap(
                    spacing: DsSpacing.lg,
                    runSpacing: DsSpacing.lg,
                    children: [
                      for (final item in filtered)
                        SizedBox(
                          width: width,
                          child: _ConsumableCard(
                            item: item,
                            onMove: () => _openMovement(item),
                            onEdit: () => _openEditor(item),
                            onHistory: () => _openHistory(item),
                            onArchive: () => _archive(item),
                          ),
                        ),
                    ],
                  );
                },
              ),
          ],
        );
      },
    );
    return Theme(
      data: DsTheme.light,
      child: widget.embedded
          ? content
          : Scaffold(backgroundColor: Colors.transparent, body: content),
    );
  }

  Future<void> _openEditor([Consumable? item]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => _ConsumableEditor(item: item),
    );
    if (saved == true) ref.invalidate(consumablesProvider);
  }

  Future<void> _openMovement(Consumable item) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => _StockMovementDialog(item: item),
    );
    if (saved == true) {
      ref.invalidate(consumablesProvider);
      ref.invalidate(consumableMovementsProvider(item.id));
    }
  }

  Future<void> _openHistory(Consumable item) => showDialog<void>(
    context: context,
    builder: (context) => _MovementHistoryDialog(item: item),
  );

  Future<void> _archive(Consumable item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archiver ce consommable ?'),
        content: Text(
          '${item.name} ne sera plus proposé pour les prochaines maraudes. '
          'Son historique sera conservé.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Archiver'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(consumableRepositoryProvider).archive(item.id);
    ref.invalidate(consumablesProvider);
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.count,
    required this.purchaseCount,
    required this.onCreate,
  });

  final int count;
  final int purchaseCount;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.spaceBetween,
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: DsSpacing.lg,
    runSpacing: DsSpacing.md,
    children: [
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Consommables', style: DsTypography.h1),
          Text(
            '$count référence${count > 1 ? 's' : ''} · $purchaseCount à acheter',
          ),
        ],
      ),
      DsPrimaryButton(
        label: 'Nouveau consommable',
        icon: Icons.add,
        onPressed: onCreate,
      ),
    ],
  );
}

class _ConsumableCard extends StatelessWidget {
  const _ConsumableCard({
    required this.item,
    required this.onMove,
    required this.onEdit,
    required this.onHistory,
    required this.onArchive,
  });

  final Consumable item;
  final VoidCallback onMove;
  final VoidCallback onEdit;
  final VoidCallback onHistory;
  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) {
    final variant = switch (item.stockStatus) {
      ConsumableStockStatus.ok => DsSemanticVariant.success,
      ConsumableStockStatus.low => DsSemanticVariant.warning,
      ConsumableStockStatus.out => DsSemanticVariant.error,
    };
    return DsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(item.name, style: DsTypography.h3)),
              DsBadge(label: item.stockStatus.label, variant: variant),
              PopupMenuButton<String>(
                tooltip: 'Actions pour ${item.name}',
                onSelected: (value) => switch (value) {
                  'edit' => onEdit(),
                  'history' => onHistory(),
                  'archive' => onArchive(),
                  _ => null,
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Modifier')),
                  PopupMenuItem(value: 'history', child: Text('Historique')),
                  PopupMenuItem(value: 'archive', child: Text('Archiver')),
                ],
              ),
            ],
          ),
          Text(item.category),
          const SizedBox(height: DsSpacing.md),
          Text(
            '${_number(item.currentQuantity)} ${item.unit.label}${item.currentQuantity > 1 ? 's' : ''}',
            style: DsTypography.h2,
          ),
          Text(
            'Seuil : ${_number(item.alertThreshold)} · ${item.storageLocation ?? 'Emplacement non renseigné'}',
          ),
          const SizedBox(height: DsSpacing.md),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: onMove,
              icon: const Icon(Icons.swap_vert),
              label: const Text('Modifier le stock'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConsumableEditor extends ConsumerStatefulWidget {
  const _ConsumableEditor({this.item});
  final Consumable? item;

  @override
  ConsumerState<_ConsumableEditor> createState() => _ConsumableEditorState();
}

class _ConsumableEditorState extends ConsumerState<_ConsumableEditor> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.item?.name);
  late final _category = TextEditingController(text: widget.item?.category);
  late final _quantity = TextEditingController(
    text: widget.item == null ? '0' : _number(widget.item!.currentQuantity),
  );
  late final _threshold = TextEditingController(
    text: widget.item == null ? '0' : _number(widget.item!.alertThreshold),
  );
  late String? _locationName = widget.item?.storageLocation;
  late var _unit = widget.item?.unit ?? InventoryUnit.unit;
  var _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _category.dispose();
    _quantity.dispose();
    _threshold.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final repository = ref.read(consumableRepositoryProvider);
      if (widget.item == null) {
        await repository.create(
          name: _name.text,
          category: _category.text,
          unit: _unit,
          initialQuantity: _parse(_quantity.text)!,
          alertThreshold: _parse(_threshold.text)!,
          storageLocation: _locationName,
        );
      } else {
        await repository.updateMetadata(
          widget.item!.id,
          name: _name.text,
          category: _category.text,
          unit: _unit,
          alertThreshold: _parse(_threshold.text)!,
          storageLocation: _locationName,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(describeError(error, 'Enregistrement impossible.')),
        ),
      );
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locationsState = ref.watch(equipmentLocationsProvider);
    final locations = locationsState.value ?? const <EquipmentLocation>[];
    final selectedLocation = _locationName?.trim();
    final selectableLocations = [
      if (selectedLocation != null && selectedLocation.isNotEmpty)
        selectedLocation,
      for (final location in locations)
        if (selectedLocation == null ||
            location.name.toLowerCase() != selectedLocation.toLowerCase())
          location.name,
    ];
    return AlertDialog(
      title: Text(
        widget.item == null ? 'Nouveau consommable' : 'Modifier le consommable',
      ),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _name,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Nom'),
                  validator: _required,
                ),
                const SizedBox(height: DsSpacing.md),
                TextFormField(
                  controller: _category,
                  decoration: const InputDecoration(labelText: 'Catégorie'),
                  validator: _required,
                ),
                const SizedBox(height: DsSpacing.md),
                DropdownButtonFormField<InventoryUnit>(
                  initialValue: _unit,
                  decoration: const InputDecoration(labelText: 'Unité'),
                  items: [
                    for (final unit in InventoryUnit.values)
                      DropdownMenuItem(value: unit, child: Text(unit.label)),
                  ],
                  onChanged: (value) => setState(() => _unit = value ?? _unit),
                ),
                const SizedBox(height: DsSpacing.md),
                if (widget.item == null) ...[
                  TextFormField(
                    controller: _quantity,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Quantité initiale',
                    ),
                    validator: _nonNegative,
                  ),
                  const SizedBox(height: DsSpacing.md),
                ],
                TextFormField(
                  controller: _threshold,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Seuil d’alerte',
                  ),
                  validator: _nonNegative,
                ),
                const SizedBox(height: DsSpacing.md),
                DropdownButtonFormField<String?>(
                  key: ValueKey(selectedLocation),
                  initialValue: selectedLocation?.isEmpty ?? true
                      ? null
                      : selectedLocation,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Emplacement',
                    suffixIcon: locationsState.isLoading
                        ? const Padding(
                            padding: EdgeInsets.all(14),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : null,
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Non renseigné'),
                    ),
                    for (final location in selectableLocations)
                      DropdownMenuItem(value: location, child: Text(location)),
                  ],
                  onChanged: locationsState.hasError
                      ? null
                      : (value) => setState(() => _locationName = value),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _saving ? null : _createLocation,
                    icon: const Icon(Icons.add_location_alt_outlined),
                    label: const Text('Créer un emplacement'),
                  ),
                ),
                if (locationsState.hasError)
                  Text(
                    'La liste des emplacements est indisponible.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
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

  Future<void> _createLocation() async {
    final location = await showCreateStockLocationDialog(context, ref);
    if (location != null && mounted) {
      setState(() => _locationName = location.name);
    }
  }
}

class _StockMovementDialog extends ConsumerStatefulWidget {
  const _StockMovementDialog({required this.item});
  final Consumable item;

  @override
  ConsumerState<_StockMovementDialog> createState() =>
      _StockMovementDialogState();
}

class _StockMovementDialogState extends ConsumerState<_StockMovementDialog> {
  late final _quantity = TextEditingController(
    text: _number(widget.item.currentQuantity),
  );
  final _note = TextEditingController();
  var _reason = InventoryMovementReason.restock;
  var _saving = false;

  @override
  void dispose() {
    _quantity.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final quantity = _parse(_quantity.text);
    if (_saving || quantity == null || quantity < 0) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(consumableRepositoryProvider)
          .moveStock(
            id: widget.item.id,
            newQuantity: quantity,
            reason: _reason,
            note: _note.text,
          );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(describeError(error, 'Mouvement impossible.'))),
      );
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Stock · ${widget.item.name}'),
    content: SizedBox(
      width: 440,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _quantity,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Nouvelle quantité'),
          ),
          const SizedBox(height: DsSpacing.md),
          DropdownButtonFormField<InventoryMovementReason>(
            initialValue: _reason,
            decoration: const InputDecoration(labelText: 'Motif'),
            items: [
              for (final reason in InventoryMovementReason.values)
                DropdownMenuItem(value: reason, child: Text(reason.label)),
            ],
            onChanged: (value) => setState(() => _reason = value ?? _reason),
          ),
          const SizedBox(height: DsSpacing.md),
          TextField(
            controller: _note,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Note (optionnelle)'),
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
        child: Text(_saving ? 'Enregistrement…' : 'Valider'),
      ),
    ],
  );
}

class _MovementHistoryDialog extends ConsumerWidget {
  const _MovementHistoryDialog({required this.item});
  final Consumable item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final movements = ref.watch(consumableMovementsProvider(item.id));
    return AlertDialog(
      title: Text('Historique · ${item.name}'),
      content: SizedBox(
        width: 620,
        height: 420,
        child: movements.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Text(describeError(error, 'Historique indisponible.')),
          ),
          data: (items) => items.isEmpty
              ? const Center(child: Text('Aucun mouvement.'))
              : ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const Divider(),
                  itemBuilder: (context, index) {
                    final movement = items[index];
                    final sign = movement.difference > 0 ? '+' : '';
                    return ListTile(
                      title: Text(
                        '${movement.reason.label} · $sign${_number(movement.difference)}',
                      ),
                      subtitle: Text(
                        '${_number(movement.previousQuantity)} → ${_number(movement.newQuantity)} · ${movement.actorName ?? 'Auteur inconnu'}${movement.note == null ? '' : '\n${movement.note}'}',
                      ),
                      trailing: Text(
                        _dateTime(movement.createdAt),
                        textAlign: TextAlign.end,
                      ),
                    );
                  },
                ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Fermer'),
        ),
      ],
    );
  }
}

String? _required(String? value) =>
    value == null || value.trim().isEmpty ? 'Champ obligatoire' : null;
String? _nonNegative(String? value) {
  final parsed = _parse(value ?? '');
  return parsed == null || parsed < 0
      ? 'Saisissez une valeur positive ou nulle'
      : null;
}

double? _parse(String value) =>
    double.tryParse(value.trim().replaceAll(',', '.'));
String _number(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toStringAsFixed(2).replaceAll('.', ',');
String _dateTime(DateTime value) {
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year}\n'
      '${two(local.hour)}:${two(local.minute)}';
}
