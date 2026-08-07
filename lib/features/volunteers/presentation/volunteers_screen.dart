import 'package:club_sandwich/features/auth/application/auth_providers.dart';
import 'package:club_sandwich/features/auth/domain/user_account.dart';
import 'package:club_sandwich/features/concerts/data/concert_providers.dart';
import 'package:club_sandwich/features/concerts/domain/concert.dart';
import 'package:club_sandwich/features/concerts/domain/maraude_operation.dart';
import 'package:club_sandwich/design_system/tokens/ds_theme.dart';
import 'package:club_sandwich/features/concerts/presentation/maraude_calendar.dart';
import 'package:club_sandwich/features/concerts/presentation/maraude_list_section.dart';
import 'package:club_sandwich/features/volunteers/domain/concert_volunteer_application.dart';
import 'package:club_sandwich/features/volunteers/presentation/volunteer_documents_panel.dart';
import 'package:club_sandwich/shared/widgets/app_state_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class VolunteersScreen extends ConsumerStatefulWidget {
  const VolunteersScreen({super.key});

  @override
  ConsumerState<VolunteersScreen> createState() => _VolunteersScreenState();
}

class _VolunteersScreenState extends ConsumerState<VolunteersScreen> {
  late DateTime _displayedMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _displayedMonth = DateTime(now.year, now.month);
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(currentUserContextProvider).value?.role;
    if (role == AppUserRole.admin) {
      return _VolunteerDirectory(
        users: ref.watch(managedUsersProvider),
        onRetry: () => ref.invalidate(managedUsersProvider),
      );
    }
    final overview = ref.watch(maraudeOverviewProvider);
    final viewMode = ref.watch(concertViewModeProvider);
    return Theme(
      data: DsTheme.light,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          children: [
            MaraudeViewToolbar(
              title: 'Mes maraudes',
              viewMode: viewMode,
              onViewChanged: (mode) =>
                  ref.read(concertViewModeProvider.notifier).select(mode),
              selectorKey: const ValueKey('volunteer-view-selector'),
            ),
            Expanded(
              child: overview.when(
                loading: () =>
                    const AppLoadingState(label: 'Chargement des maraudes'),
                error: (_, _) => AppErrorState(
                  message: 'Impossible de charger vos maraudes.',
                  onRetry: () => ref.invalidate(maraudeOverviewProvider),
                ),
                data: (items) => viewMode == ConcertViewMode.list
                    ? _VolunteerMaraudes(items: items)
                    : SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 48),
                        child: MaraudeCalendar(
                          month: _displayedMonth,
                          items: items
                              .map(_volunteerCalendarItem)
                              .toList(growable: false),
                          onPreviousMonth: () => _changeMonth(-1),
                          onNextMonth: () => _changeMonth(1),
                          onToday: _goToCurrentMonth,
                          onOpen: (id) => context.go('/maraudes/$id'),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
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
}

class _VolunteerDirectory extends StatelessWidget {
  const _VolunteerDirectory({required this.users, required this.onRetry});

  final AsyncValue<List<ManagedUser>> users;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.transparent,
    body: users.when(
      loading: () => const AppLoadingState(label: 'Chargement des bénévoles'),
      error: (_, _) => AppErrorState(
        message: 'Impossible de charger les bénévoles.',
        onRetry: onRetry,
      ),
      data: (items) {
        final volunteers = items
            .where((item) => item.role == AppUserRole.volunteer)
            .toList(growable: false);
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 48),
          children: [
            Text(
              'Bénévoles',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 6),
            Text('${volunteers.length} bénévole(s)'),
            const SizedBox(height: 18),
            if (volunteers.isEmpty)
              const AppEmptyState(
                title: 'Aucun bénévole',
                message: 'Aucun compte bénévole n’est enregistré.',
                icon: Icons.groups_outlined,
              )
            else
              for (final volunteer in volunteers)
                Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text(volunteer.displayName.characters.first),
                    ),
                    title: Text(volunteer.displayName),
                    subtitle: Text(
                      '${volunteer.email}\n${volunteer.status.label}',
                    ),
                    isThreeLine: true,
                    trailing: OutlinedButton.icon(
                      onPressed: () => _showDocuments(context, volunteer),
                      icon: const Icon(Icons.folder_outlined),
                      label: const Text('Documents'),
                    ),
                  ),
                ),
          ],
        );
      },
    ),
  );

  void _showDocuments(BuildContext context, ManagedUser volunteer) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => UncontrolledProviderScope(
        container: ProviderScope.containerOf(context),
        child: AlertDialog(
          title: Text('Documents — ${volunteer.displayName}'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: VolunteerDocumentsPanel(userId: volunteer.profileId),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Fermer'),
            ),
          ],
        ),
      ),
    );
  }
}

