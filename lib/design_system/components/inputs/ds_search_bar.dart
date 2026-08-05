import 'package:flutter/material.dart';

import '../../icons/ds_icons.dart';
import '../../tokens/ds_motion.dart';
import '../../tokens/ds_radius.dart';
import '../../tokens/ds_spacing.dart';
import '../../tokens/ds_tokens.dart';
import '../../tokens/ds_typography.dart';

/// A search input — a [DsTextField]-styled box with a leading search icon
/// and a clear ("x") button that appears once there's text to clear.
class DsSearchBar extends StatefulWidget {
  const DsSearchBar({
    super.key,
    this.hintText = 'Rechercher',
    this.onChanged,
    this.onClear,
    this.leadingIcon = DsIcons.search,
  });

  final String hintText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  final IconData leadingIcon;

  @override
  State<DsSearchBar> createState() => _DsSearchBarState();
}

class _DsSearchBarState extends State<DsSearchBar> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _focused = false;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(
      () => setState(() => _focused = _focusNode.hasFocus),
    );
    _controller.addListener(() {
      final hasText = _controller.text.isNotEmpty;
      if (hasText != _hasText) setState(() => _hasText = hasText);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _clear() {
    _controller.clear();
    widget.onChanged?.call('');
    widget.onClear?.call();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<DsTokens>()!;
    final colors = tokens.colors;

    return AnimatedContainer(
      duration: DsMotion.standard,
      curve: DsMotion.curve,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: DsRadius.lgRadius,
        border: Border.all(
          color: _focused ? colors.borderFocus : colors.border,
          width: _focused ? 2 : 1,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: DsSpacing.md),
      height: 44,
      child: Row(
        children: [
          Icon(widget.leadingIcon, size: 18, color: colors.textSecondary),
          const SizedBox(width: DsSpacing.sm),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              onChanged: widget.onChanged,
              style: DsTypography.body.copyWith(color: colors.textPrimary),
              cursorColor: colors.primary,
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                hintText: widget.hintText,
                hintStyle: DsTypography.body.copyWith(
                  color: colors.textDisabled,
                ),
              ),
            ),
          ),
          AnimatedOpacity(
            opacity: _hasText ? 1 : 0,
            duration: DsMotion.standard,
            child: IgnorePointer(
              ignoring: !_hasText,
              child: GestureDetector(
                onTap: _clear,
                child: Icon(
                  DsIcons.close,
                  size: 16,
                  color: colors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
