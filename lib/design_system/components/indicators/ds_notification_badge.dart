import 'package:flutter/material.dart';

import '../../tokens/ds_motion.dart';
import '../../tokens/ds_tokens.dart';
import '../../tokens/ds_typography.dart';

/// A small counter badge overlaid on the top-right corner of [child] — for
/// unread notifications, pending counts, etc.
class DsNotificationBadge extends StatelessWidget {
  const DsNotificationBadge({
    super.key,
    required this.child,
    required this.count,
    this.showZero = false,
  });

  final Widget child;
  final int count;
  final bool showZero;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<DsTokens>()!;
    final colors = tokens.colors;
    final visible = count > 0 || (count == 0 && showZero);
    final label = count > 99 ? '99+' : '$count';

    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          top: -4,
          right: -4,
          child: AnimatedScale(
            scale: visible ? 1 : 0,
            duration: DsMotion.standard,
            curve: DsMotion.curve,
            child: Container(
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: colors.error,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: colors.surface, width: 1.5),
              ),
              alignment: Alignment.center,
              child: Text(
                label,
                style: DsTypography.caption.copyWith(
                  color: colors.textOnColor,
                  fontSize: 10,
                  height: 1,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
