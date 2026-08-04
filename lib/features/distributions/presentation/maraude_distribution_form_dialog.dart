import 'package:club_sandwich/features/concerts/presentation/concert_formatters.dart';
import 'package:club_sandwich/features/distributions/domain/maraude_distribution.dart';
import 'package:club_sandwich/shared/utils/error_messages.dart';
import 'package:flutter/material.dart';

class MaraudeDistributionFormDialog extends StatefulWidget {
  const MaraudeDistributionFormDialog({
    required this.onSubmit,
    this.initialDistribution,
    super.key,
  });

  final MaraudeDistribution? initialDistribution;
  final Future<void> Function(MaraudeDistributionDraft draft) onSubmit;

  bool get isEditing => initialDistribution != null;

  @override
  State<MaraudeDistributionFormDialog> createState() =>
      _MaraudeDistributionFormDialogState();
}

class _MaraudeDistributionFormDialogState
    extends State<MaraudeDistributionFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _locationController;
  late final TextEditingController _beneficiariesController;
  late final TextEditingController _mealsController;
  late final TextEditingController _remainingWeightController;
  late final TextEditingController _incidentController;
  DateTime? _startedAt;
  DateTime? _completedAt;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final distribution = widget.initialDistribution;
    _locationController = TextEditingController(
      text: distribution?.distributionLocation ?? '',
    );
    _beneficiariesController = TextEditingController(
      text: distribution?.estimatedBeneficiaries?.toString() ?? '',
    );
    _mealsController = TextEditingController(
      text: distribution?.distributedMeals?.toString() ?? '',
    );
    _remainingWeightController = TextEditingController(
      text: distribution?.remainingWeightKg == null
          ? ''
          : formatDistributionNumber(distribution!.remainingWeightKg!),
    );
    _incidentController = TextEditingController(
      text: distribution?.incidentComment ?? '',
    );
    _startedAt = distribution?.distributionStartedAt;
    _completedAt = distribution?.distributionCompletedAt;
  }

  @override
  void dispose() {
    _locationController.dispose();
    _beneficiariesController.dispose();
    _mealsController.dispose();
    _remainingWeightController.dispose();
    _incidentController.dispose();
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
                        widget.isEditing
                            ? 'Modifier la distribution'
                            : 'Ajouter la distribution',
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
                TextFormField(
                  controller: _locationController,
                  enabled: !_isSubmitting,
                  autofocus: true,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Lieu de distribution',
                    hintText: 'Optionnel',
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _beneficiariesController,
                  enabled: !_isSubmitting,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Bénéficiaires estimés',
                    hintText: 'Optionnel',
                  ),
                  validator: _validateNonNegativeInteger,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _mealsController,
                  enabled: !_isSubmitting,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Repas distribués',
                    hintText: 'Optionnel',
                  ),
                  validator: _validateNonNegativeInteger,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _remainingWeightController,
                  enabled: !_isSubmitting,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Poids restant (kg)',
                    hintText: 'Optionnel',
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) return null;
                    final weight = _parseDecimal(text);
                    if (weight == null || !weight.isFinite || weight < 0) {
                      return 'Le poids doit être positif ou nul.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _DistributionDateTimeField(
                  label: 'Début de la distribution',
                  value: _startedAt,
                  enabled: !_isSubmitting,
                  onPick: () => _pickDateTime(isStart: true),
                  onClear: () => setState(() => _startedAt = null),
                ),
                const SizedBox(height: 12),
                _DistributionDateTimeField(
                  label: 'Fin de la distribution',
                  value: _completedAt,
                  enabled: !_isSubmitting,
                  onPick: () => _pickDateTime(isStart: false),
                  onClear: () => setState(() => _completedAt = null),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _incidentController,
                  enabled: !_isSubmitting,
                  maxLines: 4,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  decoration: const InputDecoration(
                    labelText: 'Commentaire d’incident',
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
                                  : 'Ajouter la distribution',
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

  Future<void> _pickDateTime({required bool isStart}) async {
    final currentValue = isStart ? _startedAt : _completedAt;
    final initial = currentValue?.toLocal() ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) return;
    final value = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    setState(() {
      if (isStart) {
        _startedAt = value;
      } else {
        _completedAt = value;
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_completedAt != null && _startedAt == null) {
      setState(() {
        _errorMessage = 'Renseignez le début avant la fin de la distribution.';
      });
      return;
    }
    if (_completedAt != null && _completedAt!.isBefore(_startedAt!)) {
      setState(() {
        _errorMessage = 'La fin de la distribution doit suivre son début.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      await widget.onSubmit(
        MaraudeDistributionDraft(
          distributionLocation: _locationController.text,
          estimatedBeneficiaries: _parseInteger(_beneficiariesController.text),
          distributedMeals: _parseInteger(_mealsController.text),
          remainingWeightKg: _parseDecimal(_remainingWeightController.text),
          distributionStartedAt: _startedAt,
          distributionCompletedAt: _completedAt,
          incidentComment: _incidentController.text,
        ),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = describeError(
          error,
          widget.isEditing
              ? 'Impossible d’enregistrer les modifications.'
              : 'Impossible d’ajouter la distribution.',
        );
      });
    }
  }
}

class _DistributionDateTimeField extends StatelessWidget {
  const _DistributionDateTimeField({
    required this.label,
    required this.value,
    required this.enabled,
    required this.onPick,
    required this.onClear,
  });

  final String label;
  final DateTime? value;
  final bool enabled;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(labelText: label),
      child: Row(
        children: [
          Expanded(
            child: Text(
              value == null ? 'Non renseigné' : formatFrenchDateTime(value!),
            ),
          ),
          if (value != null)
            IconButton(
              tooltip: 'Effacer $label',
              onPressed: enabled ? onClear : null,
              icon: const Icon(Icons.clear),
            ),
          TextButton(
            onPressed: enabled ? onPick : null,
            child: Text(value == null ? 'Renseigner' : 'Modifier'),
          ),
        ],
      ),
    );
  }
}

String? _validateNonNegativeInteger(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return null;
  final parsed = int.tryParse(text);
  if (parsed == null || parsed < 0) {
    return 'Saisissez un nombre entier positif ou nul.';
  }
  return null;
}

int? _parseInteger(String value) {
  final text = value.trim();
  return text.isEmpty ? null : int.tryParse(text);
}

double? _parseDecimal(String value) {
  final text = value.trim().replaceAll(',', '.');
  return text.isEmpty ? null : double.tryParse(text);
}

String formatDistributionNumber(double value) {
  return value == value.roundToDouble()
      ? value.toInt().toString()
      : value
            .toStringAsFixed(2)
            .replaceFirst(RegExp(r'0+$'), '')
            .replaceFirst(RegExp(r'\.$'), '');
}
