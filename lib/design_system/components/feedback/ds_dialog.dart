import 'package:flutter/material.dart';

import '../../tokens/ds_radius.dart';
import '../../tokens/ds_shadows.dart';
import '../../tokens/ds_spacing.dart';
import '../../tokens/ds_tokens.dart';
import '../../tokens/ds_typography.dart';

/// A modal dialog — floats on `colors.surfaceElevated` with the
/// system's discreet elevated shadow, never Material's default dialog
/// shadow. Use [showDsDialog] to present it.
class DsDialog extends StatelessWidget {
  const DsDialog({
    super.key,
    required this.title,
    required this.content,
    this.actions = const [],
  });

  final String title;
  final Widget content;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<DsTokens>()!;
    final colors = tokens.colors;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Container(
          decoration: BoxDecoration(
            color: colors.surfaceElevated,
            borderRadius: DsRadius.lgRadius,
            boxShadow: DsShadows.elevated,
          ),
          padding: const EdgeInsets.all(DsSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: DsTypography.h3.copyWith(color: colors.textPrimary),
              ),
              const SizedBox(height: DsSpacing.md),
              content,
              if (actions.isNotEmpty) ...[
                const SizedBox(height: DsSpacing.xl),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    for (var i = 0; i < actions.length; i++) ...[
                      if (i > 0) const SizedBox(width: DsSpacing.sm),
                      actions[i],
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Presents a [DsDialog] with a soft (non-pitch-black) barrier.
Future<T?> showDsDialog<T>({
  required BuildContext context,
  required String title,
  required Widget content,
  List<Widget> actions = const [],
}) {
  final tokens = Theme.of(context).extension<DsTokens>()!;
  return showDialog<T>(
    context: context,
    barrierColor: tokens.colors.textPrimary.withValues(alpha: 0.32),
    builder: (context) =>
        DsDialog(title: title, content: content, actions: actions),
  );
}
