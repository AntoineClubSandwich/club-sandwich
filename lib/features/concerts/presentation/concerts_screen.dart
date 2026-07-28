import 'package:club_sandwich/features/concerts/data/concert_providers.dart';
import 'package:club_sandwich/features/concerts/domain/concert.dart';
import 'package:club_sandwich/features/concerts/presentation/concert_form.dart';
import 'package:club_sandwich/features/concerts/presentation/concert_formatters.dart';
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
  final _producerFilterController = TextEditingController();
  final _promoterFilterController = TextEditingController();
  ConcertStatus? _concertStatusFilter;
  MaraudeStatus? _maraudeStatusFilter;
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
    _producerFilterController.dispose();
    _promoterFilterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncConcerts = ref.watch(concertsProvider);
    final viewMode = ref.watch(concertViewModeProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          _PageToolbar(
            viewMode: viewMode,
            onViewChanged: (mode) =>
                ref.read(concertViewModeProvider.notifier).select(mode),
          ),
          Expanded(
            child: asyncConcerts.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => _ConcertsError(
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
                            producerController: _producerFilterController,
                            promoterController: _promoterFilterController,
                            concertStatus: _concertStatusFilter,
                            maraudeStatus: _maraudeStatusFilter,
                            onTextChanged: (_) => setState(() {}),
                            onConcertStatusChanged: (value) =>
                                setState(() => _concertStatusFilter = value),
                            onMaraudeStatusChanged: (value) =>
                                setState(() => _maraudeStatusFilter = value),
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
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                          sliver: SliverToBoxAdapter(
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                if (constraints.maxWidth < 700) {
                                  return _MobileAgenda(
                                    concerts: _sortChronologically(filtered),
                                  );
                                }
                                return _MonthAgenda(
                                  month: _displayedMonth,
                                  concerts: filtered,
                                  onPreviousMonth: () => _changeMonth(-1),
                                  onNextMonth: () => _changeMonth(1),
                                  onToday: _goToCurrentMonth,
                                );
                              },
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createConcert(context),
        icon: const Icon(Icons.add),
        label: const Text('Nouvelle maraude'),
      ),
    );
  }

  List<Concert> _filterConcerts(List<Concert> items) {
    final artist = _normalize(_artistFilterController.text);
    final venue = _normalize(_venueFilterController.text);
    final producer = _normalize(_producerFilterController.text);
    final promoter = _normalize(_promoterFilterController.text);
    return items
        .where((concert) {
          return _contains(concert.artist, artist) &&
              _contains(concert.venueName, venue) &&
              _contains(concert.promoterOrganizationName, producer) &&
              _contains(concert.promoterContactName, promoter) &&
              (_concertStatusFilter == null ||
                  concert.status == _concertStatusFilter) &&
              (_maraudeStatusFilter == null ||
                  concert.maraudeStatus == _maraudeStatusFilter);
        })
        .toList(growable: false);
  }

  void _clearFilters() {
    _artistFilterController.clear();
    _venueFilterController.clear();
    _producerFilterController.clear();
    _promoterFilterController.clear();
    setState(() {
      _concertStatusFilter = null;
      _maraudeStatusFilter = null;
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
    final created = await showDialog<bool>(
      context: context,
      builder: (context) => ConcertForm(
        onSubmit: (draft) =>
            ref.read(concertRepositoryProvider).createConcert(draft),
      ),
    );
    if (created != true || !context.mounted) return;

    ref.invalidate(concertsProvider);
    ref.invalidate(maraudeOverviewProvider);
    await ref.read(concertsProvider.future);
    if (!context.mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Concert créé.')));
  }
}

class _PageToolbar extends StatelessWidget {
  const _PageToolbar({required this.viewMode, required this.onViewChanged});

  final ConcertViewMode viewMode;
  final ValueChanged<ConcertViewMode> onViewChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Maraudes',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          SegmentedButton<ConcertViewMode>(
            key: const ValueKey('concert-view-selector'),
            segments: const [
              ButtonSegment(
                value: ConcertViewMode.list,
                icon: Icon(Icons.view_list_outlined),
                label: Text('Liste'),
              ),
              ButtonSegment(
                value: ConcertViewMode.agenda,
                icon: Icon(Icons.calendar_month_outlined),
                label: Text('Agenda'),
              ),
            ],
            selected: {viewMode},
            onSelectionChanged: (selection) => onViewChanged(selection.single),
          ),
        ],
      ),
    );
  }
}

