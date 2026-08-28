import 'package:club_sandwich/design_system/components/buttons/ds_ghost_button.dart';
import 'package:club_sandwich/design_system/components/buttons/ds_primary_button.dart';
import 'package:club_sandwich/design_system/components/ds_hover_spotlight.dart';
import 'package:club_sandwich/design_system/components/ds_reveal_on_scroll.dart';
import 'package:club_sandwich/design_system/components/indicators/ds_skeleton.dart';
import 'package:club_sandwich/design_system/components/indicators/ds_status_chip.dart';
import 'package:club_sandwich/design_system/components/inputs/ds_dropdown.dart';
import 'package:club_sandwich/design_system/components/inputs/ds_filter_chip.dart';
import 'package:club_sandwich/design_system/components/inputs/ds_text_field.dart';
import 'package:club_sandwich/design_system/components/surfaces/ds_card.dart';
import 'package:club_sandwich/design_system/icons/ds_icons.dart';
import 'package:club_sandwich/design_system/tokens/ds_radius.dart';
import 'package:club_sandwich/design_system/tokens/ds_spacing.dart';
import 'package:club_sandwich/design_system/tokens/ds_theme.dart';
import 'package:club_sandwich/design_system/tokens/ds_tokens.dart';
import 'package:club_sandwich/design_system/tokens/ds_typography.dart';
import 'package:club_sandwich/design_system/widgets/club_sandwich_mascot.dart';
import 'package:club_sandwich/features/auth/application/auth_providers.dart';
import 'package:club_sandwich/features/auth/domain/user_account.dart';
import 'package:club_sandwich/features/concerts/data/concert_providers.dart';
import 'package:club_sandwich/features/concerts/domain/concert.dart';
import 'package:club_sandwich/features/concerts/presentation/concert_form.dart';
import 'package:club_sandwich/features/concerts/presentation/concert_formatters.dart';
import 'package:club_sandwich/features/concerts/presentation/maraude_calendar.dart';
import 'package:club_sandwich/features/organizations/data/organization_providers.dart';
import 'package:club_sandwich/features/organizations/domain/organization.dart';
import 'package:club_sandwich/shared/utils/error_messages.dart';
import 'package:club_sandwich/shared/widgets/app_state_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ConcertsScreen extends ConsumerStatefulWidget {
  const ConcertsScreen({super.key});

  @override
  ConsumerState<ConcertsScreen> createState() => _ConcertsScreenState();
}

