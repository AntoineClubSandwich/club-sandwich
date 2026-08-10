import 'package:flutter/material.dart';

import '../../tokens/ds_radius.dart';
import '../../tokens/ds_spacing.dart';
import '../../tokens/ds_tokens.dart';
import '../../tokens/ds_typography.dart';
import 'ds_semantic_variant.dart';

/// A small pill label for tags/categories — e.g. a role name, a document
/// type. For a value that represents a lifecycle state (open, pending,
/// completed...), prefer [DsStatusChip], which also carries a dot
/// indicator.
class DsBadge extends StatelessWidget {
  const DsBadge({
    super.key,
    required this.label,
    this.variant = DsSemanticVariant.neutral,
  });

  final String label;
  final DsSemanticVariant variant;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<DsTokens>()!;
    final colors = tokens.colors;
    final semantic = DsSemanticColors.resolve(colors, variant);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DsSpacing.sm,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: semantic.background,
        borderRadius: DsRadius.pillRadius,
      ),
      child: Text(
        label,
        style: DsTypography.caption.copyWith(
          color: semantic.foreground,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
