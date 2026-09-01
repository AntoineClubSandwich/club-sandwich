import 'package:club_sandwich/features/concerts/domain/concert.dart';
import 'package:club_sandwich/features/organizations/domain/organization.dart';
import 'package:club_sandwich/features/venues/domain/venue.dart';
import 'package:club_sandwich/features/venues/presentation/venue_search_field.dart';
import 'package:club_sandwich/shared/utils/error_messages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ConcertForm extends ConsumerStatefulWidget {
  const ConcertForm({
    required this.onSubmit,
    this.initialConcert,
    this.promoterOrganizations = const [],
    super.key,
  });

  final Concert? initialConcert;
  final List<Organization> promoterOrganizations;
  final Future<void> Function(ConcertDraft draft, {required bool asDraft})
  onSubmit;

  bool get isEditing => initialConcert != null;

  @override
  ConsumerState<ConcertForm> createState() => _ConcertFormState();
}

class _ConcertFormState extends ConsumerState<ConcertForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _artistController;
  late final TextEditingController _notesController;
  late final TextEditingController _cateringContactNameController;
  late final TextEditingController _promoterContactNameController;
  late final TextEditingController _promoterContactPhoneController;
  late DateTime _date;
  TimeOfDay? _cateringClosesAt;
  Venue? _selectedVenue;
  String? _promoterOrganizationId;
  bool _isSubmitting = false;
  bool _saveAsDraft = false;

  @override
  void initState() {
    super.initState();
    final concert = widget.initialConcert;
    _artistController = TextEditingController(text: concert?.artist);
    _notesController = TextEditingController(text: concert?.notes);
    _cateringContactNameController = TextEditingController(
      text: concert?.cateringContactName,
    );
    _promoterContactNameController = TextEditingController(
      text: concert?.promoterContactName,
    );
    _promoterContactPhoneController = TextEditingController(
      text: concert?.promoterContactPhone,
    );
    _date = concert?.date ?? DateTime.now();
    _cateringClosesAt = _optionalTimeFromDatabase(concert?.cateringClosesAt);
    _selectedVenue = concert?.venue;
    _promoterOrganizationId = concert?.promoterOrganizationId;
  }

  @override
  void dispose() {
    _artistController.dispose();
    _notesController.dispose();
    _cateringContactNameController.dispose();
    _promoterContactNameController.dispose();
    _promoterContactPhoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Expanded(
            child: Text(
              widget.isEditing ? 'Modifier la maraude' : 'Nouvelle maraude',
            ),
          ),
          IconButton(
            tooltip: 'Fermer',
            onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      content: SizedBox(
        width: 580,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  key: const ValueKey('concert-artist-field'),
                  controller: _artistController,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Artiste'),
                  validator: _requiredValidator,
                  textInputAction: TextInputAction.next,
                ),
                if (widget.promoterOrganizations.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    key: const ValueKey('concert-promoter-organization-field'),
                    initialValue: _promoterOrganizationId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Organisation tourneur',
                      helperText:
                          'La maraude sera visible par les comptes de cette '
                          'organisation.',
                    ),
                    items: [
                      for (final organization in widget.promoterOrganizations)
                        DropdownMenuItem(
                          value: organization.id,
                          child: Text(
                            organization.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    validator: (value) =>
                        value == null ? 'Ce champ est requis.' : null,
                    onChanged: _isSubmitting
                        ? null
                        : (value) =>
                              setState(() => _promoterOrganizationId = value),
                  ),
                ],
                const SizedBox(height: 16),
                VenueSearchField(
                  inputKey: const ValueKey('concert-venue-field'),
                  initialVenue: _selectedVenue,
                  onChanged: (venue) => setState(() => _selectedVenue = venue),
                ),
                if (_selectedVenue != null) ...[
                  const SizedBox(height: 12),
                  _ReadOnlyInformation(
                    label: 'Entrée artistes',
                    value:
                        _selectedVenue!.formattedArtistEntrance ??
                        'Non renseignée pour cette salle',
                    helper: _selectedVenue!.accessInstructions,
                  ),
                ],
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  key: const ValueKey('concert-date-field'),
                  onPressed: _selectDate,
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(_formatDate(_date)),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const ValueKey('concert-catering-name-field'),
                  controller: _cateringContactNameController,
                  decoration: const InputDecoration(
                    labelText: 'Nom du catering (optionnel)',
                  ),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                Text(
                  'Fermeture du catering '
                  '(à renseigner quand transmise par le catering)',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  key: const ValueKey('catering-closes-field'),
                  onPressed: _selectCateringTime,
                  icon: const Icon(Icons.schedule_outlined),
                  label: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _cateringClosesAt == null
                          ? 'Choisir une heure'
                          : _displayTime(_cateringClosesAt!),
                    ),
                  ),
                ),
                if (_cateringClosesAt != null) ...[
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => setState(() => _cateringClosesAt = null),
                      child: const Text('Effacer l’heure'),
                    ),
                  ),
                  Text(
                    'Arrivée recommandée : '
                    '${_displayTime(_recommendedArrival(_cateringClosesAt!))}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 16),
                _ContactFields(
                  fieldKeyPrefix: 'promoter-contact',
                  title: 'Contact tourneur',
                  helper:
                      'Personne à contacter pour toute question relative à '
                      'cette maraude.',
                  nameLabel: 'Nom et prénom',
                  nameController: _promoterContactNameController,
                  phoneController: _promoterContactPhoneController,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const ValueKey('concert-notes-field'),
                  controller: _notesController,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optionnel)',
                    hintText:
                        'Ex. : Accès, code porte, consignes particulières, '
                        'etc.',
                  ),
                  minLines: 3,
                  maxLines: 3,
                ),
                if (!widget.isEditing) ...[
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    key: const ValueKey('concert-save-as-draft-checkbox'),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: _saveAsDraft,
                    onChanged: (value) =>
                        setState(() => _saveAsDraft = value ?? false),
                    title: const Text('Enregistrer comme brouillon'),
                    subtitle: const Text(
                      'Non visible des bénévoles tant qu’elle n’est pas '
                      'publiée.',
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          key: const ValueKey('concert-submit-button'),
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  widget.isEditing
                      ? 'Enregistrer les modifications'
                      : _saveAsDraft
                      ? 'Enregistrer comme brouillon'
                      : 'Ouvrir la maraude',
                ),
        ),
      ],
    );
  }

  Future<void> _selectDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (selected != null) setState(() => _date = selected);
  }

  Future<void> _selectCateringTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: _cateringClosesAt ?? TimeOfDay.now(),
    );
    if (selected != null) setState(() => _cateringClosesAt = selected);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final venue = _selectedVenue;
    if (venue == null) {
      setState(() {});
      return;
    }

    final initial = widget.initialConcert;
    if (initial != null &&
        initial.selectedVolunteerCount > 0 &&
        !_isSameDate(_date, initial.date)) {
      final confirmed = await _confirmDateChangeResetsTeam(
        initial.selectedVolunteerCount,
      );
      if (!confirmed) return;
    }

    setState(() => _isSubmitting = true);
    try {
      await widget.onSubmit(
        ConcertDraft(
          artist: _artistController.text.trim(),
          date: _date,
          venueId: venue.id,
          promoterOrganizationId: _promoterOrganizationId,
          cateringContactName: _optionalValue(
            _cateringContactNameController.text,
          ),
          cateringClosesAt: _cateringClosesAt == null
              ? null
              : _timeToDatabase(_cateringClosesAt!),
          notes: _optionalValue(_notesController.text),
          promoterContactName: _optionalValue(
            _promoterContactNameController.text,
          ),
          promoterContactPhone: _optionalValue(
            _promoterContactPhoneController.text,
          ),
        ),
        asDraft: _saveAsDraft,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            describeError(
              error,
              widget.isEditing
                  ? 'Impossible d’enregistrer les modifications.'
                  : 'Impossible d’ouvrir la maraude.',
            ),
          ),
        ),
      );
    }
  }

  bool _isSameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Future<bool> _confirmDateChangeResetsTeam(int selectedCount) async {
    final label = selectedCount == 1
        ? '1 bénévole est déjà positionné'
        : '$selectedCount bénévoles sont déjà positionnés';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Changer la date de la maraude ?'),
        content: Text(
          '$label sur cette maraude. Changer la date les fera repasser '
          'en attente de sélection : il faudra reconstituer l’équipe '
          'pour la nouvelle date.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Changer la date quand même'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }
}

