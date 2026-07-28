import 'dart:async';

import 'package:club_sandwich/features/concerts/domain/concert.dart';
import 'package:club_sandwich/features/organizations/domain/organization.dart';
import 'package:club_sandwich/features/venues/data/venue_providers.dart';
import 'package:club_sandwich/features/venues/domain/venue.dart';
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
  final Future<void> Function(ConcertDraft draft) onSubmit;

  bool get isEditing => initialConcert != null;

  @override
  ConsumerState<ConcertForm> createState() => _ConcertFormState();
}

class _ConcertFormState extends ConsumerState<ConcertForm> {
  final _formKey = GlobalKey<FormState>();
  final _venueFieldKey = GlobalKey<FormFieldState<Venue>>();
  late final TextEditingController _artistController;
  late final TextEditingController _venueController;
  late final TextEditingController _notesController;
  late final TextEditingController _promoterContactNameController;
  late final TextEditingController _promoterContactPhoneController;
  late final TextEditingController _cateringContactNameController;
  late final TextEditingController _cateringContactPhoneController;
  late final TextEditingController _cateringContactEmailController;
  Timer? _searchDebounce;
  late DateTime _date;
  TimeOfDay? _cateringClosesAt;
  Venue? _selectedVenue;
  String? _promoterOrganizationId;
  List<Venue> _venueResults = const [];
  bool _isSearchingVenues = false;
  bool _isSubmitting = false;
  String? _venueSearchError;

  @override
  void initState() {
    super.initState();
    final concert = widget.initialConcert;
    _artistController = TextEditingController(text: concert?.artist);
    _venueController = TextEditingController(text: concert?.venueName);
    _notesController = TextEditingController(text: concert?.notes);
    _promoterContactNameController = TextEditingController(
      text: concert?.promoterContactName,
    );
    _promoterContactPhoneController = TextEditingController(
      text: concert?.promoterContactPhone,
    );
    _cateringContactNameController = TextEditingController(
      text: concert?.cateringContactName,
    );
    _cateringContactPhoneController = TextEditingController(
      text: concert?.cateringContactPhone,
    );
    _cateringContactEmailController = TextEditingController(
      text: concert?.cateringContactEmail,
    );
    _date = concert?.date ?? DateTime.now();
    _cateringClosesAt = _optionalTimeFromDatabase(concert?.cateringClosesAt);
    _selectedVenue = concert?.venue;
    _promoterOrganizationId = concert?.promoterOrganizationId;
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _artistController.dispose();
    _venueController.dispose();
    _notesController.dispose();
    _promoterContactNameController.dispose();
    _promoterContactPhoneController.dispose();
    _cateringContactNameController.dispose();
    _cateringContactPhoneController.dispose();
    _cateringContactEmailController.dispose();
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
                _VenueField(
                  fieldKey: _venueFieldKey,
                  controller: _venueController,
                  selectedVenue: _selectedVenue,
                  results: _venueResults,
                  isSearching: _isSearchingVenues,
                  searchError: _venueSearchError,
                  onChanged: _onVenueChanged,
                  onSelected: _selectVenue,
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
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),
                _ContactFields(
                  fieldKeyPrefix: 'catering-contact',
                  title: 'Contact catering',
                  nameController: _cateringContactNameController,
                  phoneController: _cateringContactPhoneController,
                  emailController: _cateringContactEmailController,
                ),
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
                      : 'Ouvrir la maraude',
                ),
        ),
      ],
    );
  }

  void _onVenueChanged(String value) {
    if (_selectedVenue?.name != value) {
      _selectedVenue = null;
      _venueFieldKey.currentState?.didChange(null);
    }
    _scheduleVenueSearch(value);
    setState(() {});
  }

  void _selectVenue(Venue venue) {
    _searchDebounce?.cancel();
    setState(() {
      _selectedVenue = venue;
      _venueController.text = venue.name;
      _venueResults = const [];
      _venueSearchError = null;
    });
    _venueFieldKey.currentState?.didChange(venue);
  }

  void _scheduleVenueSearch(String query) {
    _searchDebounce?.cancel();
    final normalizedQuery = query.trim();
    if (normalizedQuery.length < 2) {
      setState(() {
        _venueResults = const [];
        _venueSearchError = null;
        _isSearchingVenues = false;
      });
      return;
    }
    _searchDebounce = Timer(
      const Duration(milliseconds: 250),
      () => _searchVenues(normalizedQuery),
    );
  }

  Future<void> _searchVenues(String query) async {
    setState(() {
      _isSearchingVenues = true;
      _venueSearchError = null;
    });
    try {
      final results = await ref
          .read(venueRepositoryProvider)
          .searchActiveVenues(query);
      if (!mounted ||
          _selectedVenue != null ||
          _venueController.text.trim() != query) {
        return;
      }
      setState(() => _venueResults = results);
    } on Exception {
      if (!mounted || _venueController.text.trim() != query) return;
      setState(() {
        _venueResults = const [];
        _venueSearchError = 'Impossible de rechercher les salles.';
      });
    } finally {
      if (mounted && _venueController.text.trim() == query) {
        setState(() => _isSearchingVenues = false);
      }
    }
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

    setState(() => _isSubmitting = true);
    try {
      await widget.onSubmit(
        ConcertDraft(
          artist: _artistController.text.trim(),
          date: _date,
          venueId: venue.id,
          promoterOrganizationId: _promoterOrganizationId,
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
          cateringContactName: _optionalValue(
            _cateringContactNameController.text,
          ),
          cateringContactPhone: _optionalValue(
            _cateringContactPhoneController.text,
          ),
          cateringContactEmail: _optionalValue(
            _cateringContactEmailController.text,
          ),
        ),
      );
      if (mounted) Navigator.of(context).pop(true);
    } on Exception {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isEditing
                ? 'Impossible d’enregistrer les modifications.'
                : 'Impossible d’ouvrir la maraude.',
          ),
        ),
      );
    }
  }
}

