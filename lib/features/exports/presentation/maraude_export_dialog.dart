import 'package:club_sandwich/features/auth/domain/user_account.dart';
import 'package:club_sandwich/features/exports/data/export_providers.dart';
import 'package:club_sandwich/features/organizations/data/organization_providers.dart';
import 'package:club_sandwich/features/organizations/domain/organization.dart';
import 'package:club_sandwich/shared/utils/error_messages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> showMaraudeExportDialog(BuildContext context, AppUserRole role) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => UncontrolledProviderScope(
      container: ProviderScope.containerOf(context),
      child: _MaraudeExportDialog(role: role),
    ),
  );
}

class _MaraudeExportDialog extends ConsumerStatefulWidget {
  const _MaraudeExportDialog({required this.role});
  final AppUserRole role;

  @override
  ConsumerState<_MaraudeExportDialog> createState() =>
      _MaraudeExportDialogState();
}

class _MaraudeExportDialogState extends ConsumerState<_MaraudeExportDialog> {
  DateTime? _startDate;
  DateTime? _endDate;
  String? _organizationId;
  bool _exporting = false;

  Future<void> _pickDate({required bool isStart}) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: (isStart ? _startDate : _endDate) ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (selected == null) return;
    setState(() {
      if (isStart) {
        _startDate = selected;
      } else {
        _endDate = selected;
      }
    });
  }

  Future<void> _export() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final repository = ref.read(exportRepositoryProvider);
      final rows = await repository.fetchMaraudeExportRows(
        startDate: _startDate,
        endDate: _endDate,
        organizationId: _organizationId,
      );
      if (rows.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Aucune maraude terminée ne correspond à ces critères.',
              ),
            ),
          );
        }
        return;
      }
      final bytes = repository.buildCsv(rows);
      final now = DateTime.now();
      final filename =
          'bilan-maraudes-${now.year}-'
          '${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')}';
      await repository.saveCsv(bytes, filename);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${rows.length} '
              '${rows.length == 1 ? 'maraude exportée' : 'maraudes exportées'}.',
            ),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(describeError(error, 'Impossible d’exporter.')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final organizations = widget.role == AppUserRole.admin
        ? ref.watch(organizationsProvider)
        : null;
    return AlertDialog(
      title: const Text('Exporter les indicateurs'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Export CSV des maraudes terminées (poids, repas, bénévoles, '
              'durée, distance).',
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const ValueKey('export-start-date-field'),
                    onPressed: () => _pickDate(isStart: true),
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Text(
                      _startDate == null ? 'Date de début' : _date(_startDate!),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    key: const ValueKey('export-end-date-field'),
                    onPressed: () => _pickDate(isStart: false),
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Text(
                      _endDate == null ? 'Date de fin' : _date(_endDate!),
                    ),
                  ),
                ),
              ],
            ),
            if (widget.role == AppUserRole.admin) ...[
              const SizedBox(height: 12),
              organizations!.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, _) => Row(
                  children: [
                    const Expanded(
                      child: Text('Impossible de charger les organisations.'),
                    ),
                    TextButton.icon(
                      onPressed: () => ref.invalidate(organizationsProvider),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Réessayer'),
                    ),
                  ],
                ),
                data: (items) {
                  final promoterOrganizations = items
                      .where((item) => item.kind == OrganizationKind.promoter)
                      .toList(growable: false);
                  return DropdownButtonFormField<String?>(
                    key: const ValueKey('export-organization-field'),
                    initialValue: _organizationId,
                    decoration: const InputDecoration(
                      labelText: 'Organisation (toutes si vide)',
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Toutes les organisations'),
                      ),
                      for (final organization in promoterOrganizations)
                        DropdownMenuItem(
                          value: organization.id,
                          child: Text(organization.name),
                        ),
                    ],
                    onChanged: (value) =>
                        setState(() => _organizationId = value),
                  );
                },
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          key: const ValueKey('export-submit-button'),
          onPressed: _exporting ? null : _export,
          child: _exporting
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Exporter (CSV)'),
        ),
      ],
    );
  }
}

String _date(DateTime value) {
  final local = value.toLocal();
  return '${local.day.toString().padLeft(2, '0')}/'
      '${local.month.toString().padLeft(2, '0')}/${local.year}';
}
