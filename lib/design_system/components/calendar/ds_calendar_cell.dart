import 'package:flutter/material.dart';

import '../../tokens/ds_borders.dart';
import '../../tokens/ds_motion.dart';
import '../../tokens/ds_radius.dart';
import '../../tokens/ds_tokens.dart';
import '../../tokens/ds_typography.dart';
import '../ds_pressable.dart';

enum DsCalendarCellState {
  normal,
  today,
  selected,
  hasEvent,
  disabled,
  weekend,
}

/// A single day cell in a calendar grid.
class DsCalendarCell extends StatelessWidget {
  const DsCalendarCell({
    super.key,
    required this.day,
    this.state = DsCalendarCellState.normal,
    this.onTap,
  });

  final int day;
  final DsCalendarCellState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<DsTokens>()!;
    final colors = tokens.colors;
    final disabled = state == DsCalendarCellState.disabled;
    final selected = state == DsCalendarCellState.selected;
    final today = state == DsCalendarCellState.today;
    final weekend = state == DsCalendarCellState.weekend;
    final hasEvent = state == DsCalendarCellState.hasEvent;

    return DsPressable(
      enabled: !disabled,
      onTap: onTap,
      builder: (context, interaction) {
        final Color background = selected
            ? colors.primary
            : interaction.hovered
            ? colors.neutralHoverOverlay
            : weekend
            ? colors.canvas
            : Colors.transparent;
        final Color foreground = disabled
            ? colors.textDisabled
            : selected
            ? colors.textOnColor
            : colors.textPrimary;

        return AnimatedContainer(
          duration: DsMotion.standard,
          curve: DsMotion.curve,
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: background,
            borderRadius: DsRadius.smRadius,
            border: today && !selected
                ? Border.all(color: colors.primary, width: DsBorders.standard)
                : null,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Text(
                '$day',
                style: DsTypography.caption.copyWith(
                  color: foreground,
                  fontSize: 13,
                  fontWeight: today || selected
                      ? FontWeight.w700
                      : FontWeight.w500,
                ),
              ),
              if (hasEvent)
                Positioned(
                  bottom: 3,
                  child: Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.info,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