class _ConcertFilters extends StatelessWidget {
  const _ConcertFilters({
    required this.artistController,
    required this.venueController,
    required this.producerController,
    required this.promoterController,
    required this.concertStatus,
    required this.maraudeStatus,
    required this.onTextChanged,
    required this.onConcertStatusChanged,
    required this.onMaraudeStatusChanged,
    required this.onClear,
  });

  final TextEditingController artistController;
  final TextEditingController venueController;
  final TextEditingController producerController;
  final TextEditingController promoterController;
  final ConcertStatus? concertStatus;
  final MaraudeStatus? maraudeStatus;
  final ValueChanged<String> onTextChanged;
  final ValueChanged<ConcertStatus?> onConcertStatusChanged;
  final ValueChanged<MaraudeStatus?> onMaraudeStatusChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        key: const ValueKey('concert-filters'),
        leading: const Icon(Icons.filter_list),
        title: const Text('Filtres'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
                  _FilterTextField(
                    width: fieldWidth,
                    keyValue: 'concert-filter-artist',
                    controller: artistController,
                    label: 'Artiste',
                    onChanged: onTextChanged,
                  ),
                  _FilterTextField(
                    width: fieldWidth,
                    keyValue: 'concert-filter-venue',
                    controller: venueController,
                    label: 'Salle',
                    onChanged: onTextChanged,
                  ),
                  _FilterTextField(
                    width: fieldWidth,
                    keyValue: 'concert-filter-producer',
                    controller: producerController,
                    label: 'Producteur',
                    onChanged: onTextChanged,
                  ),
                  _FilterTextField(
                    width: fieldWidth,
                    keyValue: 'concert-filter-promoter',
                    controller: promoterController,
                    label: 'Tourneur',
                    onChanged: onTextChanged,
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: DropdownButtonFormField<ConcertStatus?>(
                      key: const ValueKey('concert-filter-status'),
                      initialValue: concertStatus,
                      decoration: const InputDecoration(
                        labelText: 'Statut concert',
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('Tous'),
                        ),
                        for (final status in ConcertStatus.values)
                          DropdownMenuItem(
                            value: status,
                            child: Text(_concertStatusLabel(status)),
                          ),
                      ],
                      onChanged: onConcertStatusChanged,
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: DropdownButtonFormField<MaraudeStatus?>(
                      key: const ValueKey('concert-filter-maraude'),
                      initialValue: maraudeStatus,
                      decoration: const InputDecoration(
                        labelText: 'Statut maraude',
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('Tous'),
                        ),
                        for (final status in MaraudeStatus.values)
                          DropdownMenuItem(
                            value: status,
                            child: Text(status.label),
                          ),
                      ],
                      onChanged: onMaraudeStatusChanged,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.filter_alt_off_outlined),
              label: const Text('Effacer les filtres'),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterTextField extends StatelessWidget {
  const _FilterTextField({
    required this.width,
    required this.keyValue,
    required this.controller,
    required this.label,
    required this.onChanged,
  });

  final double width;
  final String keyValue;
  final TextEditingController controller;
  final String label;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: TextField(
        key: ValueKey(keyValue),
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.search),
        ),
        onChanged: onChanged,
      ),
    );
  }
}

class _ConcertListSliver extends StatelessWidget {
  const _ConcertListSliver({required this.concerts});

