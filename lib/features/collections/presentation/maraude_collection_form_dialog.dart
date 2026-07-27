import 'package:club_sandwich/features/collections/domain/maraude_collection.dart';
import 'package:flutter/material.dart';

class MaraudeCollectionFormDialog extends StatefulWidget {
  const MaraudeCollectionFormDialog({
    required this.onSubmit,
    this.initialCollection,
    super.key,
  });

  final MaraudeCollection? initialCollection;
  final Future<void> Function(MaraudeCollectionDraft draft) onSubmit;

  bool get isEditing => initialCollection != null;

  @override
  State<MaraudeCollectionFormDialog> createState() =>
      _MaraudeCollectionFormDialogState();
}

class _MaraudeCollectionFormDialogState
    extends State<MaraudeCollectionFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _descriptionController;
  late final TextEditingController _quantityController;
  late final TextEditingController _weightController;
  late final TextEditingController _commentController;
  late CollectionCategory _category;
  late CollectionUnit _unit;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final collection = widget.initialCollection;
    _category = collection?.category ?? CollectionCategory.preparedMeals;
    _unit = collection?.unit ?? CollectionUnit.piece;
    _descriptionController = TextEditingController(
      text: collection?.description ?? '',
    );
    _quantityController = TextEditingController(
      text: collection == null
          ? ''
          : formatCollectionNumber(collection.quantity),
    );
    _weightController = TextEditingController(
      text: collection?.weightKg == null
          ? ''
          : formatCollectionNumber(collection!.weightKg!),
    );
    _commentController = TextEditingController(text: collection?.comment ?? '');
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _quantityController.dispose();
    _weightController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.isEditing ? 'Modifier le lot' : 'Ajouter un lot',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Fermer',
                      onPressed: _isSubmitting
                          ? null
                          : () => Navigator.of(context).pop(false),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<CollectionCategory>(
                  initialValue: _category,
                  decoration: const InputDecoration(labelText: 'Catégorie'),
                  items: [
                    for (final category in CollectionCategory.values)
                      DropdownMenuItem(
                        value: category,
                        child: Text(category.label),
                      ),
                  ],
                  onChanged: _isSubmitting
                      ? null
                      : (category) {
                          if (category != null) _category = category;
                        },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  enabled: !_isSubmitting,
                  autofocus: true,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'Optionnelle',
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _quantityController,
                  enabled: !_isSubmitting,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Quantité'),
                  validator: (value) {
                    final quantity = _parseNumber(value);
                    if (quantity == null) return 'La quantité est obligatoire.';
                    if (quantity <= 0) {
                      return 'La quantité doit être supérieure à zéro.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<CollectionUnit>(
                  initialValue: _unit,
                  decoration: const InputDecoration(labelText: 'Unité'),
                  items: [
                    for (final unit in CollectionUnit.values)
                      DropdownMenuItem(value: unit, child: Text(unit.label)),
                  ],
                  onChanged: _isSubmitting
                      ? null
                      : (unit) {
                          if (unit != null) _unit = unit;
                        },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _weightController,
                  enabled: !_isSubmitting,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Poids (kg)',
                    hintText: 'Optionnel',
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) return null;
                    final weight = _parseNumber(text);
                    if (weight == null || weight < 0) {
                      return 'Le poids doit être positif ou nul.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _commentController,
                  enabled: !_isSubmitting,
                  maxLines: 3,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  decoration: const InputDecoration(
                    labelText: 'Commentaire',
                    hintText: 'Optionnel',
                  ),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
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
                          : Text(
                              widget.isEditing
                                  ? 'Enregistrer les modifications'
                                  : 'Ajouter le lot',
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await widget.onSubmit(
        MaraudeCollectionDraft(
          category: _category,
          description: _descriptionController.text,
          quantity: _parseNumber(_quantityController.text)!,
          unit: _unit,
          weightKg: _parseNumber(_weightController.text),
          comment: _commentController.text,
        ),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = widget.isEditing
            ? 'Impossible d’enregistrer les modifications.'
            : 'Impossible d’ajouter ce lot.';
      });
    }
  }
}

double? _parseNumber(String? value) {
  final normalized = value?.trim().replaceAll(',', '.') ?? '';
  return normalized.isEmpty ? null : double.tryParse(normalized);
}

String formatCollectionNumber(double value) {
  return value == value.roundToDouble()
      ? value.toInt().toString()
      : value
            .toStringAsFixed(2)
            .replaceFirst(RegExp(r'0+$'), '')
            .replaceFirst(RegExp(r'\.$'), '');
}
