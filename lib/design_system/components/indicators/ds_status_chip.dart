import 'package:flutter/material.dart';

import '../../tokens/ds_borders.dart';
import '../../tokens/ds_radius.dart';
import '../../tokens/ds_spacing.dart';
import '../../tokens/ds_tokens.dart';
import '../../tokens/ds_typography.dart';
import 'ds_semantic_variant.dart';

/// A domain-agnostic lifecycle status — "draft", "active", "pending",
/// "completed", "cancelled" — used by [DsStatusChip]. Deliberately generic
/// (not `MaraudeStatus`/`ConcertStatus` etc.) so the same chip works for
/// any status-bearing entity shown in the design system.
enum DsChipStatus { draft, active, pending, completed, cancelled }

extension on DsChipStatus {
  DsSemanticVariant get variant => switch (this) {
    DsChipStatus.draft => DsSemanticVariant.neutral,
    DsChipStatus.active => DsSemanticVariant.info,
    DsChipStatus.pending => DsSemanticVariant.warning,
    DsChipStatus.completed => DsSemanticVariant.success,
    DsChipStatus.cancelled => DsSemanticVariant.error,
  };
}

/// A status pill with an optional colored dot — for showing where an
/// entity (a maraude, an invitation, a document...) sits in its
/// lifecycle. Unlike [DsBadge], it carries a visible border and an
/// (optional) dot indicator, since it represents *state* rather than a
/// static tag.
class DsStatusChip extends StatelessWidget {
  const DsStatusChip({
    super.key,
    required this.label,
    required this.status,
    this.dotIndicator = true,
  });

  final String label;
  final DsChipStatus status;
  final bool dotIndicator;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<DsTokens>()!;
    final colors = tokens.colors;
    final semantic = DsSemanticColors.resolve(colors, status.variant);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DsSpacing.sm,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: semantic.background,
        borderRadius: DsRadius.pillRadius,
        border: Border.all(
          color: semantic.foreground,
          width: DsBorders.hairline,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dotIndicator) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: semantic.foreground,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: DsSpacing.xs),
          ],
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: DsTypography.caption.copyWith(
                color: semantic.foreground,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
