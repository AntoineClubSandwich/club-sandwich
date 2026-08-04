import 'dart:async';

import 'package:club_sandwich/features/venues/data/venue_providers.dart';
import 'package:club_sandwich/features/venues/domain/venue.dart';
import 'package:club_sandwich/shared/utils/error_messages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class VenueSearchField extends ConsumerStatefulWidget {
  const VenueSearchField({
    required this.inputKey,
    required this.onChanged,
    this.initialVenue,
    this.autofocus = false,
    super.key,
  });

  final Key inputKey;
  final Venue? initialVenue;
  final ValueChanged<Venue?> onChanged;
  final bool autofocus;

  @override
  ConsumerState<VenueSearchField> createState() => _VenueSearchFieldState();
}

class _VenueSearchFieldState extends ConsumerState<VenueSearchField> {
  final _fieldKey = GlobalKey<FormFieldState<Venue>>();
  late final TextEditingController _controller;
  Timer? _searchDebounce;
  Venue? _selectedVenue;
  List<Venue> _results = const [];
  bool _isSearching = false;
  String? _searchError;

  @override
  void initState() {
    super.initState();
    _selectedVenue = widget.initialVenue;
    _controller = TextEditingController(text: widget.initialVenue?.name);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FormField<Venue>(
      key: _fieldKey,
      initialValue: _selectedVenue,
      validator: (value) => value == null ? 'Ce champ est requis.' : null,
      builder: (field) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            key: widget.inputKey,
            controller: _controller,
            autofocus: widget.autofocus,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'Salle',
              hintText: 'Saisissez au moins 2 caractères',
              errorText: field.errorText,
              suffixIcon: _isSearching
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : const Icon(Icons.search),
            ),
            onChanged: _onTextChanged,
          ),
          if (_searchError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _searchError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (_results.isNotEmpty)
            Card(
              margin: const EdgeInsets.only(top: 4),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 240),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _results.length,
                  itemBuilder: (context, index) {
                    final venue = _results[index];
                    return ListTile(
                      dense: true,
                      title: Text(venue.name),
                      subtitle: Text(venue.formattedAddress),
                      onTap: () => _selectVenue(venue),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _onTextChanged(String value) {
    if (_selectedVenue?.name != value) {
      _selectedVenue = null;
      _fieldKey.currentState?.didChange(null);
      widget.onChanged(null);
    }
    _scheduleSearch(value);
    setState(() {});
  }

  void _selectVenue(Venue venue) {
    _searchDebounce?.cancel();
    setState(() {
      _selectedVenue = venue;
      _controller.text = venue.name;
      _results = const [];
      _searchError = null;
    });
    _fieldKey.currentState?.didChange(venue);
    widget.onChanged(venue);
  }

  void _scheduleSearch(String query) {
    _searchDebounce?.cancel();
    final normalizedQuery = query.trim();
    if (normalizedQuery.length < 2) {
      setState(() {
        _results = const [];
        _searchError = null;
        _isSearching = false;
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
      _isSearching = true;
      _searchError = null;
    });
    try {
      final results = await ref
          .read(venueRepositoryProvider)
          .searchActiveVenues(query);
      if (!mounted ||
          _selectedVenue != null ||
          _controller.text.trim() != query) {
        return;
      }
      setState(() => _results = results);
    } catch (error) {
      if (!mounted || _controller.text.trim() != query) return;
      setState(() {
        _results = const [];
        _searchError = describeError(
          error,
          'Impossible de rechercher les salles.',
        );
      });
    } finally {
      if (mounted && _controller.text.trim() == query) {
        setState(() => _isSearching = false);
      }
    }
  }
}
