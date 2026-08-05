import 'package:flutter/material.dart';

import '../../tokens/ds_motion.dart';
import '../../tokens/ds_radius.dart';
import '../../tokens/ds_spacing.dart';
import '../../tokens/ds_tokens.dart';
import '../../tokens/ds_typography.dart';
import '../ds_pressable.dart';

/// A medium-emphasis action button — outlined in `colors.secondary`
/// (the brand blue) on a transparent/surface background.
class DsSecondaryButton extends StatelessWidget {
  const DsSecondaryButton({
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
        final Color border = !enabled
            ? colors.border
            : state.pressed
            ? colors.secondaryPressed
            : state.hovered
            ? colors.secondaryHover
            : colors.secondary;
        final Color background = enabled && (state.hovered || state.pressed)
            ? colors.secondarySelectedBg
            : colors.surface;
        final Color foreground = enabled
            ? colors.secondary
            : colors.textDisabled;

        return AnimatedScale(
          scale: state.pressed ? 0.97 : 1,
          duration: DsMotion.standard,
          curve: DsMotion.curve,
          child: AnimatedContainer(
            duration: DsMotion.standard,
            curve: DsMotion.curve,
            width: isFullWidth ? double.infinity : null,
            padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
            height: 44,
            alignment: isFullWidth ? Alignment.center : null,
            decoration: BoxDecoration(
              color: background,
              borderRadius: DsRadius.lgRadius,
              border: Border.all(color: border, width: 1.5),
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
                            color: foreground,
                          ),
                        )
                      : icon != null
                      ? Icon(
                          icon,
                          key: const ValueKey('icon'),
                          size: 18,
                          color: foreground,
                        )
                      : const SizedBox.shrink(key: ValueKey('no-icon')),
                ),
                if (isLoading || icon != null)
                  const SizedBox(width: DsSpacing.sm),
                Text(
                  label,
                  style: DsTypography.body.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w600,
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