class _ConcertsScreenState extends ConsumerState<ConcertsScreen> {
  final _artistFilterController = TextEditingController();
  final _venueFilterController = TextEditingController();
  final _promoterFilterController = TextEditingController();
  Set<String> _selectedOrganizationIds = {};
  ConcertStatus? _concertStatusFilter;
  MaraudeStatus? _maraudeStatusFilter;
  bool? _cateringFilter;
  late DateTime _displayedMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _displayedMonth = DateTime(now.year, now.month);
  }

  @override
  void dispose() {
    _artistFilterController.dispose();
    _venueFilterController.dispose();
    _promoterFilterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncConcerts = ref.watch(concertsProvider);
    final viewMode = ref.watch(concertViewModeProvider);
    final currentRole = ref.watch(currentUserContextProvider).value?.role;
    final promoterOrganizations =
        (ref.watch(organizationsProvider).value ?? const <Organization>[])
            .where(
              (organization) => organization.kind == OrganizationKind.promoter,
            )
            .toList(growable: false);

    return Theme(
      data: DsTheme.light,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          children: [
            MaraudeViewToolbar(
              title: 'Maraudes',
              viewMode: viewMode,
              onViewChanged: (mode) =>
                  ref.read(concertViewModeProvider.notifier).select(mode),
              selectorKey: const ValueKey('concert-view-selector'),
            ),
            Expanded(
              child: asyncConcerts.when(
                loading: () => const _ConcertsSkeletonGrid(),
                error: (error, stackTrace) => AppErrorState(
                  message: _errorMessage(error),
                  onRetry: () => ref.invalidate(concertsProvider),
                ),
                data: (items) {
                  final filtered = _filterConcerts(items);
                  return RefreshIndicator(
                    onRefresh: () => ref.refresh(concertsProvider.future),
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                          sliver: SliverToBoxAdapter(
                            child: _ConcertFilters(
                              artistController: _artistFilterController,
                              venueController: _venueFilterController,
                              promoterController: _promoterFilterController,
                              organizations: promoterOrganizations,
                              selectedOrganizationIds: _selectedOrganizationIds,
                              concertStatus: _concertStatusFilter,
                              maraudeStatus: _maraudeStatusFilter,
                              cateringFilter: _cateringFilter,
                              onTextChanged: (_) => setState(() {}),
                              onOrganizationsChanged: (value) => setState(
                                () => _selectedOrganizationIds = value,
                              ),
                              onConcertStatusChanged: (value) =>
                                  setState(() => _concertStatusFilter = value),
                              onMaraudeStatusChanged: (value) =>
                                  setState(() => _maraudeStatusFilter = value),
                              onCateringChanged: (value) =>
                                  setState(() => _cateringFilter = value),
                              onClear: _clearFilters,
                            ),
                          ),
                        ),
                        if (items.isEmpty)
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: _EmptyConcerts(
                              onCreate: () => _createConcert(context),
                            ),
                          )
                        else if (filtered.isEmpty)
                          const SliverFillRemaining(
                            hasScrollBody: false,
                            child: _NoFilterResults(),
                          )
                        else if (viewMode == ConcertViewMode.list)
                          _ConcertListSliver(
                            concerts: _sortForDashboard(filtered),
                            role: currentRole,
                          )
                        else
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                            sliver: SliverToBoxAdapter(
                              child: MaraudeCalendar(
                                month: _displayedMonth,
                                items: filtered
                                    .map(_concertCalendarItem)
                                    .toList(growable: false),
                                onPreviousMonth: () => _changeMonth(-1),
                                onNextMonth: () => _changeMonth(1),
                                onToday: _goToCurrentMonth,
                                onOpen: (id) => context.go('/maraudes/$id'),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        floatingActionButton: asyncConcerts.value?.isNotEmpty == true
            ? FloatingActionButton.extended(
                onPressed: () => _createConcert(context),
                icon: const Icon(Icons.add),
                label: const Text('Nouvelle maraude'),
              )
            : null,
      ),
    );
  }

  List<Concert> _filterConcerts(List<Concert> items) {
    final artist = _normalize(_artistFilterController.text);
    final venue = _normalize(_venueFilterController.text);
    final promoter = _normalize(_promoterFilterController.text);
    return items
        .where((concert) {
          final hasCatering =
              concert.cateringContactName != null &&
              concert.cateringContactName!.trim().isNotEmpty;
          return _contains(concert.artist, artist) &&
              _contains(concert.venueName, venue) &&
              _contains(concert.promoterContactName, promoter) &&
              (_selectedOrganizationIds.isEmpty ||
                  _selectedOrganizationIds.contains(concert.organizationId)) &&
              (_concertStatusFilter == null ||
                  concert.status == _concertStatusFilter) &&
              (_maraudeStatusFilter == null ||
                  concert.maraudeStatus == _maraudeStatusFilter) &&
              (_cateringFilter == null || hasCatering == _cateringFilter);
        })
        .toList(growable: false);
  }

  void _clearFilters() {
    _artistFilterController.clear();
    _venueFilterController.clear();
    _promoterFilterController.clear();
    setState(() {
      _selectedOrganizationIds = {};
      _concertStatusFilter = null;
      _maraudeStatusFilter = null;
      _cateringFilter = null;
    });
  }

  void _changeMonth(int delta) {
    setState(() {
      _displayedMonth = DateTime(
        _displayedMonth.year,
        _displayedMonth.month + delta,
      );
    });
  }

  void _goToCurrentMonth() {
    final now = DateTime.now();
    setState(() => _displayedMonth = DateTime(now.year, now.month));
  }

  Future<void> _createConcert(BuildContext context) async {
    var promoterOrganizations = const <Organization>[];
    CurrentUserContext? account;
    try {
      account = await ref.read(currentUserContextProvider.future);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            describeError(
              error,
              'Impossible de vérifier votre compte utilisateur.',
            ),
          ),
        ),
      );
      return;
    }
    if (account == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Votre session n’est plus disponible.')),
      );
      return;
    }
    if (account.role == AppUserRole.admin) {
      try {
        promoterOrganizations = (await ref.read(organizationsProvider.future))
            .where(
              (organization) => organization.kind == OrganizationKind.promoter,
            )
            .toList(growable: false);
      } catch (error) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              describeError(
                error,
                'Impossible de charger les organisations tourneurs.',
              ),
            ),
          ),
        );
        return;
      }
    }

    if (!context.mounted) return;
    final created = await showDialog<bool>(
      context: context,
      builder: (context) => ConcertForm(
        promoterOrganizations: promoterOrganizations,
        onSubmit: (draft, {required asDraft}) => ref
            .read(concertRepositoryProvider)
            .createConcert(draft, asDraft: asDraft),
      ),
    );
    if (created != true || !context.mounted) return;

    ref.invalidate(concertsProvider);
    ref.invalidate(maraudeOverviewProvider);
    await ref.read(concertsProvider.future);
    if (!context.mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Maraude créée.')));
  }
}

