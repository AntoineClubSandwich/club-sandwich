import 'package:flutter/material.dart';

import '../../tokens/ds_borders.dart';
import '../../tokens/ds_motion.dart';
import '../../tokens/ds_radius.dart';
import '../../tokens/ds_spacing.dart';
import '../../tokens/ds_tokens.dart';
import '../../tokens/ds_typography.dart';
import '../ds_pressable.dart';

/// A togglable filter pill — e.g. a status/category filter above a list.
/// [count], when set, renders a small number after the label (how many
/// items match this filter).
class DsFilterChip extends StatelessWidget {
  const DsFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
    this.count,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<DsTokens>()!;
    final colors = tokens.colors;

    return DsPressable(
      onTap: () => onSelected(!selected),
      builder: (context, state) {
        final Color background = selected
            ? colors.primarySelectedBg
            : (state.hovered ? colors.neutralHoverOverlay : colors.surface);
        final Color foreground = selected
            ? colors.primary
            : colors.textSecondary;
        final Color border = selected ? colors.primary : colors.border;

        return AnimatedContainer(
          duration: DsMotion.standard,
          curve: DsMotion.curve,
          padding: const EdgeInsets.symmetric(
            horizontal: DsSpacing.md,
            vertical: DsSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: background,
            borderRadius: DsRadius.pillRadius,
            border: Border.all(color: border, width: DsBorders.hairline),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: DsTypography.caption.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (count != null) ...[
                const SizedBox(width: DsSpacing.xs),
                Text(
                  '$count',
                  style: DsTypography.caption.copyWith(
                    color: foreground.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
