import 'package:flutter/material.dart';

import '../../tokens/ds_colors.dart';
import '../../tokens/ds_motion.dart';
import '../../tokens/ds_radius.dart';
import '../../tokens/ds_spacing.dart';
import '../../tokens/ds_tokens.dart';
import '../../tokens/ds_typography.dart';
import '../ds_pressable.dart';

class DsNavigationRailItem {
  const DsNavigationRailItem({
    required this.label,
    required this.icon,
    this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData? selectedIcon;
}

/// A vertical navigation rail. **Style-guide showcase only** — it does
/// not replace the real `NavigationRail` driving `AppShell`'s navigation
/// (`lib/shared/widgets/app_shell.dart`); it exists so the visual
/// treatment (selection pill, spacing, iconography) can be reviewed and
/// eventually adopted there in a future screen-by-screen redesign.
class DsNavigationRail extends StatelessWidget {
  const DsNavigationRail({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<DsNavigationRailItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<DsTokens>()!;
    final colors = tokens.colors;

    return Container(
      width: 240,
      color: colors.surface,
      padding: const EdgeInsets.symmetric(
        horizontal: DsSpacing.md,
        vertical: DsSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(height: DsSpacing.xs),
            _buildItem(context, colors, items[i], i == selectedIndex, i),
          ],
        ],
      ),
    );
  }

  Widget _buildItem(
    BuildContext context,
    DsColorTokens colors,
    DsNavigationRailItem item,
    bool selected,
    int index,
  ) {
    return DsPressable(
      onTap: () => onSelected(index),
      builder: (context, state) {
        final Color background = selected
            ? colors.primarySelectedBg
            : state.hovered
            ? colors.neutralHoverOverlay
            : Colors.transparent;
        final Color foreground = selected
            ? colors.primary
            : colors.textSecondary;

        return AnimatedContainer(
          duration: DsMotion.standard,
          curve: DsMotion.curve,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: DsSpacing.md,
            vertical: DsSpacing.sm + 2,
          ),
          decoration: BoxDecoration(
            color: background,
            borderRadius: DsRadius.lgRadius,
          ),
          child: Row(
            children: [
              Icon(
                selected ? (item.selectedIcon ?? item.icon) : item.icon,
                size: 20,
                color: foreground,
              ),
              const SizedBox(width: DsSpacing.md),
              Text(
                item.label,
                style: DsTypography.body.copyWith(
                  color: foreground,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
