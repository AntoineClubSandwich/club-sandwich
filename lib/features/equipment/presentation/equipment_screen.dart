import 'package:club_sandwich/design_system/components/buttons/ds_primary_button.dart';
import 'package:club_sandwich/design_system/components/indicators/ds_badge.dart';
import 'package:club_sandwich/design_system/components/indicators/ds_semantic_variant.dart';
import 'package:club_sandwich/design_system/components/surfaces/ds_card.dart';
import 'package:club_sandwich/design_system/tokens/ds_spacing.dart';
import 'package:club_sandwich/design_system/tokens/ds_theme.dart';
import 'package:club_sandwich/design_system/tokens/ds_typography.dart';
import 'package:club_sandwich/features/equipment/data/equipment_providers.dart';
import 'package:club_sandwich/features/equipment/domain/equipment_asset.dart';
import 'package:club_sandwich/features/stock/presentation/stock_location_dialog.dart';
import 'package:club_sandwich/shared/utils/error_messages.dart';
import 'package:club_sandwich/shared/widgets/app_state_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class EquipmentScreen extends ConsumerStatefulWidget {
  const EquipmentScreen({this.embedded = false, super.key});

  final bool embedded;

  @override
  ConsumerState<EquipmentScreen> createState() => _EquipmentScreenState();
}

class _EquipmentScreenState extends ConsumerState<EquipmentScreen> {
  var _query = '';
  EquipmentStatus? _status;