class _ConcertFilters extends StatelessWidget {
  const _ConcertFilters({
    required this.artistController,
    required this.venueController,
    required this.promoterController,
    required this.organizations,
    required this.selectedOrganizationIds,
    required this.concertStatus,
    required this.maraudeStatus,
    required this.cateringFilter,
    required this.onTextChanged,
    required this.onOrganizationsChanged,
    required this.onConcertStatusChanged,
    required this.onMaraudeStatusChanged,
    required this.onCateringChanged,
    required this.onClear,
  });

  final TextEditingController artistController;
  final TextEditingController venueController;
  final TextEditingController promoterController;
  final List<Organization> organizations;
  final Set<String> selectedOrganizationIds;
  final ConcertStatus? concertStatus;
  final MaraudeStatus? maraudeStatus;
  final bool? cateringFilter;
  final ValueChanged<String> onTextChanged;
  final ValueChanged<Set<String>> onOrganizationsChanged;
  final ValueChanged<ConcertStatus?> onConcertStatusChanged;
  final ValueChanged<MaraudeStatus?> onMaraudeStatusChanged;
  final ValueChanged<bool?> onCateringChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<DsTokens>()!;
    final colors = tokens.colors;
    return DsCard(
      padding: EdgeInsets.zero,
      borderRadius: DsRadius.lgRadius,
      child: ExpansionTile(
        key: const ValueKey('concert-filters'),
        leading: Icon(DsIcons.filter, color: colors.textPrimary),
        title: Text(
          'Filtres',
          style: DsTypography.body.copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        shape: const RoundedRectangleBorder(side: BorderSide.none),
        collapsedShape: const RoundedRectangleBorder(side: BorderSide.none),
        childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final fieldWidth = constraints.maxWidth >= 900
                  ? (constraints.maxWidth - 32) / 3
                  : constraints.maxWidth >= 560
                  ? (constraints.maxWidth - 16) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: 16,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: fieldWidth,
                    child: DsTextField(
                      key: const ValueKey('concert-filter-artist'),
                      controller: artistController,
                      label: 'Artiste',
                      prefixIcon: DsIcons.search,
                      onChanged: onTextChanged,
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: DsTextField(
                      key: const ValueKey('concert-filter-venue'),
                      controller: venueController,
                      label: 'Salle',
                      prefixIcon: DsIcons.search,
                      onChanged: onTextChanged,
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: DsTextField(
                      key: const ValueKey('concert-filter-promoter'),
                      controller: promoterController,
                      label: 'Contact tourneur',
                      prefixIcon: DsIcons.search,
                      onChanged: onTextChanged,
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: DsDropdown<ConcertStatus?>(
                      key: const ValueKey('concert-filter-status'),
                      label: 'Statut concert',
                      hintText: 'Tous',
                      value: concertStatus,
                      items: [
                        const DsDropdownItem(value: null, label: 'Tous'),
                        for (final status in ConcertStatus.values)
                          DsDropdownItem(
                            value: status,
                            label: _concertStatusLabel(status),
                          ),
                      ],
                      onChanged: onConcertStatusChanged,
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: DsDropdown<MaraudeStatus?>(
                      key: const ValueKey('concert-filter-maraude'),
                      label: 'Statut maraude',
                      hintText: 'Tous',
                      value: maraudeStatus,
                      items: [
                        const DsDropdownItem(value: null, label: 'Tous'),
                        for (final status in MaraudeStatus.values)
                          DsDropdownItem(value: status, label: status.label),
                      ],
                      onChanged: onMaraudeStatusChanged,
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: DsDropdown<bool?>(
                      key: const ValueKey('concert-filter-catering'),
                      label: 'Catering',
                      hintText: 'Tous',
                      value: cateringFilter,
                      items: const [
                        DsDropdownItem(value: null, label: 'Tous'),
                        DsDropdownItem(value: true, label: 'Avec catering'),
                        DsDropdownItem(value: false, label: 'Sans catering'),
                      ],
                      onChanged: onCateringChanged,
                    ),
                  ),
                ],
              );
            },
          ),
          if (organizations.isNotEmpty) ...[
            const SizedBox(height: DsSpacing.lg),
            Text(
              'Organisation tourneur',
              style: DsTypography.caption.copyWith(
                color: colors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: DsSpacing.sm),
            Wrap(
              key: const ValueKey('concert-filter-organizations'),
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final organization in organizations)
                  DsFilterChip(
                    key: ValueKey(
                      'concert-filter-organization-${organization.id}',
                    ),
                    label: organization.name,
                    selected: selectedOrganizationIds.contains(organization.id),
                    onSelected: (selected) {
                      final updated = Set<String>.of(selectedOrganizationIds);
                      if (selected) {
                        updated.add(organization.id);
                      } else {
                        updated.remove(organization.id);
                      }
                      onOrganizationsChanged(updated);
                    },
                  ),
              ],
            ),
          ],
          const SizedBox(height: DsSpacing.sm),
          Align(
            alignment: Alignment.centerRight,
            child: DsGhostButton(
              icon: DsIcons.close,
              label: 'Effacer les filtres',
              onPressed: onClear,
            ),
          ),
        ],
      ),
    );
  }
}

