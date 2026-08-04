import 'package:club_sandwich/features/concerts/data/concert_providers.dart';
import 'package:club_sandwich/features/collections/domain/maraude_collection.dart';
import 'package:club_sandwich/features/concerts/domain/concert.dart';
import 'package:club_sandwich/features/concerts/domain/maraude_operation.dart';
import 'package:club_sandwich/shared/utils/error_messages.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MaraudeOperationalReportCard extends ConsumerStatefulWidget {
  const MaraudeOperationalReportCard({
    required this.concert,
    required this.canEdit,
    required this.canEditPhoto,
    required this.canManagePhotoGallery,
    required this.currentUserId,
    required this.isAdmin,
    super.key,
  });

  final Concert concert;
  final bool canEdit;
  final bool canEditPhoto;
  final bool canManagePhotoGallery;
  final String? currentUserId;
  final bool isAdmin;

  @override
  ConsumerState<MaraudeOperationalReportCard> createState() =>
      _MaraudeOperationalReportCardState();
}

class _MaraudeOperationalReportCardState
    extends ConsumerState<MaraudeOperationalReportCard> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _weightController;
  late final TextEditingController _distanceController;
  late final TextEditingController _commentController;
  bool _isSaving = false;
  bool _isUploadingPhoto = false;
  late bool _quantitiesUnavailable;

  @override
  void initState() {
    super.initState();
    final report = widget.concert.operationalReport;
    _weightController = TextEditingController(
      text: _displayedWeight(widget.concert),
    );
    _distanceController = TextEditingController(
      text: report?.distanceKm?.toString().replaceAll('.', ',') ?? '',
    );
    _quantitiesUnavailable = _effectiveQuantitiesUnavailable(widget.concert);
    _commentController = TextEditingController(text: report?.comment ?? '');
  }

  @override
  void didUpdateWidget(covariant MaraudeOperationalReportCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final updatedWeight = _displayedWeight(widget.concert);
    if (_weightController.text != updatedWeight) {
      _weightController.text = updatedWeight;
    }
    if (oldWidget.concert.operationalReport !=
            widget.concert.operationalReport ||
        oldWidget.concert.collections != widget.concert.collections) {
      _quantitiesUnavailable = _effectiveQuantitiesUnavailable(widget.concert);
    }
  }

  @override
  void dispose() {
    _weightController.dispose();
    _distanceController.dispose();
    _commentController.dispose();
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
                      enabled: false,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Poids total calculé (kg)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      key: const ValueKey('report-quantities-unavailable'),
                      contentPadding: EdgeInsets.zero,
                      value: _quantitiesUnavailable,
                      title: const Text('Quantités non renseignées'),
                      subtitle: const Text(
                        'À utiliser si les quantités n’ont pas été relevées.',
                      ),
                      onChanged: _isSaving
                          ? null
                          : (value) => setState(
                              () => _quantitiesUnavailable = value ?? false,
                            ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const ValueKey('report-distance'),
                      controller: _distanceController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Kilomètres parcourus',
                      ),
                      validator: (value) {
                        final distance = _parseWeight(value);
                        if (value != null &&
                            value.trim().isNotEmpty &&
                            (distance == null || distance < 0)) {
                          return 'Saisissez une distance positive ou nulle.';
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
                    MaraudePhotoGallery(
                      concertId: widget.concert.id,
                      canUpload:
                          widget.canManagePhotoGallery && !_isUploadingPhoto,
                      isUploading: _isUploadingPhoto,
                      onUpload: _uploadPhoto,
                      currentUserId: widget.currentUserId,
                      isAdmin: widget.isAdmin,
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton.icon(
                        key: const ValueKey('save-report-draft'),
                        onPressed: _isSaving ? null : () => _save(false),
                        icon: _isSaving
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Text(
                          widget.concert.maraudeStatus ==
                                  MaraudeStatus.completed
                              ? 'Enregistrer les corrections'
                              : 'Enregistrer le compte rendu',
                        ),
                      ),
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
                      value: _effectiveQuantitiesUnavailable(widget.concert)
                          ? 'Non renseigné'
                          : report.totalWeightKg == null
                          ? 'Non renseigné'
                          : '${_formatNumber(report.totalWeightKg!)} kg',
                    ),
                    _ReportValue(
                      label: 'Kilomètres parcourus',
                      value: report.distanceKm == null
                          ? 'Non renseigné'
                          : '${_formatNumber(report.distanceKm!)} km',
                    ),
                    _ReportValue(
                      label: 'Commentaire',
                      value: report.comment ?? '—',
                      showDivider: false,
                    ),
                  ],
                  const SizedBox(height: 16),
                  MaraudePhotoGallery(
                    concertId: widget.concert.id,
                    canUpload:
                        widget.canManagePhotoGallery && !_isUploadingPhoto,
                    isUploading: _isUploadingPhoto,
                    onUpload: _uploadPhoto,
                    currentUserId: widget.currentUserId,
                    isAdmin: widget.isAdmin,
                  ),
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
          .saveMaraudeReport(widget.concert.id, _draft, complete: complete);
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
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            describeError(error, 'Impossible d’enregistrer le compte rendu.'),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  MaraudeReportDraft get _draft => MaraudeReportDraft(
    totalWeightKg: _quantitiesUnavailable
        ? null
        : _parseWeight(_weightController.text),
    distanceKm: _parseWeight(_distanceController.text),
    quantitiesUnavailable: _quantitiesUnavailable,
    comment: _nullIfBlank(_commentController.text),
  );

  Future<void> _uploadPhoto() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
      withData: true,
    );
    final file = result?.files.single;
    if (file?.bytes == null || !mounted) return;
    final extension = (file!.extension ?? 'jpg').toLowerCase();
    final contentType = switch (extension) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };
    setState(() => _isUploadingPhoto = true);
    try {
      await ref
          .read(concertRepositoryProvider)
          .uploadMaraudePhoto(
            concertId: widget.concert.id,
            extension: extension,
            bytes: file.bytes!,
            contentType: contentType,
          );
      ref.invalidate(maraudePhotosProvider(widget.concert.id));
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Photo ajoutée.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            describeError(error, 'Impossible d’ajouter cette photo.'),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }
}