  @override
  Widget build(BuildContext context) {
    final asyncAssets = ref.watch(equipmentAssetsProvider);
    final content = asyncAssets.when(
      loading: () => const AppLoadingState(label: 'Chargement du matériel'),
      error: (error, _) => AppErrorState(
        message: describeError(error, 'Impossible de charger le matériel.'),
        onRetry: () => ref.invalidate(equipmentAssetsProvider),
      ),
      data: (assets) {
        final query = _query.trim().toLowerCase();
        final filtered = assets
            .where((asset) {
              if (_status != null && asset.status != _status) return false;
              return query.isEmpty ||
                  asset.name.toLowerCase().contains(query) ||
                  asset.category.toLowerCase().contains(query) ||
                  (asset.internalCode?.toLowerCase().contains(query) ?? false);
            })
            .toList(growable: false);
        return ListView(
          padding: const EdgeInsets.all(DsSpacing.xl),
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: DsSpacing.lg,
              runSpacing: DsSpacing.md,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Parc matériel', style: DsTypography.h1),
                    Text(
                      '${assets.length} équipement${assets.length > 1 ? 's' : ''} · ${assets.where((asset) => asset.status == EquipmentStatus.available).length} disponible${assets.length > 1 ? 's' : ''}',
                    ),
                  ],
                ),
                Wrap(
                  spacing: DsSpacing.sm,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _openLocationEditor,
                      icon: const Icon(Icons.place_outlined),
                      label: const Text('Nouvel emplacement'),
                    ),
                    DsPrimaryButton(
                      label: 'Nouveau matériel',
                      icon: Icons.add,
                      onPressed: () => _openEditor(),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: DsSpacing.lg),
            Wrap(
              spacing: DsSpacing.md,
              runSpacing: DsSpacing.md,
              children: [
                SizedBox(
                  width: 320,
                  child: TextField(
                    onChanged: (value) => setState(() => _query = value),
                    decoration: const InputDecoration(
                      hintText: 'Rechercher du matériel',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
                SizedBox(
                  width: 240,
                  child: DropdownButtonFormField<EquipmentStatus?>(
                    isExpanded: true,
                    initialValue: _status,
                    decoration: const InputDecoration(labelText: 'Statut'),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Tous les statuts'),
                      ),
                      for (final status in EquipmentStatus.values)
                        DropdownMenuItem(
                          value: status,
                          child: Text(status.label),
                        ),
                    ],
                    onChanged: (value) => setState(() => _status = value),
                  ),
                ),
              ],
            ),
            const SizedBox(height: DsSpacing.lg),
            if (filtered.isEmpty)
              const AppEmptyState(
                title: 'Aucun matériel',
                message: 'Ajoutez du matériel ou modifiez les filtres.',
                icon: Icons.inventory_2_outlined,
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
                      for (final asset in filtered)
                        SizedBox(
                          width: width,
                          child: _EquipmentCard(
                            asset: asset,
                            onEdit: () => _openEditor(asset),
                            onHistory: () => _openHistory(asset),
                            onArchive: () => _archive(asset),
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

  Future<void> _openEditor([EquipmentAsset? asset]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => _EquipmentEditor(asset: asset),
    );
    if (saved == true) ref.invalidate(equipmentAssetsProvider);
  }

  Future<void> _openLocationEditor() async {
    await showCreateStockLocationDialog(context, ref);
  }

  Future<void> _openHistory(EquipmentAsset asset) => showDialog<void>(
    context: context,
    builder: (context) => _EquipmentHistoryDialog(asset: asset),
  );

  Future<void> _archive(EquipmentAsset asset) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archiver ce matériel ?'),
        content: Text(
          '${asset.name} sera retiré du parc actif. Son historique sera conservé.',
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
    await ref.read(equipmentRepositoryProvider).archive(asset.id);
    ref.invalidate(equipmentAssetsProvider);
  }
}

class _EquipmentCard extends StatelessWidget {
  const _EquipmentCard({
    required this.asset,
    required this.onEdit,
    required this.onHistory,
    required this.onArchive,
  });

  final EquipmentAsset asset;
  final VoidCallback onEdit;
  final VoidCallback onHistory;
  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) {
    final variant = switch (asset.status) {
      EquipmentStatus.available => DsSemanticVariant.success,
      EquipmentStatus.assigned ||
      EquipmentStatus.inUse => DsSemanticVariant.info,
      EquipmentStatus.needsCheck ||
      EquipmentStatus.needsCleaning => DsSemanticVariant.warning,
      EquipmentStatus.damaged ||
      EquipmentStatus.lost ||
      EquipmentStatus.outOfService => DsSemanticVariant.error,
    };
    return DsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(asset.name, style: DsTypography.h3)),
              DsBadge(label: asset.status.label, variant: variant),
              PopupMenuButton<String>(
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
          Text(
            '${asset.category} · ${asset.quantityTotal} unité${asset.quantityTotal > 1 ? 's' : ''}',
          ),
          const SizedBox(height: DsSpacing.sm),
          Text('Emplacement : ${asset.locationName ?? 'Non renseigné'}'),
          if (asset.internalCode != null)
            Text('Référence : ${asset.internalCode}'),
          if (asset.condition != null) Text('État : ${asset.condition}'),
        ],
      ),
    );
  }
}

class _EquipmentEditor extends ConsumerStatefulWidget {
  const _EquipmentEditor({this.asset});
  final EquipmentAsset? asset;