/// Loading placeholder for [_ConcertListSliver] — same grid shape and
/// card silhouette so nothing jumps around once the real data lands.
class _ConcertsSkeletonGrid extends StatelessWidget {
  const _ConcertsSkeletonGrid();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 1024
            ? 3
            : width >= 768
            ? 2
            : 1;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: 20,
              mainAxisSpacing: 20,
              mainAxisExtent: 366,
            ),
            itemCount: columns * 2,
            itemBuilder: (context, index) => const _ConcertCardSkeleton(),
          ),
        );
      },
    );
  }
}

class _ConcertCardSkeleton extends StatelessWidget {
  const _ConcertCardSkeleton();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<DsTokens>()!.colors;
    return DsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DsSkeleton(width: 180, height: 20),
          const SizedBox(height: DsSpacing.md),
          const DsSkeleton(
            width: 96,
            height: 22,
            borderRadius: DsRadius.pillRadius,
          ),
          const SizedBox(height: DsSpacing.lg),
          const DsSkeleton(width: 140, height: 14),
          const SizedBox(height: DsSpacing.sm),
          const DsSkeleton(width: 160, height: 14),
          const SizedBox(height: DsSpacing.sm),
          const DsSkeleton(width: 120, height: 14),
          const Spacer(),
          Divider(height: 1, color: colors.border),
          const SizedBox(height: DsSpacing.md),
          Row(
            children: [
              const DsSkeleton(width: 70, height: 12),
              const SizedBox(width: 24),
              const DsSkeleton(width: 70, height: 12),
            ],
          ),
        ],
      ),
    );
  }
}

class _ConcertListSliver extends StatelessWidget {
  const _ConcertListSliver({required this.concerts, required this.role});

  final List<Concert> concerts;
  final AppUserRole? role;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
      sliver: SliverLayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.crossAxisExtent;
          final columns = width >= 1024
              ? 3
              : width >= 768
              ? 2
              : 1;
          return SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: 20,
              mainAxisSpacing: 20,
              mainAxisExtent: 366,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => DsRevealOnScroll(
                delay: Duration(milliseconds: 40 * (index % 6)),
                child: _ConcertCard(concert: concerts[index], role: role),
              ),
              childCount: concerts.length,
            ),
          );
        },
      ),
    );
  }
}

class _ConcertCard extends ConsumerWidget {
  const _ConcertCard({required this.concert, required this.role});

  final Concert concert;
  final AppUserRole? role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<DsTokens>()!;
    final colors = tokens.colors;
    final (statusLabel, tone) = _concertCalendarStatus(concert);

    final photoUrl = concert.venue?.photoUrl;