  final List<Concert> concerts;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
      sliver: SliverLayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.crossAxisExtent;
          final columns = width >= 900 ? 2 : 1;
          return SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              mainAxisExtent: 290,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => _ConcertCard(concert: concerts[index]),
              childCount: concerts.length,
            ),
          );
        },
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
        key: ValueKey('concert-card-${concert.id}'),
        onTap: () => context.go('/maraudes/${concert.id}'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 8, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      concert.artist,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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
                          deleteConcertWithConfirmation(context, ref, concert);
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
              const Spacer(),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Wrap(
                spacing: 24,
                runSpacing: 8,
                children: [
                  _Metadata(
                    label: 'Producteur',
                    value: concert.promoterOrganizationName ?? '—',
                  ),
                  _Metadata(
                    label: 'Équipe',
                    value: _volunteerCountLabel(concert.selectedVolunteerCount),
                  ),
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
      builder: (context) => ConcertForm(
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
}

class _MonthAgenda extends StatelessWidget {
  const _MonthAgenda({
    required this.month,
    required this.concerts,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onToday,
  });

  final DateTime month;
  final List<Concert> concerts;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(month.year, month.month);
    final gridStart = firstDay.subtract(Duration(days: firstDay.weekday - 1));
    final concertsByDay = <DateTime, List<Concert>>{};
    for (final concert in concerts) {
      final day = _dateOnly(concert.date);
      concertsByDay.putIfAbsent(day, () => []).add(concert);
    }
    for (final values in concertsByDay.values) {
      values.sort(_compareConcertTime);
    }

    return Column(
      key: const ValueKey('month-agenda'),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                IconButton(
                  key: const ValueKey('agenda-previous-month'),
                  tooltip: 'Mois précédent',
                  onPressed: onPreviousMonth,
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    _monthLabel(month),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onToday,
                  child: const Text('Aujourd’hui'),
                ),
                IconButton(
                  key: const ValueKey('agenda-next-month'),
                  tooltip: 'Mois suivant',
                  onPressed: onNextMonth,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final label in [
              'Lun',
              'Mar',
              'Mer',
              'Jeu',
              'Ven',
              'Sam',
              'Dim',
            ])
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
          ],
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
            mainAxisExtent: 182,
          ),
          itemCount: 42,
          itemBuilder: (context, index) {
            final day = gridStart.add(Duration(days: index));
            return _AgendaDay(
              day: day,
              isCurrentMonth: day.month == month.month,
              concerts: concertsByDay[_dateOnly(day)] ?? const [],
            );
          },
        ),
      ],
    );
  }
}

class _AgendaDay extends StatelessWidget {
  const _AgendaDay({
    required this.day,
    required this.isCurrentMonth,
    required this.concerts,
  });

