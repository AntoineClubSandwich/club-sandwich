import 'package:club_sandwich/features/volunteers/domain/concert_volunteer_application.dart';
import 'package:club_sandwich/features/volunteers/domain/maraude_role_mission.dart';
import 'package:flutter/material.dart';

Future<void> showMaraudeRoleMissionSheet(
  BuildContext context,
  MaraudeRole role,
) {
  return showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 640),
        child: _MaraudeRoleMissionSheetContent(role: role),
      ),
    ),
  );
}

class _MaraudeRoleMissionSheetContent extends StatelessWidget {
  const _MaraudeRoleMissionSheetContent({required this.role});

  final MaraudeRole role;

  @override
  Widget build(BuildContext context) {
    final mission = maraudeRoleMissions[role];
    final colors = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 12, 12),
          child: Row(
            children: [
              Icon(Icons.assignment_ind_outlined, color: colors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Fiche de mission — ${role.label}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                key: const ValueKey('close-mission-sheet'),
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        if (mission != null)
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _MissionSection(
                    title: 'Responsabilités',
                    icon: Icons.person_pin_circle_outlined,
                    items: mission.responsibilities,
                  ),
                  _MissionSection(
                    title: 'Check-list',
                    icon: Icons.checklist_outlined,
                    items: mission.checklist,
                  ),
                  _MissionSection(
                    title: 'Bonnes pratiques',
                    icon: Icons.tips_and_updates_outlined,
                    items: mission.bestPractices,
                  ),
                  _MissionSection(
                    title: 'Objectifs de la mission',
                    icon: Icons.flag_outlined,
                    items: mission.objectives,
                    showDivider: false,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _MissionSection extends StatelessWidget {
  const _MissionSection({
    required this.title,
    required this.icon,
    required this.items,
    this.showDivider = true,
  });

  final String title;
  final IconData icon;
  final List<String> items;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: colors.primary),
            const SizedBox(width: 8),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 6, left: 26),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('•  '),
                Expanded(child: Text(item)),
              ],
            ),
          ),
        if (showDivider) ...[const SizedBox(height: 8), const Divider()],
        const SizedBox(height: 8),
      ],
    );
  }
}

class MaraudeRoleMissionCard extends StatelessWidget {
  const MaraudeRoleMissionCard({super.key, required this.role});

  final MaraudeRole role;

  @override
  Widget build(BuildContext context) {
    final mission = maraudeRoleMissions[role];
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.assignment_ind_outlined, color: colors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ma mission : ${role.label}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    mission?.objectives.first ??
                        'Consultez votre fiche de mission pour connaître vos responsabilités.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            TextButton(
              key: const ValueKey('open-mission-sheet-card'),
              onPressed: () => showMaraudeRoleMissionSheet(context, role),
              child: const Text('Voir la fiche complète'),
            ),
          ],
        ),
      ),
    );
  }
}
