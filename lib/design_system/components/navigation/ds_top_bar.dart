import 'package:flutter/material.dart';

import '../../tokens/ds_shadows.dart';
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

    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: DsSpacing.xl),
      decoration: BoxDecoration(
        color: colors.surface,
        boxShadow: DsShadows.card(colors.borderStrong),
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
    );
  }
}
