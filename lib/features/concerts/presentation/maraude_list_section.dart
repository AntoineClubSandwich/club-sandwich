import 'package:club_sandwich/features/concerts/domain/maraude_operation.dart';
import 'package:club_sandwich/features/concerts/presentation/maraude_overview_card.dart';
import 'package:flutter/material.dart';

class MaraudeListSection extends StatelessWidget {
  const MaraudeListSection({
    required this.title,
    required this.items,
    this.actionLabel,
    this.actionLabelFor,
    this.canOpenFor,
    super.key,
  });

  final String title;
  final List<MaraudeOverview> items;
  final String? actionLabel;
  final String Function(MaraudeOverview)? actionLabelFor;
  final bool Function(MaraudeOverview)? canOpenFor;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          for (final item in items)
            MaraudeOverviewCard(
              maraude: item,
              actionLabel: actionLabelFor?.call(item) ?? actionLabel,
              canOpen: canOpenFor?.call(item) ?? true,
            ),
        ],
      ),
    );
  }
}
