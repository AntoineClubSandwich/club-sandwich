import 'package:club_sandwich/features/equipment/data/equipment_providers.dart';
import 'package:club_sandwich/features/equipment/domain/equipment_asset.dart';
import 'package:club_sandwich/shared/utils/error_messages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<EquipmentLocation?> showCreateStockLocationDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final controller = TextEditingController();
  final name = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Nouvel emplacement'),
      content: TextField(
        controller: controller,
        autofocus: true,
        textInputAction: TextInputAction.done,
        decoration: const InputDecoration(labelText: 'Nom'),
        onSubmitted: (value) {
          final trimmed = value.trim();
          if (trimmed.isNotEmpty) Navigator.pop(context, trimmed);
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () {
            final trimmed = controller.text.trim();
            if (trimmed.isNotEmpty) Navigator.pop(context, trimmed);
          },
          child: const Text('Créer'),
        ),
      ],
    ),
  );
  controller.dispose();
  if (name == null) return null;

  try {
    final location = await ref
        .read(equipmentRepositoryProvider)
        .createLocation(name);
    ref.invalidate(equipmentLocationsProvider);
    return location;
  } catch (error) {
    if (!context.mounted) return null;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          describeError(error, 'Impossible de créer cet emplacement.'),
        ),
      ),
    );
    return null;
  }
}
