import 'dart:ui';

import 'package:flutter/material.dart';

import '../../tokens/ds_spacing.dart';
import '../../tokens/ds_tokens.dart';
import '../../tokens/ds_typography.dart';

/// A page top bar — title, optional leading widget (e.g. a back button),
/// optional trailing actions (e.g. a [DsNotificationBadge]-wrapped bell).
class DsTopBar extends StatelessWidget implements PreferredSizeWidget {
  const DsTopBar({
    super.key,
    required this.title,
    this.leading,
    this.actions = const [],
  });

  final String title;
  final Widget? leading;
  final List<Widget> actions;

  static const double height = 64;

  @override
  Size get preferredSize => const Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<DsTokens>()!;
    final colors = tokens.colors;

    // Glass surface: translucent + blurred rather than a solid fill with a
    // drop shadow. The blur only has a visible effect once a screen scrolls
    // content behind this bar (`extendBodyBehindAppBar`) — until then it's
    // an inert-but-harmless no-op and this just reads as a softer, subtly
    // transparent bar with a hairline border.
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: DsSpacing.xl),
          decoration: BoxDecoration(
            color: colors.surface.withValues(alpha: 0.8),
            border: Border(
              bottom: BorderSide(
                color: colors.textPrimary.withValues(alpha: 0.05),
              ),
            ),
          ),
          child: Row(
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: DsSpacing.md),
              ],
              Expanded(
                child: Text(
                  title,
                  style: DsTypography.h3.copyWith(color: colors.textPrimary),
                ),
              ),
              for (final action in actions) ...[
                const SizedBox(width: DsSpacing.md),
                action,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
