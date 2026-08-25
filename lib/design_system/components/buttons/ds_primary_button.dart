import 'package:flutter/material.dart';

import '../../tokens/ds_motion.dart';
import '../../tokens/ds_radius.dart';
import '../../tokens/ds_shadows.dart';
import '../../tokens/ds_spacing.dart';
import '../../tokens/ds_tokens.dart';
import '../../tokens/ds_typography.dart';
import '../ds_pressable.dart';

/// The design system's primary call-to-action button — filled with
/// `colors.primary`, the highest-emphasis action on a screen.
class DsPrimaryButton extends StatelessWidget {
  const DsPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool isFullWidth;

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
            ? colors.primaryDisabled
            : state.pressed
            ? colors.primaryPressed
            : state.hovered
            ? colors.primaryHover
            : colors.primary;

        final shadow = enabled
            ? DsShadows.accent(colors.primary)
            : const <BoxShadow>[];

        return DsPressScale(
          pressed: state.pressed && enabled,
          child: AnimatedContainer(
            duration: DsMotion.standard,
            curve: DsMotion.curve,
            width: isFullWidth ? double.infinity : null,
            padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
            height: 48,
            alignment: isFullWidth ? Alignment.center : null,
            decoration: BoxDecoration(
              color: background,
              borderRadius: DsRadius.mdRadius,
              boxShadow: state.pressed || !enabled ? const [] : shadow,
            ),
            child: Row(
              mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedSwitcher(
                  duration: DsMotion.standard,
                  child: isLoading
                      ? SizedBox(
                          key: const ValueKey('loading'),
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colors.textOnColor,
                          ),
                        )
                      : icon != null
                      ? Icon(
                          icon,
                          key: const ValueKey('icon'),
                          size: 18,
                          color: colors.textOnColor,
                        )
                      : const SizedBox.shrink(key: ValueKey('no-icon')),
                ),
                if (isLoading || icon != null)
                  const SizedBox(width: DsSpacing.sm),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: DsTypography.body.copyWith(
                      color: colors.textOnColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