class _VenueField extends StatelessWidget {
  const _VenueField({
    required this.fieldKey,
    required this.controller,
    required this.selectedVenue,
    required this.results,
    required this.isSearching,
    required this.searchError,
    required this.onChanged,
    required this.onSelected,
  });

  final GlobalKey<FormFieldState<Venue>> fieldKey;
  final TextEditingController controller;
  final Venue? selectedVenue;
  final List<Venue> results;
  final bool isSearching;
  final String? searchError;
  final ValueChanged<String> onChanged;
  final ValueChanged<Venue> onSelected;

  @override
  Widget build(BuildContext context) {
    return FormField<Venue>(
      key: fieldKey,
      initialValue: selectedVenue,
      validator: (value) => value == null ? 'Ce champ est requis.' : null,
      builder: (field) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            key: const ValueKey('concert-venue-field'),
            controller: controller,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'Salle',
              hintText: 'Saisissez au moins 2 caractères',
              errorText: field.errorText,
              suffixIcon: isSearching
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : const Icon(Icons.search),
            ),
            onChanged: onChanged,
          ),
          if (searchError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                searchError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (results.isNotEmpty)
            Card(
              margin: const EdgeInsets.only(top: 4),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 240),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: results.length,
                  itemBuilder: (context, index) {
                    final venue = results[index];
                    return ListTile(
                      dense: true,
                      title: Text(venue.name),
                      subtitle: Text(venue.formattedAddress),
                      onTap: () => onSelected(venue),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
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
    this.emailController,
  });

  final String fieldKeyPrefix;
  final String title;
  final String? helper;
  final String nameLabel;
  final TextEditingController nameController;
  final TextEditingController phoneController;
  final TextEditingController? emailController;

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
        if (emailController != null) ...[
          const SizedBox(height: 12),
          TextFormField(
            key: ValueKey('$fieldKeyPrefix-email'),
            controller: emailController,
            decoration: const InputDecoration(labelText: 'E-mail'),
            keyboardType: TextInputType.emailAddress,
            validator: _validateOptionalEmail,
            textInputAction: TextInputAction.next,
          ),
        ],
      ],
    );
  }
}

String? _requiredValidator(String? value) {
  return value == null || value.trim().isEmpty ? 'Ce champ est requis.' : null;
}

String? _validateOptionalEmail(String? value) {
  final normalized = value?.trim() ?? '';
  if (normalized.isEmpty) return null;
  final atIndex = normalized.indexOf('@');
  final dotIndex = normalized.lastIndexOf('.');
  if (atIndex <= 0 ||
      dotIndex <= atIndex + 1 ||
      dotIndex == normalized.length - 1) {
    return 'Saisissez une adresse e-mail valide.';
  }
  return null;
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
