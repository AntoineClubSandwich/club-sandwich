import 'dart:async';

import 'package:club_sandwich/features/concerts/data/concert_providers.dart';
import 'package:club_sandwich/features/concerts/data/concert_repository.dart';
import 'package:club_sandwich/features/concerts/domain/concert.dart';
import 'package:club_sandwich/features/concerts/presentation/concert_formatters.dart';
import 'package:club_sandwich/features/venues/data/venue_providers.dart';
import 'package:club_sandwich/features/venues/domain/venue.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ConcertsScreen extends ConsumerWidget {
  const ConcertsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final concerts = ref.watch(concertsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: concerts.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _ConcertsError(
          message: _errorMessage(error),
          onRetry: () => ref.invalidate(concertsProvider),
        ),
        data: (items) {
          final sortedItems = _sortForDashboard(items);
          if (items.isEmpty) {
            return _EmptyConcerts(
              onCreate: () => _createConcert(context, ref),
              onRefresh: () => ref.refresh(concertsProvider.future),
            );
          }

          return _ConcertDashboard(
            concerts: sortedItems,
            onRefresh: () => ref.refresh(concertsProvider.future),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createConcert(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Nouveau concert'),
      ),
    );
  }

  Future<void> _createConcert(BuildContext context, WidgetRef ref) async {
    final draft = await showDialog<CreateConcertDraft>(
      context: context,
      builder: (context) => const CreateConcertDialog(),
    );
    if (draft == null || !context.mounted) return;

    try {
      await ref.read(concertRepositoryProvider).createConcert(draft);
      ref.invalidate(concertsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Concert créé.')));
      }
    } on Exception catch (error) {
      if (context.mounted) _showError(context, error);
    }
  }
}

class _ConcertDashboard extends StatelessWidget {
  const _ConcertDashboard({required this.concerts, required this.onRefresh});

  final List<Concert> concerts;
  final RefreshCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 16.0;
        final horizontalPadding = constraints.maxWidth < 600 ? 16.0 : 24.0;
        final availableWidth = constraints.maxWidth - horizontalPadding * 2;
        final cardWidth = availableWidth >= 900
            ? (availableWidth - spacing) / 2
            : availableWidth;

