import 'package:club_sandwich/design_system/components/buttons/ds_primary_button.dart';
import 'package:club_sandwich/design_system/components/surfaces/ds_card.dart';
import 'package:club_sandwich/design_system/icons/ds_icons.dart';
import 'package:club_sandwich/design_system/tokens/ds_radius.dart';
import 'package:club_sandwich/design_system/tokens/ds_spacing.dart';
import 'package:club_sandwich/design_system/tokens/ds_theme.dart';
import 'package:club_sandwich/design_system/tokens/ds_tokens.dart';
import 'package:club_sandwich/design_system/tokens/ds_typography.dart';
import 'package:club_sandwich/features/venues/data/venue_providers.dart';
import 'package:club_sandwich/features/venues/domain/venue.dart';
import 'package:club_sandwich/shared/utils/error_messages.dart';
import 'package:club_sandwich/shared/widgets/app_state_panel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class VenuesScreen extends ConsumerStatefulWidget {
  const VenuesScreen({super.key});

  @override
  ConsumerState<VenuesScreen> createState() => _VenuesScreenState();
}

class _VenuesScreenState extends ConsumerState<VenuesScreen> {
  String? _selectedId;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final venues = ref.watch(venuesProvider);
    return Theme(
      data: DsTheme.light,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: venues.when(
          loading: () => const AppLoadingState(label: 'Chargement des salles'),
          error: (_, _) => AppErrorState(
            message: 'Impossible de charger les salles.',
            onRetry: () => ref.invalidate(venuesProvider),
          ),
          data: (items) {
            final filtered = _query.trim().isEmpty
                ? items
                : items
                      .where(
                        (v) => v.name.toLowerCase().contains(
                          _query.trim().toLowerCase(),
                        ),
                      )
                      .toList(growable: false);
            final selectedId = _selectedId ?? filtered.firstOrNull?.id;

            return LayoutBuilder(
              builder: (context, constraints) {
                final list = _VenueList(
                  venues: filtered,
                  totalCount: items.length,
                  query: _query,
                  onQueryChanged: (value) => setState(() => _query = value),
                  selectedId: constraints.maxWidth < 840 ? null : selectedId,
                  onTap: (venue) => constraints.maxWidth < 840
                      ? _showMobileDetails(venue)
                      : setState(() => _selectedId = venue.id),
                );

                if (constraints.maxWidth < 840) {
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                    children: [list],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: 320,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [list],
                      ),
                    ),
                    Builder(
                      builder: (context) {
                        final colors = Theme.of(
                          context,
                        ).extension<DsTokens>()!.colors;
                        return VerticalDivider(width: 1, color: colors.border);
                      },
                    ),
                    Expanded(
                      child: selectedId == null
                          ? const SizedBox()
                          : SingleChildScrollView(
                              child: _VenueDetailsPane(
                                key: ValueKey(selectedId),
                                venueId: selectedId,
                              ),
                            ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _showMobileDetails(Venue venue) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Theme(
        data: DsTheme.light,
        child: DraggableScrollableSheet(
          initialChildSize: 0.85,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) => Builder(
            builder: (context) {
              final colors = Theme.of(context).extension<DsTokens>()!.colors;
              return Container(
                decoration: BoxDecoration(
                  color: colors.canvas,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(DsRadius.xxl),
                  ),
                ),
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(DsSpacing.lg),
                  child: _VenueDetailsPane(venueId: venue.id),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _VenueList extends StatelessWidget {
  const _VenueList({
    required this.venues,
    required this.totalCount,
    required this.query,
    required this.onQueryChanged,
    required this.selectedId,
    required this.onTap,
  });

  final List<Venue> venues;
  final int totalCount;
  final String query;
  final ValueChanged<String> onQueryChanged;
  final String? selectedId;
  final ValueChanged<Venue> onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<DsTokens>()!.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Salles', style: DsTypography.h1.copyWith(color: colors.textPrimary)),
        const SizedBox(height: 4),
        Text(
          '$totalCount salle${totalCount > 1 ? 's' : ''}',
          style: DsTypography.body.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: DsSpacing.lg),
        TextField(
          onChanged: onQueryChanged,
          decoration: InputDecoration(
            hintText: 'Rechercher une salle',
            prefixIcon: Icon(DsIcons.search, size: 18, color: colors.textSecondary),
          ),
        ),
        const SizedBox(height: DsSpacing.lg),
        if (venues.isEmpty)
          Text(
            'Aucune salle ne correspond à cette recherche.',
            style: DsTypography.meta.copyWith(color: colors.textSecondary),
          )
        else
          for (final venue in venues)
            Padding(
              padding: const EdgeInsets.only(bottom: DsSpacing.sm),
              child: _VenueListItem(
                venue: venue,
                selected: venue.id == selectedId,
                onTap: () => onTap(venue),
              ),
            ),
      ],
    );
  }
}

class _VenueListItem extends StatelessWidget {
  const _VenueListItem({
    required this.venue,
    required this.selected,
    required this.onTap,
  });

  final Venue venue;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<DsTokens>()!.colors;
    return DsCard(
      padding: const EdgeInsets.all(DsSpacing.sm),
      borderRadius: DsRadius.lgRadius,
      onTap: onTap,
      child: Row(
        children: [
          ClipRRect(
            borderRadius: DsRadius.mdRadius,
            child: SizedBox(
              width: 44,
              height: 44,
              child: venue.photoUrl == null
                  ? ColoredBox(
                      color: colors.secondarySelectedBg,
                      child: Icon(
                        DsIcons.building,
                        size: 18,
                        color: colors.textSecondary,
                      ),
                    )
                  : Image.network(
                      venue.photoUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => ColoredBox(
                        color: colors.secondarySelectedBg,
                        child: Icon(
                          DsIcons.building,
                          size: 18,
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: DsSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  venue.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DsTypography.body.copyWith(
                    color: colors.textPrimary,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                Text(
                  '${venue.postalCode} ${venue.city}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DsTypography.caption.copyWith(color: colors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VenueDetailsPane extends ConsumerStatefulWidget {
  const _VenueDetailsPane({required this.venueId, super.key});

  final String venueId;

  @override
  ConsumerState<_VenueDetailsPane> createState() => _VenueDetailsPaneState();
}

class _VenueDetailsPaneState extends ConsumerState<_VenueDetailsPane> {
  bool _uploading = false;
  bool _savingAccess = false;
  late final TextEditingController _entranceLine1;
  late final TextEditingController _entranceLine2;
  late final TextEditingController _entrancePostalCode;
  late final TextEditingController _entranceCity;
  late final TextEditingController _accessInstructions;

  @override
  void initState() {
    super.initState();
    final venue = ref
        .read(venuesProvider)
        .maybeWhen(
          data: (items) =>
              items.where((v) => v.id == widget.venueId).firstOrNull,
          orElse: () => null,
        );
    _entranceLine1 = TextEditingController(
      text: venue?.artistEntranceAddressLine1 ?? '',
    );
    _entranceLine2 = TextEditingController(
      text: venue?.artistEntranceAddressLine2 ?? '',
    );
    _entrancePostalCode = TextEditingController(
      text: venue?.artistEntrancePostalCode ?? '',
    );
    _entranceCity = TextEditingController(
      text: venue?.artistEntranceCity ?? '',
    );
    _accessInstructions = TextEditingController(
      text: venue?.accessInstructions ?? '',
    );
  }

  @override
  void dispose() {
    _entranceLine1.dispose();
    _entranceLine2.dispose();
    _entrancePostalCode.dispose();
    _entranceCity.dispose();
    _accessInstructions.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<DsTokens>()!.colors;
    final venue = ref
        .watch(venuesProvider)
        .maybeWhen(
          data: (items) =>
              items.where((v) => v.id == widget.venueId).firstOrNull,
          orElse: () => null,
        );
    if (venue == null) return const SizedBox();

    return Padding(
      padding: const EdgeInsets.all(DsSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: DsRadius.xlRadius,
            child: AspectRatio(
              // A fixed height regardless of the pane's width used to
              // force very wide panes into an extreme, heavily-cropped
              // banner shape — a fixed aspect ratio keeps the crop
              // proportionate at any pane width instead.
              aspectRatio: 16 / 9,
              child: Container(
                color: colors.secondarySelectedBg,
                child: venue.photoUrl == null
                    ? Icon(
                        DsIcons.building,
                        size: 40,
                        color: colors.textSecondary,
                      )
                    : Image.network(
                        venue.photoUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Icon(
                          DsIcons.building,
                          size: 40,
                          color: colors.textSecondary,
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: DsSpacing.md),
          DsPrimaryButton(
            label: venue.photoUrl == null ? 'Ajouter une photo' : 'Changer la photo',
            isLoading: _uploading,
            onPressed: _uploading ? null : _uploadPhoto,
          ),
          const SizedBox(height: DsSpacing.xl),
          Text(venue.name, style: DsTypography.h2.copyWith(color: colors.textPrimary)),
          const SizedBox(height: DsSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(DsIcons.mapPin, size: 16, color: colors.textSecondary),
              const SizedBox(width: DsSpacing.sm),
              Expanded(
                child: Text(
                  venue.formattedAddress,
                  style: DsTypography.body.copyWith(color: colors.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: DsSpacing.xl),
          Text(
            'Entrée artiste',
            style: DsTypography.h3.copyWith(color: colors.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            'Visible par l\'admin, le tourneur et l\'équipe confirmée sur la '
            'fiche maraude.',
            style: DsTypography.meta.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: DsSpacing.md),
          TextField(
            controller: _entranceLine1,
            decoration: const InputDecoration(labelText: 'Adresse'),
          ),
          const SizedBox(height: DsSpacing.sm),
          TextField(
            controller: _entranceLine2,
            decoration: const InputDecoration(labelText: 'Complément'),
          ),
          const SizedBox(height: DsSpacing.sm),
          Row(
            children: [
              SizedBox(
                width: 140,
                child: TextField(
                  controller: _entrancePostalCode,
                  decoration: const InputDecoration(labelText: 'Code postal'),
                ),
              ),
              const SizedBox(width: DsSpacing.sm),
              Expanded(
                child: TextField(
                  controller: _entranceCity,
                  decoration: const InputDecoration(labelText: 'Ville'),
                ),
              ),
            ],
          ),
          const SizedBox(height: DsSpacing.sm),
          TextField(
            controller: _accessInstructions,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Instructions d\'accès',
              hintText: 'Ex : sonner à l\'interphone "Régie", accès par la rue...',
            ),
          ),
          const SizedBox(height: DsSpacing.md),
          DsPrimaryButton(
            label: 'Enregistrer l\'entrée artiste',
            isLoading: _savingAccess,
            onPressed: _savingAccess ? null : _saveAccessDetails,
          ),
        ],
      ),
    );
  }

  Future<void> _saveAccessDetails() async {
    setState(() => _savingAccess = true);
    try {
      await ref
          .read(venueRepositoryProvider)
          .updateAccessDetails(
            venueId: widget.venueId,
            artistEntranceAddressLine1: _nullIfBlank(_entranceLine1.text),
            artistEntranceAddressLine2: _nullIfBlank(_entranceLine2.text),
            artistEntrancePostalCode: _nullIfBlank(_entrancePostalCode.text),
            artistEntranceCity: _nullIfBlank(_entranceCity.text),
            accessInstructions: _nullIfBlank(_accessInstructions.text),
          );
      ref.invalidate(venuesProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Entrée artiste enregistrée.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            describeError(error, 'Impossible d\'enregistrer l\'entrée artiste.'),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _savingAccess = false);
    }
  }

  String? _nullIfBlank(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Future<void> _uploadPhoto() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
      withData: true,
    );
    final file = result?.files.single;
    if (file?.bytes == null || !mounted) return;
    final extension = (file!.extension ?? 'jpg').toLowerCase();
    final contentType = switch (extension) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };
    setState(() => _uploading = true);
    try {
      await ref
          .read(venueRepositoryProvider)
          .uploadVenuePhoto(
            venueId: widget.venueId,
            extension: extension,
            bytes: file.bytes!,
            contentType: contentType,
          );
      ref.invalidate(venuesProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Photo mise à jour.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(describeError(error, 'Impossible de mettre à jour la photo.')),
        ),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }
}
