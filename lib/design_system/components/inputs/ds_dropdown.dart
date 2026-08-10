import 'package:flutter/material.dart';

import '../../icons/ds_icons.dart';
import '../../tokens/ds_borders.dart';
import '../../tokens/ds_radius.dart';
import '../../tokens/ds_spacing.dart';
import '../../tokens/ds_tokens.dart';
import '../../tokens/ds_typography.dart';

class DsDropdownItem<T> {
  const DsDropdownItem({required this.value, required this.label, this.icon});

  final T value;
  final String label;
  final IconData? icon;
}

/// A dropdown/select field, styled to match [DsTextField] when closed and
/// opening a `colors.surfaceElevated` menu (built on Flutter's
/// `PopupMenuButton` for correct overlay positioning/dismissal — only its
/// visuals are custom).
class DsDropdown<T> extends StatelessWidget {
  const DsDropdown({
    super.key,
    required this.items,
    required this.onChanged,
    this.value,
    this.label,
    this.hintText = 'Sélectionner',
  });

  final List<DsDropdownItem<T>> items;
  final ValueChanged<T> onChanged;
  final T? value;
  final String? label;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<DsTokens>()!;
    final colors = tokens.colors;

    DsDropdownItem<T>? selected;
    for (final item in items) {
      if (item.value == value) {
        selected = item;
        break;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: DsTypography.caption.copyWith(
              color: colors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: DsSpacing.xs),
        ],
        PopupMenuButton<T>(
          initialValue: value,
          onSelected: onChanged,
          color: colors.surfaceElevated,
          elevation: 3,
          shadowColor: Colors.black.withValues(alpha: 0.12),
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: DsRadius.smRadius,
            side: BorderSide(color: colors.border, width: DsBorders.hairline),
          ),
          itemBuilder: (context) => [
            for (final item in items)
              PopupMenuItem<T>(
                value: item.value,
                child: Row(
                  children: [
                    if (item.icon != null) ...[
                      Icon(item.icon, size: 16, color: colors.textSecondary),
                      const SizedBox(width: DsSpacing.sm),
                    ],
                    Text(
                      item.label,
                      style: DsTypography.body.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
          ],
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: DsSpacing.md),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: DsRadius.smRadius,
              border: Border.all(
                color: colors.border,
                width: DsBorders.hairline,
              ),
            ),
            child: Row(
              children: [
                if (selected?.icon != null) ...[
                  Icon(selected!.icon, size: 16, color: colors.textSecondary),
                  const SizedBox(width: DsSpacing.sm),
                ],
                Expanded(
                  child: Text(
                    selected?.label ?? hintText,
                    style: DsTypography.body.copyWith(
                      color: selected != null
                          ? colors.textPrimary
                          : colors.textDisabled,
                    ),
                  ),
                ),
                Icon(
                  DsIcons.chevronDown,
                  size: 18,
                  color: colors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
