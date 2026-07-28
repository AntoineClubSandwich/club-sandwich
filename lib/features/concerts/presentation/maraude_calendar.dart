import 'package:club_sandwich/features/concerts/data/concert_providers.dart';
import 'package:club_sandwich/features/concerts/presentation/concert_formatters.dart';
import 'package:flutter/material.dart';

enum MaraudeCalendarTone {
  blue,
  orange,
  green,
  primary,
  tertiary,
  neutral,
  error,
}

class MaraudeViewToolbar extends StatelessWidget {
  const MaraudeViewToolbar({
    required this.title,
    required this.viewMode,
    required this.onViewChanged,
    required this.selectorKey,
    super.key,
  });

  final String title;
  final ConcertViewMode viewMode;
  final ValueChanged<ConcertViewMode> onViewChanged;
  final Key selectorKey;

  @override
  Widget build(BuildContext context) {
    final titleWidget = Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
    );
    final selector = SegmentedButton<ConcertViewMode>(
      key: selectorKey,
      segments: const [
        ButtonSegment(
          value: ConcertViewMode.list,
          icon: Icon(Icons.view_list_outlined),
          label: Text('Liste'),
        ),
        ButtonSegment(
          value: ConcertViewMode.agenda,
          icon: Icon(Icons.calendar_month_outlined),
          label: Text('Calendrier'),
        ),
      ],
      selected: {viewMode},
      onSelectionChanged: (selection) => onViewChanged(selection.single),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 520) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                titleWidget,
                const SizedBox(height: 12),
                Align(alignment: Alignment.centerRight, child: selector),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: titleWidget),
              selector,
            ],
          );
        },
      ),
    );
  }
}

class MaraudeCalendarItem {
  const MaraudeCalendarItem({
    required this.id,
    required this.artist,
    required this.date,
    required this.venueName,
    required this.selectedVolunteerCount,
    required this.statusLabel,
    required this.tone,
    this.time,
  });

  final String id;
  final String artist;
  final DateTime date;
  final String? time;
  final String venueName;
  final int selectedVolunteerCount;
  final String statusLabel;
  final MaraudeCalendarTone tone;
}

class MaraudeCalendar extends StatelessWidget {
  const MaraudeCalendar({
    required this.month,
    required this.items,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onToday,
    required this.onOpen,
    super.key,
  });

  final DateTime month;
  final List<MaraudeCalendarItem> items;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final VoidCallback onToday;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 700) {
          return _MobileMaraudeCalendar(
            items: _sortChronologically(items),
            onOpen: onOpen,
          );
        }
        return _MonthMaraudeCalendar(
          month: month,
          items: items,
          onPreviousMonth: onPreviousMonth,
          onNextMonth: onNextMonth,
          onToday: onToday,
          onOpen: onOpen,
        );
      },
    );
  }
}

class _MonthMaraudeCalendar extends StatelessWidget {
  const _MonthMaraudeCalendar({
    required this.month,
    required this.items,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onToday,
    required this.onOpen,
  });

  final DateTime month;
  final List<MaraudeCalendarItem> items;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final VoidCallback onToday;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(month.year, month.month);
    final gridStart = firstDay.subtract(Duration(days: firstDay.weekday - 1));
    final itemsByDay = <DateTime, List<MaraudeCalendarItem>>{};
    for (final item in items) {
      itemsByDay.putIfAbsent(_dateOnly(item.date), () => []).add(item);
    }
    for (final values in itemsByDay.values) {
      values.sort(_compareTime);
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
            return _CalendarDay(
              day: day,
              isCurrentMonth: day.month == month.month,
              items: itemsByDay[_dateOnly(day)] ?? const [],
              onOpen: onOpen,
            );
          },
        ),
      ],
    );
  }
}

class _CalendarDay extends StatelessWidget {
  const _CalendarDay({
    required this.day,
    required this.isCurrentMonth,
    required this.items,
    required this.onOpen,
  });

  final DateTime day;
  final bool isCurrentMonth;
  final List<MaraudeCalendarItem> items;
  final ValueChanged<String> onOpen;

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
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 4),
                itemBuilder: (context, index) =>
                    _CalendarTile(item: items[index], onOpen: onOpen),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CalendarTile extends StatelessWidget {
  const _CalendarTile({required this.item, required this.onOpen});

  final MaraudeCalendarItem item;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final color = _toneColor(context, item.tone);
    final details = [
      item.artist,
      item.venueName,
      formatLongFrenchDate(item.date),
      if (item.time != null) formatDatabaseTime(item.time!),
      '${item.selectedVolunteerCount} bénévoles',
      item.statusLabel,
    ].join('\n');
    return Tooltip(
      message: details,
      waitDuration: const Duration(milliseconds: 350),
      child: Material(
        key: ValueKey('calendar-item-surface-${item.id}'),
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('agenda-concert-${item.id}'),
          onTap: () => onOpen(item.id),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  item.venueName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11),
                ),
                Text(
                  item.time == null
                      ? 'Heure non renseignée'
                      : formatDatabaseTime(item.time!),
                  style: const TextStyle(fontSize: 11),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        item.statusLabel,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                  ],
                ),
                Text(
                  '${item.selectedVolunteerCount}/4 bénévoles',
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

class _MobileMaraudeCalendar extends StatelessWidget {
  const _MobileMaraudeCalendar({required this.items, required this.onOpen});

  final List<MaraudeCalendarItem> items;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final grouped = <DateTime, List<MaraudeCalendarItem>>{};
    for (final item in items) {
      grouped.putIfAbsent(_dateOnly(item.date), () => []).add(item);
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
          for (final item in entry.value)
            _MobileCalendarCard(item: item, onOpen: onOpen),
        ],
      ],
    );
  }
}

class _MobileCalendarCard extends StatelessWidget {
  const _MobileCalendarCard({required this.item, required this.onOpen});

  final MaraudeCalendarItem item;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final color = _toneColor(context, item.tone);
    return Card(
      child: InkWell(
        key: ValueKey('mobile-agenda-concert-${item.id}'),
        onTap: () => onOpen(item.id),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 64,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.artist,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(item.venueName),
                    const SizedBox(height: 4),
                    Text(
                      '${item.time == null ? 'Heure non renseignée' : formatDatabaseTime(item.time!)}'
                      ' · ${item.selectedVolunteerCount}/4 bénévoles',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      item.statusLabel,
                      style: Theme.of(
                        context,
                      ).textTheme.labelMedium?.copyWith(color: color),
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

Color _toneColor(BuildContext context, MaraudeCalendarTone tone) {
  final colors = Theme.of(context).colorScheme;
  return switch (tone) {
    MaraudeCalendarTone.blue => Colors.blue,
    MaraudeCalendarTone.orange => Colors.orange,
    MaraudeCalendarTone.green => Colors.green,
    MaraudeCalendarTone.primary => colors.primary,
    MaraudeCalendarTone.tertiary => colors.tertiary,
    MaraudeCalendarTone.neutral => colors.onSurfaceVariant,
    MaraudeCalendarTone.error => colors.error,
  };
}

List<MaraudeCalendarItem> _sortChronologically(
  List<MaraudeCalendarItem> items,
) {
  final sorted = List<MaraudeCalendarItem>.of(items);
  sorted.sort((left, right) {
    final date = left.date.compareTo(right.date);
    return date == 0 ? _compareTime(left, right) : date;
  });
  return sorted;
}

int _compareTime(MaraudeCalendarItem left, MaraudeCalendarItem right) {
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
