import 'package:club_sandwich/features/concerts/domain/concert.dart';
import 'package:club_sandwich/features/concerts/domain/maraude_operation.dart';
import 'package:club_sandwich/features/concerts/presentation/concert_formatters.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MaraudeOverviewCard extends StatelessWidget {
  const MaraudeOverviewCard({
    required this.maraude,
    this.actionLabel,
    super.key,
  });

  final MaraudeOverview maraude;
  final String? actionLabel;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.go('/concerts/${maraude.concertId}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      maraude.artist,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Chip(
                    visualDensity: VisualDensity.compact,
                    label: Text(maraude.maraudeStatus.label),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${formatLongFrenchDate(maraude.date)} · ${maraude.venueName}'
                '${maraude.time == null ? '' : ' · ${_shortTime(maraude.time!)}'}',
              ),
              if (maraude.venueAddress != null) ...[
                const SizedBox(height: 6),
                Text(
                  maraude.venueAddress!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              if (maraude.cateringName != null) ...[
                const SizedBox(height: 6),
                Text('Catering : ${maraude.cateringName}'),
              ],
              if (maraude.ownTeamRole != null) ...[
                const SizedBox(height: 6),
                Text('Rôle : ${maraude.ownTeamRole!.label}'),
              ],
              if (maraude.cateringClosesAt != null) ...[
                const SizedBox(height: 6),
                Text(
                  'Arrivée recommandée : '
                  '${_time(maraude.recommendedArrival)}',
                ),
              ],
              if (maraude.maraudeStatus == MaraudeStatus.completed ||
                  maraude.maraudeStatus == MaraudeStatus.cancelled) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    Text(
                      '${maraude.selectedCount} bénévole'
                      '${maraude.selectedCount > 1 ? 's' : ''}',
                    ),
                    Text(
                      maraude.totalWeightKg == null
                          ? 'Poids : —'
                          : '${_number(maraude.totalWeightKg!)} kg',
                    ),
                    Text(
                      maraude.estimatedMeals == null
                          ? 'Repas : —'
                          : '${maraude.estimatedMeals} repas',
                    ),
                  ],
                ),
              ],
              if (actionLabel != null) ...[
                const SizedBox(height: 10),
                Text(
                  actionLabel!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String _shortTime(String value) {
  final parts = value.split(':');
  return parts.length < 2 ? value : '${parts[0]}:${parts[1]}';
}

String _number(double value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value.toString().replaceAll('.', ',');
}

String _time(DateTime value) {
  return '${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}';
}
