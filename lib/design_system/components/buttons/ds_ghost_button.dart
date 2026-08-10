import 'package:flutter/material.dart';

import '../../tokens/ds_motion.dart';
import '../../tokens/ds_radius.dart';
import '../../tokens/ds_spacing.dart';
import '../../tokens/ds_tokens.dart';
import '../../tokens/ds_typography.dart';
import '../ds_pressable.dart';

/// The lowest-emphasis action button — no fill or border at rest, just a
/// soft neutral overlay on hover/press. For secondary/tertiary actions
/// inside cards, toolbars and dialogs.
class DsGhostButton extends StatelessWidget {
  const DsGhostButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<DsTokens>()!;
    final colors = tokens.colors;
    final enabled = onPressed != null && !isLoading;

    return DsPressable(
      enabled: enabled,
      onTap: onPressed,
      builder: (context, state) {
        final Color background = !enabled
            ? Colors.transparent
            : state.pressed
            ? colors.neutralPressedOverlay
            : state.hovered
            ? colors.neutralHoverOverlay
            : Colors.transparent;
        final Color foreground = enabled
            ? colors.textPrimary
            : colors.textDisabled;

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
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: DsMotion.standard,
                child: isLoading
                    ? SizedBox(
                        key: const ValueKey('loading'),
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: foreground,
                        ),
                      )
                    : icon != null
                    ? Icon(
                        icon,
                        key: const ValueKey('icon'),
                        size: 16,
                        color: foreground,
                      )
                    : const SizedBox.shrink(key: ValueKey('no-icon')),
              ),
              if (isLoading || icon != null)
                const SizedBox(width: DsSpacing.xs),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: DsTypography.body.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w600,
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