class _VolunteerMaraudes extends StatelessWidget {
  const _VolunteerMaraudes({required this.items});

  final List<MaraudeOverview> items;

  @override
  Widget build(BuildContext context) {
    final open = items.where((item) => item.isOpenForApplication).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final ownItems = items
        .where((item) => item.ownStatus != null)
        .toList(growable: false);
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final upcoming =
        ownItems
            .where(
              (item) =>
                  !item.date.isBefore(todayDate) &&
                  item.maraudeStatus != MaraudeStatus.completed &&
                  item.maraudeStatus != MaraudeStatus.cancelled &&
                  (item.ownStatus == ConcertVolunteerStatus.pending ||
                      item.ownStatus == ConcertVolunteerStatus.selected),
            )
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));
    final toRegularize =
        ownItems
            .where(
              (item) =>
                  item.date.isBefore(todayDate) &&
                  item.maraudeStatus != MaraudeStatus.completed &&
                  item.maraudeStatus != MaraudeStatus.cancelled &&
                  (item.ownStatus == ConcertVolunteerStatus.pending ||
                      item.ownStatus == ConcertVolunteerStatus.selected),
            )
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));
    final history =
        ownItems
            .where(
              (item) =>
                  item.ownStatus == ConcertVolunteerStatus.notSelected ||
                  item.ownStatus == ConcertVolunteerStatus.withdrawn ||
                  (item.maraudeStatus == MaraudeStatus.completed &&
                      item.ownStatus == ConcertVolunteerStatus.selected),
            )
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 48),
      children: [
        if (open.isEmpty && upcoming.isEmpty && toRegularize.isEmpty)
          const Text('Aucune maraude à venir.'),
        MaraudeListSection(
          title: 'Maraudes ouvertes',
          items: open,
          actionLabel: 'Je me propose',
        ),
        MaraudeListSection(
          title: 'À venir',
          items: upcoming,
          actionLabelFor: (item) => _availabilityLabel(item.ownStatus!),
        ),
        MaraudeListSection(
          title: 'À régulariser',
          items: toRegularize,
          actionLabelFor: (item) => _availabilityLabel(item.ownStatus!),
        ),
        MaraudeListSection(
          title: 'Historique personnel',
          items: history,
          canOpenFor: (item) =>
              item.ownStatus == ConcertVolunteerStatus.selected,
          actionLabelFor: (item) =>
              item.ownStatus == ConcertVolunteerStatus.selected
              ? 'Consulter la maraude'
              : _availabilityLabel(item.ownStatus!),
        ),
      ],
    );
  }
}

String _availabilityLabel(ConcertVolunteerStatus status) {
  return switch (status) {
    ConcertVolunteerStatus.pending => 'Disponibilité transmise',
    ConcertVolunteerStatus.selected => 'Sélectionné',
    ConcertVolunteerStatus.notSelected => 'Non sélectionné',
    ConcertVolunteerStatus.withdrawn => 'Désisté — repositionnement possible',
  };
}

MaraudeCalendarItem _volunteerCalendarItem(MaraudeOverview maraude) {
  final (label, tone) = switch (maraude.ownStatus) {
    ConcertVolunteerStatus.pending => (
      'En attente',
      MaraudeCalendarTone.orange,
    ),
    ConcertVolunteerStatus.selected => (
      'Sélectionné',
      MaraudeCalendarTone.green,
    ),
    ConcertVolunteerStatus.notSelected => (
      'Non sélectionné',
      MaraudeCalendarTone.neutral,
    ),
    ConcertVolunteerStatus.withdrawn => (
      'Désisté',
      MaraudeCalendarTone.neutral,
    ),
    null => ('Ouverte', MaraudeCalendarTone.blue),
  };
  return MaraudeCalendarItem(
    id: maraude.concertId,
    artist: maraude.artist,
    date: maraude.date,
    time: maraude.time,
    venueName: maraude.venueName,
    selectedVolunteerCount: maraude.selectedCount,
    statusLabel: label,
    tone: tone,
  );
}