class _ReadOnlyInformation extends StatelessWidget {
  const _ReadOnlyInformation({
    required this.label,
    required this.value,
    this.helper,
  });

  final String label;
  final String value;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      readOnly: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 4),
              Text(value),
              if (helper != null && helper!.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(helper!, style: Theme.of(context).textTheme.bodySmall),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ContactFields extends StatelessWidget {
  const _ContactFields({
    required this.fieldKeyPrefix,
    required this.title,
    required this.nameController,
    required this.phoneController,
    this.helper,
    this.nameLabel = 'Nom',
  });

  final String fieldKeyPrefix;
  final String title;
  final String? helper;
  final String nameLabel;
  final TextEditingController nameController;
  final TextEditingController phoneController;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.labelLarge),
        if (helper != null) ...[
          const SizedBox(height: 4),
          Text(helper!, style: Theme.of(context).textTheme.bodySmall),
        ],
        const SizedBox(height: 12),
        TextFormField(
          key: ValueKey('$fieldKeyPrefix-name'),
          controller: nameController,
          decoration: InputDecoration(labelText: nameLabel),
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 12),
        TextFormField(
          key: ValueKey('$fieldKeyPrefix-phone'),
          controller: phoneController,
          decoration: const InputDecoration(labelText: 'Téléphone'),
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
        ),
      ],
    );
  }
}

String? _requiredValidator(String? value) {
  return value == null || value.trim().isEmpty ? 'Ce champ est requis.' : null;
}

String? _optionalValue(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String _formatDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';
}

String _timeToDatabase(TimeOfDay value) {
  return '${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}:00';
}

String _displayTime(TimeOfDay value) {
  return '${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}';
}

TimeOfDay? _optionalTimeFromDatabase(String? value) {
  if (value == null) return null;
  final parts = value.split(':');
  return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
}

TimeOfDay _recommendedArrival(TimeOfDay cateringClosesAt) {
  final totalMinutes =
      (cateringClosesAt.hour * 60 + cateringClosesAt.minute - 15) % (24 * 60);
  return TimeOfDay(hour: totalMinutes ~/ 60, minute: totalMinutes % 60);
}
