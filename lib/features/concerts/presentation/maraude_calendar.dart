import 'package:club_sandwich/design_system/components/ds_pressable.dart';
import 'package:club_sandwich/design_system/components/surfaces/ds_card.dart';
import 'package:club_sandwich/design_system/icons/ds_icons.dart';
import 'package:club_sandwich/design_system/tokens/ds_borders.dart';
import 'package:club_sandwich/design_system/tokens/ds_motion.dart';
import 'package:club_sandwich/design_system/tokens/ds_radius.dart';
import 'package:club_sandwich/design_system/tokens/ds_shadows.dart';
import 'package:club_sandwich/design_system/tokens/ds_spacing.dart';
import 'package:club_sandwich/design_system/tokens/ds_tokens.dart';
import 'package:club_sandwich/design_system/tokens/ds_typography.dart';
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
    final colors = Theme.of(context).extension<DsTokens>()!.colors;
    final titleWidget = Text(
      title.toUpperCase(),
      style: DsTypography.h1.copyWith(color: colors.textPrimary),
    );
    final selector = Container(
      key: selectorKey,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.secondarySelectedBg,
        borderRadius: DsRadius.lgRadius,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ViewModeSegment(
            label: 'Liste',
            icon: DsIcons.layoutDashboard,
            selected: viewMode == ConcertViewMode.list,
            onTap: () => onViewChanged(ConcertViewMode.list),
          ),
          const SizedBox(width: 4),
          _ViewModeSegment(
            label: 'Calendrier',
            icon: DsIcons.calendar,
            selected: viewMode == ConcertViewMode.agenda,
            onTap: () => onViewChanged(ConcertViewMode.agenda),
          ),
        ],
      ),
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

