import 'package:flutter/material.dart';

import '../../tokens/ds_radius.dart';
import '../../tokens/ds_shadows.dart';
import '../../tokens/ds_spacing.dart';
import '../../tokens/ds_tokens.dart';

/// A sheet that slides up from the bottom — rounded only on top, floating
/// on `colors.surfaceElevated`. Use [showDsBottomSheet] to present it.
class DsBottomSheet extends StatelessWidget {
  const DsBottomSheet({
    super.key,
    required this.child,
    this.showDragHandle = true,
  });

  final Widget child;
  final bool showDragHandle;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<DsTokens>()!;
    final colors = tokens.colors;

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(DsRadius.xxl),
          topRight: Radius.circular(DsRadius.xxl),
        ),
        boxShadow: DsShadows.ambientElevated(colors.textPrimary),
      ),
      padding: const EdgeInsets.fromLTRB(
        DsSpacing.xl,
        DsSpacing.md,
        DsSpacing.xl,
        DsSpacing.xl,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showDragHandle) ...[
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: DsSpacing.lg),
                  decoration: BoxDecoration(
                    color: colors.border,
                    borderRadius: DsRadius.pillRadius,
                  ),
                ),
              ),
            ],
            child,
          ],
        ),
      ),
    );
  }
}

/// Presents a [DsBottomSheet] with a transparent modal barrier scaffold
/// (so only the sheet itself carries the design system's shape/shadow).
Future<T?> showDsBottomSheet<T>({
  required BuildContext context,
  required Widget child,
  bool showDragHandle = true,
}) {
  final tokens = Theme.of(context).extension<DsTokens>()!;
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: tokens.colors.textPrimary.withValues(alpha: 0.32),
    builder: (context) =>
        DsBottomSheet(showDragHandle: showDragHandle, child: child),
  );
}