  final DateTime day;
  final bool isCurrentMonth;
  final List<Concert> concerts;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isToday = _isSameDay(day, DateTime.now());
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isCurrentMonth
            ? colors.surfaceContainerLowest
            : colors.surfaceContainerLow,
        border: Border.all(
          color: isToday ? colors.primary : colors.outlineVariant,
          width: isToday ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${day.day}',
              style: TextStyle(
                fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                color: isCurrentMonth
                    ? colors.onSurface
                    : colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 3),
            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.zero,
                itemCount: concerts.length,
                separatorBuilder: (_, _) => const SizedBox(height: 4),
                itemBuilder: (context, index) =>
                    _AgendaConcertTile(concert: concerts[index]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AgendaConcertTile extends StatelessWidget {
  const _AgendaConcertTile({required this.concert});

  final Concert concert;

  @override
  Widget build(BuildContext context) {
    final indicator = _agendaIndicator(context, concert);
    final details = [
      concert.artist,
      concert.venueName ?? 'Salle non renseignée',
      formatLongFrenchDate(concert.date),
      if (concert.time != null) formatDatabaseTime(concert.time!),
      '${concert.selectedVolunteerCount} bénévoles',
      indicator.label,
    ].join('\n');
    return Tooltip(
      message: details,
      waitDuration: const Duration(milliseconds: 350),
      child: Material(
        color: indicator.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('agenda-concert-${concert.id}'),
          onTap: () => context.go('/maraudes/${concert.id}'),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  concert.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  concert.venueName ?? '—',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11),
                ),
                Text(
                  concert.time == null
                      ? 'Heure non renseignée'
                      : formatDatabaseTime(concert.time!),
                  style: const TextStyle(fontSize: 11),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: indicator.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        indicator.label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                  ],
                ),
                Text(
                  '${concert.selectedVolunteerCount}/4 bénévoles',
                  style: const TextStyle(fontSize: 10),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MobileAgenda extends StatelessWidget {
  const _MobileAgenda({required this.concerts});

  final List<Concert> concerts;

  @override
  Widget build(BuildContext context) {
    final grouped = <DateTime, List<Concert>>{};
    for (final concert in concerts) {
      grouped.putIfAbsent(_dateOnly(concert.date), () => []).add(concert);
    }
    return Column(
      key: const ValueKey('mobile-agenda'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final entry in grouped.entries) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
            child: Text(
              _relativeDateLabel(entry.key),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          for (final concert in entry.value)
            _MobileAgendaCard(concert: concert),
        ],
      ],
    );
  }
}

class _MobileAgendaCard extends StatelessWidget {
  const _MobileAgendaCard({required this.concert});

  final Concert concert;

  @override
  Widget build(BuildContext context) {
    final indicator = _agendaIndicator(context, concert);
    return Card(
      child: InkWell(
        key: ValueKey('mobile-agenda-concert-${concert.id}'),
        onTap: () => context.go('/maraudes/${concert.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 64,
                decoration: BoxDecoration(
                  color: indicator.color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      concert.artist,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(concert.venueName ?? '—'),
                    const SizedBox(height: 4),
                    Text(
                      '${concert.time == null ? 'Heure non renseignée' : formatDatabaseTime(concert.time!)}'
                      ' · ${concert.selectedVolunteerCount}/4 bénévoles',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      indicator.label,
                      style: Theme.of(
                        context,
                      ).textTheme.labelMedium?.copyWith(color: indicator.color),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyConcerts extends StatelessWidget {
  const _EmptyConcerts({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.music_note_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 20),
            Text(
              'Aucune maraude',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text('Ouvrez votre première maraude.'),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: const Text('Ouvrir une maraude'),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_outlined,
              size: 56,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Aucun résultat',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text('Modifiez ou effacez les filtres.'),
          ],
        ),
      ),
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
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: onRetry,
              child: const Text('Réessayer'),
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
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Supprimer la maraude ?'),
      content: Text(
        'La maraude « ${concert.artist} », ses candidatures, sa collecte, '
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
        Expanded(
          child: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis),
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

class _AgendaIndicator {
  const _AgendaIndicator(this.label, this.color);

  final String label;
  final Color color;
}

_AgendaIndicator _agendaIndicator(BuildContext context, Concert concert) {
  final colors = Theme.of(context).colorScheme;
  if (concert.status == ConcertStatus.cancelled) {
    return _AgendaIndicator('Annulé', colors.error);
  }
  if (concert.maraudeStatus == MaraudeStatus.completed ||
      concert.status == ConcertStatus.completed) {
    return _AgendaIndicator('Terminé', colors.onSurface);
  }
  if (concert.maraudeStatus == MaraudeStatus.inProgress) {
    return _AgendaIndicator('En cours', colors.primary);
  }
  if (concert.selectedVolunteerCount >= 4) {
    return _AgendaIndicator('Préparation · Équipe complète', Colors.green);
  }
  return _AgendaIndicator('Préparation · Équipe incomplète', colors.tertiary);
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

List<Concert> _sortChronologically(List<Concert> concerts) {
  final sorted = List<Concert>.of(concerts);
  sorted.sort((left, right) {
    final date = left.date.compareTo(right.date);
    return date == 0 ? _compareConcertTime(left, right) : date;
  });
  return sorted;
}

int _compareConcertTime(Concert left, Concert right) {
  return (left.time ?? '').compareTo(right.time ?? '');
}

DateTime _dateOnly(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}

bool _isSameDay(DateTime left, DateTime right) {
  return left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}

String _relativeDateLabel(DateTime date) {
  final today = _dateOnly(DateTime.now());
  if (_isSameDay(date, today)) return 'Aujourd’hui';
  if (_isSameDay(date, today.add(const Duration(days: 1)))) return 'Demain';
  return formatLongFrenchDate(date);
}

String _monthLabel(DateTime month) {
  const months = [
    'janvier',
    'février',
    'mars',
    'avril',
    'mai',
    'juin',
    'juillet',
    'août',
    'septembre',
    'octobre',
    'novembre',
    'décembre',
  ];
  return '${months[month.month - 1]} ${month.year}';
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

void _showError(BuildContext context, Object error) {
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(_errorMessage(error))));
}