        return RefreshIndicator(
          onRefresh: onRefresh,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              24,
              horizontalPadding,
              96,
            ),
            child: Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                for (final concert in concerts)
                  SizedBox(
                    width: cardWidth,
                    child: _ConcertCard(concert: concert),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _EmptyConcerts extends StatelessWidget {
  const _EmptyConcerts({required this.onCreate, required this.onRefresh});

  final VoidCallback onCreate;
  final RefreshCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 120),
          Icon(
            Icons.music_note_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 20),
          Text(
            'Aucun concert',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Créez votre premier concert.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
          Center(
            child: FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: const Text('Créer un concert'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConcertCard extends ConsumerWidget {
  const _ConcertCard({required this.concert});

  final Concert concert;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go('/concerts/${concert.id}'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 8, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      concert.artist,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  PopupMenuButton<_ConcertAction>(
                    tooltip: 'Actions',
                    onSelected: (action) {
                      switch (action) {
                        case _ConcertAction.edit:
                          _edit(context, ref);
                        case _ConcertAction.delete:
                          _delete(context, ref);
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: _ConcertAction.edit,
                        child: ListTile(
                          leading: Icon(Icons.edit_outlined),
                          title: Text('Modifier'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      PopupMenuItem(
                        value: _ConcertAction.delete,
                        child: ListTile(
                          leading: Icon(Icons.delete_outline),
                          title: Text('Supprimer'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _CardInformation(
                icon: Icons.location_on_outlined,
                text: concert.venueName ?? '—',
              ),
              const SizedBox(height: 8),
              _CardInformation(
                icon: Icons.calendar_today_outlined,
                text: formatLongFrenchDate(concert.date),
              ),
              if (concert.cateringClosesAt != null) ...[
                const SizedBox(height: 8),
                _CardInformation(
                  icon: Icons.schedule_outlined,
                  text:
                      'Catering : ${formatDatabaseTime(concert.cateringClosesAt!)}',
                ),
                const SizedBox(height: 8),
                _CardInformation(
                  icon: Icons.directions_walk_outlined,
                  text:
                      'Arrivée recommandée : '
                      '${recommendedArrivalFromDatabase(concert.cateringClosesAt!)}',
                ),
              ],
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Wrap(
                spacing: 24,
                runSpacing: 8,
                children: [
                  _Metadata(
                    label: 'Producteur',
                    value: concert.promoterOrganizationName ?? '—',
                  ),
                  const _Metadata(label: 'Équipe', value: '0 bénévole'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final updated = await showDialog<bool>(
      context: context,
      builder: (context) => ConcertFormDialog(
        initialConcert: concert,
        onSubmit: (draft) => ref
            .read(concertRepositoryProvider)
            .updateConcert(concert.id, draft),
      ),
    );
    if (updated != true || !context.mounted) return;

    ref.invalidate(concertsProvider);
    ref.invalidate(concertDetailsProvider(concert.id));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Concert modifié.')));
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    await deleteConcertWithConfirmation(context, ref, concert);
  }
}

Future<bool> deleteConcertWithConfirmation(
  BuildContext context,
  WidgetRef ref,
  Concert concert,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Supprimer le concert ?'),
      content: Text(
        'Le concert « ${concert.artist} », ses candidatures, sa collecte, '
        'sa distribution et son bilan seront définitivement supprimés.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Supprimer'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return false;

  try {
    await ref.read(concertRepositoryProvider).deleteConcert(concert.id);
    ref.invalidate(concertsProvider);
    ref.invalidate(concertDetailsProvider(concert.id));
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Concert supprimé.')));
    }
    return true;
  } on Exception catch (error) {
    if (context.mounted) _showError(context, error);
    return false;
  }
}

class _CardInformation extends StatelessWidget {
  const _CardInformation({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    );
  }
}

class _Metadata extends StatelessWidget {
  const _Metadata({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 2),
          Text(value, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

enum _ConcertAction { edit, delete }

class CreateConcertDialog extends ConsumerStatefulWidget {
  const CreateConcertDialog({super.key});

  @override
  ConsumerState<CreateConcertDialog> createState() =>
      _CreateConcertDialogState();
}

class _CreateConcertDialogState extends ConsumerState<CreateConcertDialog> {
  final _formKey = GlobalKey<FormState>();
  final _artistController = TextEditingController();
  final _venueController = TextEditingController();
  final _notesController = TextEditingController();
  Timer? _searchDebounce;
  DateTime? _date;
  TimeOfDay? _cateringClosesAt;
  Venue? _selectedVenue;
  List<Venue> _venueResults = const [];
  bool _isSearchingVenues = false;
  String? _venueSearchError;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _artistController.dispose();
    _venueController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Expanded(child: Text('Nouveau concert')),
          IconButton(
            tooltip: 'Fermer',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _artistController,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Artiste'),
                  validator: _requiredValidator,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                FormField<DateTime>(
                  validator: (value) =>
                      value == null ? 'Ce champ est requis.' : null,
                  builder: (field) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _selectDate(field),
                        icon: const Icon(Icons.calendar_today_outlined),
                        label: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _date == null
                                ? 'Date du concert'
                                : _formatDate(_date!),
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: field.hasError
                              ? Theme.of(context).colorScheme.error
                              : null,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 18,
                          ),
                        ),
                      ),
                      if (field.errorText != null)
                        Padding(
                          padding: const EdgeInsets.only(left: 12, top: 8),
                          child: Text(
                            field.errorText!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                FormField<Venue>(
                  validator: (value) =>
                      value == null ? 'Ce champ est requis.' : null,
                  builder: (field) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _venueController,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: 'Salle',
                          hintText: 'Saisissez au moins 2 caractères',
                          errorText: field.errorText,
                          suffixIcon: _isSearchingVenues
                              ? const Padding(
                                  padding: EdgeInsets.all(14),
                                  child: SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              : const Icon(Icons.search),
                        ),
                        onChanged: (value) {
                          if (_selectedVenue?.name != value) {
                            _selectedVenue = null;
                            field.didChange(null);
                          }
                          _scheduleVenueSearch(value);
                        },
                      ),
                      if (_venueSearchError != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            _venueSearchError!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      if (_venueResults.isNotEmpty)
                        Card(
                          margin: const EdgeInsets.only(top: 4),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 240),
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: _venueResults.length,
                              itemBuilder: (context, index) {
                                final venue = _venueResults[index];
                                return ListTile(
                                  dense: true,
                                  title: Text(venue.name),
                                  subtitle: Text(venue.formattedAddress),
                                  onTap: () {
                                    _searchDebounce?.cancel();
                                    setState(() {
                                      _selectedVenue = venue;
                                      _venueController.text = venue.name;
                                      _venueResults = const [];
                                      _venueSearchError = null;
                                    });
                                    field.didChange(venue);
                                  },
                                );
                              },
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _selectCateringTime,
                  icon: const Icon(Icons.schedule_outlined),
                  label: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _cateringClosesAt == null
                          ? 'Heure de fermeture du catering (optionnel)'
                          : 'Fermeture du catering : '
                                '${_cateringClosesAt!.format(context)}',
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 18,
                    ),
                  ),
                ),
                if (_cateringClosesAt != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Arrivée recommandée : '
                    '${_recommendedArrival(_cateringClosesAt!).format(context)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 16),
                TextFormField(
                  controller: _notesController,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optionnel)',
                  ),
                  minLines: 3,
                  maxLines: 5,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Enregistrer')),
      ],
    );
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

  Future<void> _selectDate(FormFieldState<DateTime> field) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _date ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (selected != null) {
      setState(() => _date = selected);
      field.didChange(selected);
    }
  }

  Future<void> _selectCateringTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: _cateringClosesAt ?? TimeOfDay.now(),
    );
    if (selected != null) setState(() => _cateringClosesAt = selected);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final venue = _selectedVenue;
    final date = _date;
    if (venue == null || date == null) return;

    Navigator.of(context).pop(
      CreateConcertDraft(
        artist: _artistController.text.trim(),
        date: date,
        venueId: venue.id,
        cateringClosesAt: _cateringClosesAt == null
            ? null
            : _timeToDatabase(_cateringClosesAt!),
        notes: _optionalValue(_notesController.text),
      ),
    );
  }
}

class ConcertFormDialog extends StatefulWidget {
  const ConcertFormDialog({
    required this.initialConcert,
    required this.onSubmit,
    super.key,
  });

  final Concert initialConcert;
  final Future<void> Function(ConcertDraft draft) onSubmit;

  @override
  State<ConcertFormDialog> createState() => _ConcertFormDialogState();
}

class _ConcertFormDialogState extends State<ConcertFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _artistController;
  late final TextEditingController _tourController;
  late final TextEditingController _notesController;
  late final TextEditingController _promoterContactNameController;
  late final TextEditingController _promoterContactPhoneController;
  late final TextEditingController _promoterContactEmailController;
  late final TextEditingController _cateringContactNameController;
  late final TextEditingController _cateringContactPhoneController;
  late final TextEditingController _cateringContactEmailController;
  late DateTime _date;
  late TimeOfDay _time;
  late ConcertStatus _status;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final concert = widget.initialConcert;
    _titleController = TextEditingController(text: concert.title);
    _artistController = TextEditingController(text: concert.artist);
    _tourController = TextEditingController(text: concert.tour);
    _notesController = TextEditingController(text: concert.notes);
    _promoterContactNameController = TextEditingController(
      text: concert.promoterContactName,
    );
    _promoterContactPhoneController = TextEditingController(
      text: concert.promoterContactPhone,
    );
    _promoterContactEmailController = TextEditingController(
      text: concert.promoterContactEmail,
    );
    _cateringContactNameController = TextEditingController(
      text: concert.cateringContactName,
    );
    _cateringContactPhoneController = TextEditingController(
      text: concert.cateringContactPhone,
    );
    _cateringContactEmailController = TextEditingController(
      text: concert.cateringContactEmail,
    );
    _date = concert.date;
    _time = concert.time == null
        ? TimeOfDay.now()
        : _timeFromDatabase(concert.time!);
    _status = concert.status;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _artistController.dispose();
    _tourController.dispose();
    _notesController.dispose();
    _promoterContactNameController.dispose();
    _promoterContactPhoneController.dispose();
    _promoterContactEmailController.dispose();
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
          const Expanded(child: Text('Modifier le concert')),
          IconButton(
            tooltip: 'Fermer',
            onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _titleController,
                  autofocus: true,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Titre'),
                  validator: _requiredValidator,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _artistController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Artiste'),
                  validator: _requiredValidator,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _tourController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Tournée (optionnel)',
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _selectDate,
                        icon: const Icon(Icons.calendar_today_outlined),
                        label: Text(_formatDate(_date)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _selectTime,
                        icon: const Icon(Icons.schedule),
                        label: Text(_time.format(context)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<ConcertStatus>(
                  initialValue: _status,
                  decoration: const InputDecoration(labelText: 'Statut'),
                  items: [
                    for (final status in ConcertStatus.values)
                      DropdownMenuItem(
                        value: status,
                        child: Text(_statusLabel(status)),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) _status = value;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _notesController,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optionnel)',
                  ),
                  minLines: 3,
                  maxLines: 5,
                ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Contacts sur place',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(height: 16),
                _ContactFields(
                  title: 'Contact tourneur',
                  nameController: _promoterContactNameController,
                  phoneController: _promoterContactPhoneController,
                  emailController: _promoterContactEmailController,
                ),
                const SizedBox(height: 20),
                _ContactFields(
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
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Enregistrer'),
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

  Future<void> _selectTime() async {
    final selected = await showTimePicker(context: context, initialTime: _time);
    if (selected != null) setState(() => _time = selected);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final draft = ConcertDraft(
      title: _titleController.text.trim(),
      artist: _artistController.text.trim(),
      tour: _optionalValue(_tourController.text),
      date: _date,
      time:
          '${_time.hour.toString().padLeft(2, '0')}:'
          '${_time.minute.toString().padLeft(2, '0')}:00',
      status: _status,
      notes: _optionalValue(_notesController.text),
      promoterContactName: _optionalValue(_promoterContactNameController.text),
      promoterContactPhone: _optionalValue(
        _promoterContactPhoneController.text,
      ),
      promoterContactEmail: _optionalValue(
        _promoterContactEmailController.text,
      ),
      cateringContactName: _optionalValue(_cateringContactNameController.text),
      cateringContactPhone: _optionalValue(
        _cateringContactPhoneController.text,
      ),
      cateringContactEmail: _optionalValue(
        _cateringContactEmailController.text,
      ),
    );

    setState(() => _isSubmitting = true);
    try {
      await widget.onSubmit(draft);
      if (mounted) Navigator.of(context).pop(true);
    } on Exception {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible d’enregistrer les modifications.'),
        ),
      );
    }
  }
}

class _ContactFields extends StatelessWidget {
  const _ContactFields({
    required this.title,
    required this.nameController,
    required this.phoneController,
    required this.emailController,
  });

  final String title;
  final TextEditingController nameController;
  final TextEditingController phoneController;
  final TextEditingController emailController;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 12),
        TextFormField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'Nom'),
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: phoneController,
          decoration: const InputDecoration(labelText: 'Téléphone'),
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: emailController,
          decoration: const InputDecoration(labelText: 'E-mail'),
          keyboardType: TextInputType.emailAddress,
          validator: validateOptionalEmail,
          autovalidateMode: AutovalidateMode.onUserInteraction,
        ),
      ],
    );
  }
}

class _ConcertsError extends StatelessWidget {
  const _ConcertsError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}

String? _requiredValidator(String? value) {
  if (value == null || value.trim().isEmpty) return 'Ce champ est requis.';
  return null;
}

String? _optionalValue(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String _formatDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}

String _timeToDatabase(TimeOfDay value) {
  return '${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}:00';
}

TimeOfDay _recommendedArrival(TimeOfDay cateringClosesAt) {
  final totalMinutes =
      (cateringClosesAt.hour * 60 + cateringClosesAt.minute - 15) % (24 * 60);
  return TimeOfDay(hour: totalMinutes ~/ 60, minute: totalMinutes % 60);
}

List<Concert> _sortForDashboard(List<Concert> concerts) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final sorted = List<Concert>.of(concerts);
  sorted.sort((left, right) {
    final leftIsPast = left.date.isBefore(today);
    final rightIsPast = right.date.isBefore(today);
    if (leftIsPast != rightIsPast) return leftIsPast ? 1 : -1;
    return leftIsPast
        ? right.date.compareTo(left.date)
        : left.date.compareTo(right.date);
  });
  return sorted;
}

TimeOfDay _timeFromDatabase(String value) {
  final parts = value.split(':');
  return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
}

String _statusLabel(ConcertStatus status) {
  return switch (status) {
    ConcertStatus.planned => 'Planifié',
    ConcertStatus.confirmed => 'Confirmé',
    ConcertStatus.completed => 'Terminé',
    ConcertStatus.cancelled => 'Annulé',
  };
}

String _errorMessage(Object error) {
  if (error is MissingMembershipException ||
      error is AmbiguousProducerMembershipException) {
    return error.toString();
  }
  return 'Une erreur est survenue lors du chargement des concerts.';
}

void _showError(BuildContext context, Object error) {
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(_errorMessage(error))));
}