    return DsHoverSpotlight(
      key: ValueKey('concert-card-spotlight-${concert.id}'),
      child: DsCard(
        key: ValueKey('concert-card-${concert.id}'),
        padding: EdgeInsets.zero,
        onTap: () => context.go('/maraudes/${concert.id}'),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(DsSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            concert.artist,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: DsTypography.h3.copyWith(
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                        if (role == AppUserRole.admin ||
                            role == AppUserRole.promoter)
                          PopupMenuButton<_ConcertAction>(
                            tooltip: 'Actions',
                            icon: Icon(
                              Icons.more_vert,
                              color: colors.textSecondary,
                            ),
                            onSelected: (action) {
                              switch (action) {
                                case _ConcertAction.edit:
                                  _edit(context, ref);
                                case _ConcertAction.delete:
                                  deleteConcertWithConfirmation(
                                    context,
                                    ref,
                                    concert,
                                  );
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: _ConcertAction.edit,
                                child: ListTile(
                                  leading: Icon(Icons.edit_outlined),
                                  title: Text('Modifier'),
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                              if (role == AppUserRole.admin)
                                const PopupMenuItem(
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
                    const SizedBox(height: DsSpacing.sm),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: DsStatusChip(
                        label: statusLabel,
                        status: _chipStatusFor(tone),
                      ),
                    ),
                    const SizedBox(height: DsSpacing.md),
                    _CardInformation(
                      icon: DsIcons.mapPin,
                      text: concert.venueName ?? '-',
                    ),
                    const SizedBox(height: DsSpacing.sm),
                    _CardInformation(
                      icon: DsIcons.calendar,
                      text: formatLongFrenchDate(concert.date),
                    ),
                    if (concert.cateringClosesAt != null) ...[
                      const SizedBox(height: DsSpacing.sm),
                      _CardInformation(
                        icon: DsIcons.clock,
                        text:
                            'Catering : ${formatDatabaseTime(concert.cateringClosesAt!)}',
                      ),
                      const SizedBox(height: DsSpacing.sm),
                      _CardInformation(
                        icon: DsIcons.footprints,
                        text:
                            'Arrivée recommandée : '
                            '${recommendedArrivalFromDatabase(concert.cateringClosesAt!)}',
                      ),
                    ],
                    const SizedBox(height: DsSpacing.md),
                    Divider(height: 1, color: colors.border),
                    const SizedBox(height: DsSpacing.md),
                    Wrap(
                      spacing: 24,
                      runSpacing: 8,
                      children: [
                        _Metadata(
                          label: 'Producteur',
                          value: concert.promoterOrganizationName ?? '-',
                        ),
                        _Metadata(
                          label: 'Équipe',
                          value: _volunteerCountLabel(
                            concert.selectedVolunteerCount,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (photoUrl != null)
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(DsRadius.xl),
                  bottomRight: Radius.circular(DsRadius.xl),
                ),
                child: SizedBox(
                  width: 140,
                  child: Image.network(
                    photoUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const SizedBox(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final updated = await showDialog<bool>(
      context: context,
      builder: (context) => ConcertForm(
        initialConcert: concert,
        onSubmit: (draft, {required asDraft}) => ref
            .read(concertRepositoryProvider)
            .updateConcert(concert.id, draft),
      ),
    );
    if (updated != true || !context.mounted) return;

    ref.invalidate(concertsProvider);
    ref.invalidate(concertDetailsProvider(concert.id));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Maraude modifiée.')));
  }
}

class _EmptyConcerts extends StatelessWidget {
  const _EmptyConcerts({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<DsTokens>()!.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ClubSandwichMascot(size: 96),
            const SizedBox(height: DsSpacing.lg),
            Text(
              'Aucune maraude',
              style: DsTypography.h2.copyWith(color: colors.textPrimary),
            ),
            const SizedBox(height: DsSpacing.sm),
            Text(
              'Ouvrez votre première maraude.',
              style: DsTypography.body.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: DsSpacing.xl),
            DsPrimaryButton(
              icon: DsIcons.plus,
              label: 'Ouvrir une maraude',
              onPressed: onCreate,
            ),
          ],
        ),
      ),
    );
  }
}

class _NoFilterResults extends StatelessWidget {
  const _NoFilterResults();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<DsTokens>()!.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(DsIcons.search, size: 48, color: colors.textSecondary),
            const SizedBox(height: DsSpacing.lg),
            Text(
              'Aucun résultat',
              style: DsTypography.h3.copyWith(color: colors.textPrimary),
            ),
            const SizedBox(height: DsSpacing.sm),
            Text(
              'Modifiez ou effacez les filtres.',
              style: DsTypography.body.copyWith(color: colors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

Future<bool> deleteConcertWithConfirmation(
  BuildContext context,
  WidgetRef ref,
  Concert concert,
) async {
  final isDraft = concert.maraudeStatus == MaraudeStatus.draft;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Supprimer la maraude ?'),
      content: Text(
        'La maraude « ${concert.artist} », ses volontaires, sa collecte, '
        'sa distribution et son bilan seront définitivement supprimés.'
        '${isDraft ? '' : '\n\nCette maraude n’est pas un brouillon : '
              'les crédits déjà attribués aux bénévoles qui l’ont réalisée '
              'seront retirés. Si un bénévole avait déjà utilisé un de ces '
              'crédits pour une invitation confirmée, son solde de '
              'crédits passera en négatif à rattraper.'}',
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
      ).showSnackBar(const SnackBar(content: Text('Maraude supprimée.')));
    }
    return true;
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            describeError(
              error,
              'Impossible de supprimer la maraude. Veuillez réessayer.',
            ),
          ),
        ),
      );
    }
    return false;
  }
}

class _CardInformation extends StatelessWidget {
  const _CardInformation({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<DsTokens>()!.colors;
    return Row(
      children: [
        Icon(icon, size: 18, color: colors.textSecondary),
        const SizedBox(width: DsSpacing.sm),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: DsTypography.caption.copyWith(
              color: colors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
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
    final colors = Theme.of(context).extension<DsTokens>()!.colors;
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: DsTypography.caption.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: DsTypography.body.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

enum _ConcertAction { edit, delete }

MaraudeCalendarItem _concertCalendarItem(Concert concert) {
  final (label, tone) = _concertCalendarStatus(concert);
  return MaraudeCalendarItem(
    id: concert.id,
    artist: concert.artist,
    date: concert.date,
    time: concert.time,
    venueName: concert.venueName ?? 'Salle non renseignée',
    selectedVolunteerCount: concert.selectedVolunteerCount,
    statusLabel: label,
    tone: tone,
  );
}

(String, MaraudeCalendarTone) _concertCalendarStatus(Concert concert) {
  if (concert.status == ConcertStatus.cancelled) {
    return ('Annulé', MaraudeCalendarTone.error);
  }
  if (concert.maraudeStatus == MaraudeStatus.completed ||
      concert.status == ConcertStatus.completed) {
    return ('Terminé', MaraudeCalendarTone.neutral);
  }
  if (concert.maraudeStatus == MaraudeStatus.inProgress) {
    return ('En cours', MaraudeCalendarTone.primary);
  }
  if (concert.selectedVolunteerCount >= 4) {
    return ('Préparation · Équipe complète', MaraudeCalendarTone.green);
  }
  return ('Préparation · Équipe incomplète', MaraudeCalendarTone.tertiary);
}

DsChipStatus _chipStatusFor(MaraudeCalendarTone tone) => switch (tone) {
  MaraudeCalendarTone.error => DsChipStatus.cancelled,
  MaraudeCalendarTone.neutral => DsChipStatus.completed,
  MaraudeCalendarTone.primary => DsChipStatus.active,
  MaraudeCalendarTone.green => DsChipStatus.completed,
  MaraudeCalendarTone.tertiary => DsChipStatus.pending,
  MaraudeCalendarTone.blue => DsChipStatus.active,
  MaraudeCalendarTone.orange => DsChipStatus.pending,
};

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

String _concertStatusLabel(ConcertStatus status) {
  return switch (status) {
    ConcertStatus.planned => 'Planifié',
    ConcertStatus.confirmed => 'Confirmé',
    ConcertStatus.completed => 'Terminé',
    ConcertStatus.cancelled => 'Annulé',
  };
}

String _volunteerCountLabel(int count) {
  return '$count ${count > 1 ? 'bénévoles' : 'bénévole'}';
}

String _normalize(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp('[àáâäãå]'), 'a')
      .replaceAll(RegExp('[ç]'), 'c')
      .replaceAll(RegExp('[èéêë]'), 'e')
      .replaceAll(RegExp('[ìíîï]'), 'i')
      .replaceAll(RegExp('[ñ]'), 'n')
      .replaceAll(RegExp('[òóôöõ]'), 'o')
      .replaceAll(RegExp('[ùúûü]'), 'u')
      .replaceAll(RegExp('[ýÿ]'), 'y')
      .replaceAll('œ', 'oe');
}

bool _contains(String? value, String query) {
  return query.isEmpty || _normalize(value ?? '').contains(query);
}

String _errorMessage(Object error) {
  return 'Une erreur est survenue lors du chargement des maraudes.';
}