  @override
  ConsumerState<_EquipmentEditor> createState() => _EquipmentEditorState();
}

class _EquipmentEditorState extends ConsumerState<_EquipmentEditor> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.asset?.name);
  late final _category = TextEditingController(text: widget.asset?.category);
  late final _code = TextEditingController(text: widget.asset?.internalCode);
  late final _quantity = TextEditingController(
    text: '${widget.asset?.quantityTotal ?? 1}',
  );
  late final _condition = TextEditingController(text: widget.asset?.condition);
  late final _notes = TextEditingController(text: widget.asset?.notes);
  late var _status = widget.asset?.status ?? EquipmentStatus.available;
  late String? _locationId = widget.asset?.locationId;
  var _saving = false;

  @override
  void dispose() {
    for (final controller in [
      _name,
      _category,
      _code,
      _quantity,
      _condition,
      _notes,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final repository = ref.read(equipmentRepositoryProvider);
      final arguments = (
        name: _name.text,
        category: _category.text,
        quantity: int.parse(_quantity.text),
      );
      if (widget.asset == null) {
        await repository.create(
          name: arguments.name,
          category: arguments.category,
          quantityTotal: arguments.quantity,
          status: _status,
          internalCode: _code.text,
          locationId: _locationId,
          condition: _condition.text,
          notes: _notes.text,
        );
      } else {
        await repository.update(
          widget.asset!.id,
          name: arguments.name,
          category: arguments.category,
          quantityTotal: arguments.quantity,
          status: _status,
          internalCode: _code.text,
          locationId: _locationId,
          condition: _condition.text,
          notes: _notes.text,
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
    final locations =
        ref.watch(equipmentLocationsProvider).value ??
        const <EquipmentLocation>[];
    return AlertDialog(
      title: Text(
        widget.asset == null ? 'Nouveau matériel' : 'Modifier le matériel',
      ),
      content: SizedBox(
        width: 560,
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
                TextFormField(
                  controller: _code,
                  decoration: const InputDecoration(
                    labelText: 'Identifiant interne (optionnel)',
                  ),
                ),
                const SizedBox(height: DsSpacing.md),
                TextFormField(
                  controller: _quantity,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Quantité totale',
                  ),
                  validator: (value) => (int.tryParse(value ?? '') ?? 0) <= 0
                      ? 'Saisissez une quantité supérieure à zéro'
                      : null,
                ),
                const SizedBox(height: DsSpacing.md),
                DropdownButtonFormField<EquipmentStatus>(
                  initialValue: _status,
                  decoration: const InputDecoration(labelText: 'Statut'),
                  items: [
                    for (final status in EquipmentStatus.values)
                      DropdownMenuItem(
                        value: status,
                        child: Text(status.label),
                      ),
                  ],
                  onChanged: (value) =>
                      setState(() => _status = value ?? _status),
                ),
                const SizedBox(height: DsSpacing.md),
                DropdownButtonFormField<String?>(
                  initialValue: _locationId,
                  decoration: const InputDecoration(labelText: 'Emplacement'),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Non renseigné'),
                    ),
                    for (final location in locations)
                      DropdownMenuItem(
                        value: location.id,
                        child: Text(location.name),
                      ),
                  ],
                  onChanged: (value) => setState(() => _locationId = value),
                ),
                const SizedBox(height: DsSpacing.md),
                TextFormField(
                  controller: _condition,
                  decoration: const InputDecoration(
                    labelText: 'État (optionnel)',
                  ),
                ),
                const SizedBox(height: DsSpacing.md),
                TextFormField(
                  controller: _notes,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optionnelles)',
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
}

class _EquipmentHistoryDialog extends ConsumerWidget {
  const _EquipmentHistoryDialog({required this.asset});
  final EquipmentAsset asset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(equipmentEventsProvider(asset.id));
    return AlertDialog(
      title: Text('Historique · ${asset.name}'),
      content: SizedBox(
        width: 620,
        height: 420,
        child: events.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Text(describeError(error, 'Historique indisponible.')),
          ),
          data: (items) => items.isEmpty
              ? const Center(child: Text('Aucun événement.'))
              : ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const Divider(),
                  itemBuilder: (context, index) {
                    final event = items[index];
                    return ListTile(
                      title: Text(_eventLabel(event.eventType)),
                      subtitle: Text(
                        '${event.actorName ?? 'Auteur inconnu'}${event.note == null ? '' : '\n${event.note}'}',
                      ),
                      trailing: Text(
                        _dateTime(event.createdAt),
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
String _eventLabel(String value) => switch (value) {
  'assignment' => 'Affectation',
  'checkout' => 'Sortie',
  'return' => 'Retour',
  'status_change' => 'Changement d’état',
  'move' => 'Déplacement',
  'incident' => 'Incident',
  _ => 'Événement',
};
String _dateTime(DateTime value) {
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year}\n'
      '${two(local.hour)}:${two(local.minute)}';
}