const _maraudePhotoLimit = 5;

/// Photo gallery for a maraude: up to [_maraudePhotoLimit] thumbnails,
/// addable by the communication role/admin, each removable by its author
/// or an admin (see get_concert_volunteer_roster-style authorization on
/// add_maraude_photo/delete_maraude_photo).
class MaraudePhotoGallery extends ConsumerStatefulWidget {
  const MaraudePhotoGallery({
    required this.concertId,
    required this.canUpload,
    required this.isUploading,
    required this.onUpload,
    required this.currentUserId,
    required this.isAdmin,
    super.key,
  });

  final String concertId;
  final bool canUpload;
  final bool isUploading;
  final VoidCallback onUpload;
  final String? currentUserId;
  final bool isAdmin;

  @override
  ConsumerState<MaraudePhotoGallery> createState() => _PhotoGalleryState();
}

class _PhotoGalleryState extends ConsumerState<MaraudePhotoGallery> {
  final Set<String> _deletingIds = {};

  @override
  Widget build(BuildContext context) {
    final photos = ref.watch(maraudePhotosProvider(widget.concertId));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.photo_outlined),
            const SizedBox(width: 10),
            Text(
              photos.maybeWhen(
                data: (items) => '${items.length} / $_maraudePhotoLimit',
                orElse: () => 'Photos',
              ),
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ],
        ),
        const SizedBox(height: 10),
        photos.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          error: (_, _) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text('Impossible de charger les photos.'),
                ),
                TextButton.icon(
                  onPressed: () =>
                      ref.invalidate(maraudePhotosProvider(widget.concertId)),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Réessayer'),
                ),
              ],
            ),
          ),
          data: (items) {
            if (items.isEmpty && !widget.canUpload) {
              return const Text('Aucune photo ajoutée.');
            }
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final photo in items)
                  _PhotoThumbnail(
                    photo: photo,
                    canDelete:
                        !_deletingIds.contains(photo.id) &&
                        (widget.isAdmin ||
                            photo.uploadedBy == widget.currentUserId),
                    isDeleting: _deletingIds.contains(photo.id),
                    onDelete: () => _deletePhoto(photo),
                  ),
                if (widget.canUpload && items.length < _maraudePhotoLimit)
                  _AddPhotoButton(
                    isUploading: widget.isUploading,
                    onUpload: widget.onUpload,
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Future<void> _deletePhoto(MaraudePhoto photo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer cette photo ?'),
        content: const Text('Cette action est définitive.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deletingIds.add(photo.id));
    try {
      await ref
          .read(concertRepositoryProvider)
          .deleteMaraudePhoto(photo.id, photo.storagePath);
      ref.invalidate(maraudePhotosProvider(widget.concertId));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            describeError(error, 'Impossible de supprimer cette photo.'),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _deletingIds.remove(photo.id));
    }
  }
}

class _PhotoThumbnail extends ConsumerWidget {
  const _PhotoThumbnail({
    required this.photo,
    required this.canDelete,
    required this.isDeleting,
    required this.onDelete,
  });

  final MaraudePhoto photo;
  final bool canDelete;
  final bool isDeleting;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = ref.watch(maraudePhotoUrlProvider(photo.storagePath));
    return SizedBox(
      width: 96,
      height: 96,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: url.when(
                loading: () => const ColoredBox(
                  color: Colors.black12,
                  child: Center(
                    child: SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
                error: (_, _) => const ColoredBox(
                  color: Colors.black12,
                  child: Icon(Icons.broken_image_outlined),
                ),
                data: (signedUrl) => Image.network(
                  signedUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const ColoredBox(
                        color: Colors.black12,
                        child: Icon(Icons.broken_image_outlined),
                      ),
                ),
              ),
            ),
          ),
          if (canDelete)
            Positioned(
              top: 2,
              right: 2,
              child: Material(
                color: Colors.black54,
                shape: const CircleBorder(),
                child: isDeleting
                    ? const Padding(
                        padding: EdgeInsets.all(6),
                        child: SizedBox.square(
                          dimension: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                      )
                    : IconButton(
                        tooltip: 'Supprimer cette photo',
                        iconSize: 18,
                        color: Colors.white,
                        onPressed: onDelete,
                        icon: const Icon(Icons.close),
                      ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AddPhotoButton extends StatelessWidget {
  const _AddPhotoButton({required this.isUploading, required this.onUpload});

  final bool isUploading;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      height: 96,
      child: OutlinedButton(
        key: const ValueKey('upload-maraude-photo'),
        onPressed: isUploading ? null : onUpload,
        style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
        child: isUploading
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.add_photo_alternate_outlined),
      ),
    );
  }
}

String _displayedWeight(Concert concert) {
  return MaraudeCollectionSummary.fromCollections(
    concert.collections,
  ).totalWeightKg.toString().replaceAll('.', ',');
}

bool _effectiveQuantitiesUnavailable(Concert concert) {
  return concert.operationalReport?.quantitiesUnavailable == true &&
      concert.collections.isEmpty;
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
