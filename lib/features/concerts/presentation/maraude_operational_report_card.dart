import 'package:club_sandwich/features/concerts/data/concert_providers.dart';
import 'package:club_sandwich/features/concerts/domain/concert.dart';
import 'package:club_sandwich/features/concerts/domain/maraude_operation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MaraudeOperationalReportCard extends ConsumerStatefulWidget {
  const MaraudeOperationalReportCard({
    required this.concert,
    required this.canEdit,
    required this.canEditPhoto,
    super.key,
  });

  final Concert concert;
  final bool canEdit;
  final bool canEditPhoto;

  @override
  ConsumerState<MaraudeOperationalReportCard> createState() =>
      _MaraudeOperationalReportCardState();
}

class _MaraudeOperationalReportCardState
    extends ConsumerState<MaraudeOperationalReportCard> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _weightController;
  late final TextEditingController _mealsController;
  late final TextEditingController _commentController;
  late final TextEditingController _photoController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final report = widget.concert.operationalReport;
    _weightController = TextEditingController(
      text: report?.totalWeightKg.toString().replaceAll('.', ',') ?? '0',
    );
    _mealsController = TextEditingController(
      text: report?.estimatedMeals.toString() ?? '0',
    );
    _commentController = TextEditingController(text: report?.comment ?? '');
    _photoController = TextEditingController(
      text: report?.photoFolderUrl ?? '',
    );
  }

  @override
  void dispose() {
    _weightController.dispose();
    _mealsController.dispose();
    _commentController.dispose();
    _photoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final report = widget.concert.operationalReport;
    return Card(
      key: const ValueKey('maraude-operational-report'),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: widget.canEdit
            ? Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Compte rendu',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const ValueKey('report-weight'),
                      controller: _weightController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Poids total collecté (kg)',
                      ),
                      validator: (value) {
                        final weight = _parseWeight(value);
                        if (weight == null || weight < 0) {
                          return 'Saisissez un poids positif ou nul.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const ValueKey('report-meals'),
                      controller: _mealsController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Repas ou portions estimés',
                      ),
                      validator: (value) {
                        final meals = int.tryParse(value?.trim() ?? '');
                        if (meals == null || meals < 0) {
                          return 'Saisissez un nombre entier positif ou nul.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const ValueKey('report-comment'),
                      controller: _commentController,
                      minLines: 3,
                      maxLines: 6,
                      decoration: const InputDecoration(
                        labelText: 'Commentaire',
                        hintText: 'Difficultés, refus ou informations utiles',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const ValueKey('report-photo-url'),
                      controller: _photoController,
                      keyboardType: TextInputType.url,
                      decoration: const InputDecoration(
                        labelText: 'Lien vers le dossier de photos',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        OutlinedButton(
                          key: const ValueKey('save-report-draft'),
                          onPressed: _isSaving ? null : () => _save(false),
                          child: const Text('Enregistrer'),
                        ),
                        FilledButton.icon(
                          key: const ValueKey('complete-with-report'),
                          onPressed: _isSaving ? null : () => _save(true),
                          icon: _isSaving
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.check_circle_outline),
                          label: Text(
                            widget.concert.maraudeStatus ==
                                    MaraudeStatus.completed
                                ? 'Enregistrer les corrections'
                                : 'Enregistrer et clôturer',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Compte rendu',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  if (report == null)
                    const Text('Aucun compte rendu enregistré.')
                  else ...[
                    _ReportValue(
                      label: 'Poids collecté',
                      value: '${_formatNumber(report.totalWeightKg)} kg',
                    ),
                    _ReportValue(
                      label: 'Repas ou portions',
                      value: report.estimatedMeals.toString(),
                    ),
                    _ReportValue(
                      label: 'Commentaire',
                      value: report.comment ?? '—',
                    ),
                    _ReportValue(
                      label: 'Photos',
                      value: report.photoFolderUrl ?? '—',
                      showDivider: false,
                    ),
                  ],
                  if (widget.canEditPhoto) ...[
                    const SizedBox(height: 16),
                    TextField(
                      key: const ValueKey('communication-photo-url'),
                      controller: _photoController,
                      keyboardType: TextInputType.url,
                      decoration: const InputDecoration(
                        labelText: 'Lien vers le dossier de photos',
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      key: const ValueKey('save-communication-photo'),
                      onPressed: _isSaving ? null : _savePhoto,
                      icon: const Icon(Icons.link),
                      label: const Text('Enregistrer le lien'),
                    ),
                  ],
                ],
              ),
      ),
    );
  }

  Future<void> _save(bool complete) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isSaving = true);
    try {
      await ref
          .read(concertRepositoryProvider)
          .saveMaraudeReport(
            widget.concert.id,
            MaraudeReportDraft(
              totalWeightKg: _parseWeight(_weightController.text)!,
              estimatedMeals: int.parse(_mealsController.text.trim()),
              comment: _nullIfBlank(_commentController.text),
              photoFolderUrl: _nullIfBlank(_photoController.text),
            ),
            complete: complete,
          );
      ref.invalidate(concertDetailsProvider(widget.concert.id));
      ref.invalidate(concertsProvider);
      ref.invalidate(maraudeOverviewProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            complete ? 'Compte rendu enregistré.' : 'Brouillon enregistré.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible d’enregistrer le compte rendu.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _savePhoto() async {
    setState(() => _isSaving = true);
    try {
      await ref
          .read(concertRepositoryProvider)
          .updateMaraudePhotoLink(
            widget.concert.id,
            _nullIfBlank(_photoController.text),
          );
      ref.invalidate(concertDetailsProvider(widget.concert.id));
      ref.invalidate(maraudeOverviewProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Lien photo enregistré.')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d’enregistrer le lien.')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

class _ReportValue extends StatelessWidget {
  const _ReportValue({
    required this.label,
    required this.value,
    this.showDivider = true,
  });

  final String label;
  final String value;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 4),
        SelectableText(value),
        if (showDivider) const Divider(height: 24),
      ],
    );
  }
}

double? _parseWeight(String? value) {
  return double.tryParse((value ?? '').trim().replaceAll(',', '.'));
}

String? _nullIfBlank(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String _formatNumber(double value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value.toString().replaceAll('.', ',');
}