class _ViewModeSegment extends StatelessWidget {
  const _ViewModeSegment({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<DsTokens>()!.colors;
    return DsPressable(
      onTap: onTap,
      builder: (context, state) {
        final background = selected
            ? colors.surface
            : (state.hovered ? colors.neutralHoverOverlay : Colors.transparent);
        final foreground = selected ? colors.primary : colors.textSecondary;
        return AnimatedContainer(
          duration: DsMotion.standard,
          curve: DsMotion.curve,
          padding: const EdgeInsets.symmetric(
            horizontal: DsSpacing.md,
            vertical: DsSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: background,
            borderRadius: DsRadius.smRadius,
            boxShadow: selected ? DsShadows.ambient(colors.textPrimary) : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: foreground),
              const SizedBox(width: DsSpacing.xs),
              Text(
                label,
                style: DsTypography.caption.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        );
      },
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
    this.countLabel = 'bénévoles',
    this.countTarget = 3,
  });

  final String id;
  final String artist;
  final DateTime date;
  final String? time;
  final String venueName;
  final int selectedVolunteerCount;
  final String statusLabel;
  final MaraudeCalendarTone tone;
  final String countLabel;
  final int? countTarget;

  String get countSummary => countTarget == null
      ? '$selectedVolunteerCount $countLabel'
      : '$selectedVolunteerCount/$countTarget $countLabel';
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

    final colors = Theme.of(context).extension<DsTokens>()!.colors;
    return Column(
      key: const ValueKey('month-agenda'),
      children: [
        DsCard(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              IconButton(
                key: const ValueKey('agenda-previous-month'),
                tooltip: 'Mois précédent',
                onPressed: onPreviousMonth,
                icon: Icon(DsIcons.chevronLeft, color: colors.textPrimary),
              ),
              Expanded(
                child: Text(
                  _monthLabel(month),
                  textAlign: TextAlign.center,
                  style: DsTypography.h3.copyWith(color: colors.textPrimary),
                ),
              ),
              TextButton(
                onPressed: onToday,
                child: Text(
                  'Aujourd’hui',
                  style: DsTypography.caption.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                key: const ValueKey('agenda-next-month'),
                tooltip: 'Mois suivant',
                onPressed: onNextMonth,
                icon: Icon(DsIcons.chevronRight, color: colors.textPrimary),
              ),
            ],
          ),
        ),
        const SizedBox(height: DsSpacing.sm),
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
                    style: DsTypography.caption.copyWith(
                      color: colors.textSecondary,
                      fontWeight: FontWeight.w800,
                    ),
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
    final colors = Theme.of(context).extension<DsTokens>()!.colors;
    final isToday = _isSameDay(day, DateTime.now());
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isCurrentMonth ? colors.surface : colors.canvas,
        border: Border.all(
          color: isToday ? colors.primary : colors.border,
          width: isToday ? DsBorders.standard : DsBorders.hairline,
        ),
        borderRadius: DsRadius.smRadius,
      ),
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${day.day}',
              style: DsTypography.caption.copyWith(
                fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
                color: isCurrentMonth
                    ? colors.textPrimary
                    : colors.textDisabled,
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
      '${item.selectedVolunteerCount} ${item.countLabel}',
      item.statusLabel,
    ].join('\n');
    final colors = Theme.of(context).extension<DsTokens>()!.colors;
    return Tooltip(
      message: details,
      waitDuration: const Duration(milliseconds: 350),
      child: Material(
        key: ValueKey('calendar-item-surface-${item.id}'),
        color: color.withValues(alpha: 0.14),
        borderRadius: DsRadius.smRadius,
        clipBehavior: Clip.antiAlias,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: DsRadius.smRadius,
            border: Border.all(color: color, width: DsBorders.hairline),
          ),
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
                    style: DsTypography.caption.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: colors.textPrimary,
                    ),
                  ),
                  Text(
                    item.venueName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DsTypography.caption.copyWith(
                      fontSize: 11,
                      color: colors.textSecondary,
                    ),
                  ),
                  Text(
                    item.time == null
                        ? 'Heure non renseignée'
                        : formatDatabaseTime(item.time!),
                    style: DsTypography.caption.copyWith(
                      fontSize: 11,
                      color: colors.textSecondary,
                    ),
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
                          style: DsTypography.caption.copyWith(
                            fontSize: 10,
                            color: colors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    item.countSummary,
                    style: DsTypography.caption.copyWith(
                      fontSize: 10,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
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
    final colors = Theme.of(context).extension<DsTokens>()!.colors;
    return Column(
      key: const ValueKey('mobile-agenda'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final entry in grouped.entries) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
            child: Text(
              _relativeDateLabel(entry.key),
              style: DsTypography.h3.copyWith(color: colors.textPrimary),
            ),
          ),
          for (final item in entry.value)
            Padding(
              padding: const EdgeInsets.only(bottom: DsSpacing.sm),
              child: _MobileCalendarCard(item: item, onOpen: onOpen),
            ),
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
    final colors = Theme.of(context).extension<DsTokens>()!.colors;
    final color = _toneColor(context, item.tone);
    return DsCard(
      key: ValueKey('mobile-agenda-concert-${item.id}'),
      onTap: () => onOpen(item.id),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 64,
            decoration: BoxDecoration(
              color: color,
              borderRadius: DsRadius.smRadius,
            ),
          ),
          const SizedBox(width: DsSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.artist,
                  style: DsTypography.body.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  item.venueName,
                  style: DsTypography.caption.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.time == null ? 'Heure non renseignée' : formatDatabaseTime(item.time!)}'
                  ' · ${item.countSummary}',
                  style: DsTypography.caption.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                Text(
                  item.statusLabel,
                  style: DsTypography.caption.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Icon(DsIcons.chevronRight, color: colors.textSecondary),
        ],
      ),
    );
  }
}

Color _toneColor(BuildContext context, MaraudeCalendarTone tone) {
  final colors = Theme.of(context).extension<DsTokens>()!.colors;
  return switch (tone) {
    MaraudeCalendarTone.blue => colors.info,
    MaraudeCalendarTone.orange => colors.warning,
    MaraudeCalendarTone.green => colors.success,
    MaraudeCalendarTone.primary => colors.primary,
    MaraudeCalendarTone.tertiary => colors.warning,
    MaraudeCalendarTone.neutral => colors.textSecondary,
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
