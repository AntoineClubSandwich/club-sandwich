import 'package:flutter/material.dart';

import '../../tokens/ds_motion.dart';
import '../../tokens/ds_radius.dart';
import '../../tokens/ds_spacing.dart';
import '../../tokens/ds_tokens.dart';
import '../../tokens/ds_typography.dart';

/// A text input field styled to the design system — a labeled box with a
/// thin border that highlights on focus, and helper/error text below.
/// Wraps Flutter's own `TextField` for correct text-editing behavior
/// (selection, IME, accessibility) rather than reimplementing it; only the
/// decoration is custom.
class DsTextField extends StatefulWidget {
  const DsTextField({
    super.key,
    this.label,
    this.hintText,
    this.controller,
    this.errorText,
    this.helperText,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.onChanged,
    this.enabled = true,
  });

  final String? label;
  final String? hintText;
  final TextEditingController? controller;
  final String? errorText;
  final String? helperText;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final ValueChanged<String>? onChanged;
  final bool enabled;

  @override
  State<DsTextField> createState() => _DsTextFieldState();
}

class _DsTextFieldState extends State<DsTextField> {
  final FocusNode _focusNode = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(
      () => setState(() => _focused = _focusNode.hasFocus),
    );
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<DsTokens>()!;
    final colors = tokens.colors;
    final hasError = widget.errorText != null && widget.errorText!.isNotEmpty;

    final Color borderColor = !widget.enabled
        ? colors.border
        : hasError
        ? colors.error
        : _focused
        ? colors.borderFocus
        : colors.border;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: DsTypography.caption.copyWith(
              color: colors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: DsSpacing.xs),
        ],
        AnimatedContainer(
          duration: DsMotion.standard,
          curve: DsMotion.curve,
          decoration: BoxDecoration(
            color: widget.enabled ? colors.surface : colors.disabledBg,
            borderRadius: DsRadius.lgRadius,
            border: Border.all(color: borderColor, width: _focused ? 2 : 1),
          ),
          child: TextField(
            controller: widget.controller,
            focusNode: _focusNode,
            enabled: widget.enabled,
            obscureText: widget.obscureText,
            onChanged: widget.onChanged,
            style: DsTypography.body.copyWith(color: colors.textPrimary),
            cursorColor: colors.primary,
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: widget.hintText,
              hintStyle: DsTypography.body.copyWith(color: colors.textDisabled),
              prefixIcon: widget.prefixIcon != null
                  ? Icon(
                      widget.prefixIcon,
                      size: 18,
                      color: colors.textSecondary,
                    )
                  : null,
              suffixIcon: widget.suffixIcon,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: DsSpacing.md,
                vertical: DsSpacing.md,
              ),
              isDense: true,
            ),
          ),
        ),
        if (hasError || widget.helperText != null) ...[
          const SizedBox(height: DsSpacing.xs),
          Text(
            hasError ? widget.errorText! : widget.helperText!,
            style: DsTypography.caption.copyWith(
              color: hasError ? colors.error : colors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}
