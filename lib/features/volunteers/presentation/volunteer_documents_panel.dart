import 'package:club_sandwich/features/volunteers/data/volunteer_document_providers.dart';
import 'package:club_sandwich/features/volunteers/domain/volunteer_document.dart';
import 'package:club_sandwich/shared/utils/error_messages.dart';
import 'package:club_sandwich/shared/widgets/app_state_panel.dart';
import 'package:club_sandwich/shared/widgets/inline_document_preview.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class VolunteerDocumentsPanel extends ConsumerWidget {
  const VolunteerDocumentsPanel({super.key, required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final documents = ref.watch(volunteerDocumentsProvider(userId));
    return documents.when(
      loading: () => const AppLoadingState(label: 'Chargement des documents'),
      error: (_, _) => AppErrorState(
        message: 'Documents indisponibles.',
        onRetry: () => ref.invalidate(volunteerDocumentsProvider(userId)),
      ),
      data: (items) {
        final identity = items
            .where((item) => item.type == VolunteerDocumentType.identity)
            .firstOrNull;
        final socialSecurity = items
            .where((item) => item.type == VolunteerDocumentType.socialSecurity)
            .firstOrNull;
        final other = items
            .where((item) => item.type == VolunteerDocumentType.other)
            .toList(growable: false);
        final contract = items
            .where((item) => item.type == VolunteerDocumentType.contract)
            .firstOrNull;
        final missing = [
          if (identity?.status != VolunteerDocumentStatus.approved)
            VolunteerDocumentType.identity.label,
          if (socialSecurity?.status != VolunteerDocumentStatus.approved)
            VolunteerDocumentType.socialSecurity.label,
          for (final document in other)
            if (document.status != VolunteerDocumentStatus.approved)
              document.displayLabel,
        ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _AdminDocumentTile(
              userId: userId,
              type: VolunteerDocumentType.identity,
              document: identity,
            ),
            const SizedBox(height: 8),
            _AdminDocumentTile(
              userId: userId,
              type: VolunteerDocumentType.socialSecurity,
              document: socialSecurity,
            ),
            for (final document in other) ...[
              const SizedBox(height: 8),
              _AdminDocumentTile(
                userId: userId,
                type: VolunteerDocumentType.other,
                document: document,
              ),
            ],
            const SizedBox(height: 8),
            _AdminDocumentTile(
              userId: userId,
              type: VolunteerDocumentType.contract,
              document: contract,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  key: const ValueKey('request-other-document-button'),
                  onPressed: () => _requestOtherDocument(context, ref),
                  icon: const Icon(Icons.playlist_add_outlined),
                  label: const Text('Demander un document libre'),
                ),
                if (missing.isNotEmpty)
                  OutlinedButton.icon(
                    key: const ValueKey('notify-missing-documents-button'),
                    onPressed: () => _notifyMissing(context, ref),
                    icon: const Icon(Icons.notifications_outlined),
                    label: const Text('Relancer le bénévole'),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<void> _requestOtherDocument(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final controller = TextEditingController();
    final label = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Demander un document'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Libellé du document (ex : certificat médical)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Demander'),
          ),
        ],
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.dispose();
    });
    if (label == null || label.trim().isEmpty || !context.mounted) return;
    try {
      await ref
          .read(volunteerDocumentRepositoryProvider)
          .adminSetDocument(
            userId: userId,
            type: VolunteerDocumentType.other,
            label: label.trim(),
          );
      ref.invalidate(volunteerDocumentsProvider(userId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document demandé au bénévole.')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              describeError(error, 'Impossible de demander ce document.'),
            ),
          ),
        );
      }
    }
  }

  Future<void> _notifyMissing(BuildContext context, WidgetRef ref) async {
    try {
      await ref
          .read(volunteerDocumentRepositoryProvider)
          .notifyMissingDocuments(userId);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Bénévole relancé.')));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(describeError(error, 'Impossible de relancer.')),
          ),
        );
      }
    }
  }
}

class _AdminDocumentTile extends ConsumerStatefulWidget {
  const _AdminDocumentTile({
    required this.userId,
    required this.type,
    this.document,
  });
  final String userId;
  final VolunteerDocumentType type;
  final VolunteerDocument? document;

  @override
  ConsumerState<_AdminDocumentTile> createState() => _AdminDocumentTileState();
}

class _AdminDocumentTileState extends ConsumerState<_AdminDocumentTile> {
  bool _busy = false;

  Future<void> _uploadOnBehalf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true,
    );
    final file = result?.files.single;
    if (file?.bytes == null || !mounted) return;
    final extension = (file!.extension ?? '').toLowerCase();
    final contentType = switch (extension) {
      'pdf' => 'application/pdf',
      'png' => 'image/png',
      _ => 'image/jpeg',
    };
    setState(() => _busy = true);
    try {
      final repository = ref.read(volunteerDocumentRepositoryProvider);
      final path = await repository.uploadFile(
        targetUserId: widget.userId,
        bytes: file.bytes!,
        extension: extension,
        contentType: contentType,
      );
      await repository.adminSetDocument(
        userId: widget.userId,
        type: widget.type,
        storagePath: path,
        label: widget.document?.label,
        documentId: widget.document?.id,
      );
      ref.invalidate(volunteerDocumentsProvider(widget.userId));
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Document enregistré.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              describeError(error, 'Impossible d’envoyer ce document.'),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _review(VolunteerDocumentStatus status) async {
    final documentId = widget.document?.id;
    if (documentId == null) return;
    String? reason;
    if (status == VolunteerDocumentStatus.rejected) {
      final controller = TextEditingController();
      reason = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Refuser ce document'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Motif du refus'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, controller.text),
              child: const Text('Refuser'),
            ),
          ],
        ),
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.dispose();
      });
      if (reason == null || reason.trim().isEmpty || !mounted) return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(volunteerDocumentRepositoryProvider)
          .reviewDocument(
            documentId: documentId,
            status: status,
            rejectionReason: reason?.trim(),
          );
      ref.invalidate(volunteerDocumentsProvider(widget.userId));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(describeError(error, 'Impossible de valider.')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final document = widget.document;
    final colors = Theme.of(context).colorScheme;
    final label = document?.displayLabel ?? widget.type.label;
    final statusColor = switch (document?.status) {
      VolunteerDocumentStatus.approved => Colors.green,
      VolunteerDocumentStatus.rejected => colors.error,
      VolunteerDocumentStatus.pending when document?.hasFile == true =>
        Colors.orange,
      _ => colors.outline,
    };
    final statusLabel = document == null
        ? 'Non fourni'
        : document.hasFile
        ? document.status.label
        : 'Demandé';
    return Card.filled(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                Chip(
                  label: Text(statusLabel),
                  backgroundColor: statusColor.withValues(alpha: 0.15),
                  labelStyle: TextStyle(color: statusColor),
                ),
              ],
            ),
            if (document?.status == VolunteerDocumentStatus.rejected &&
                document?.rejectionReason != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  document!.rejectionReason!,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: colors.error),
                ),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _busy ? null : _uploadOnBehalf,
                  icon: _busy
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.upload_file),
                  label: Text(_uploadButtonLabel(document)),
                ),
                if (document?.hasFile == true &&
                    document?.status == VolunteerDocumentStatus.pending) ...[
                  if (widget.type != VolunteerDocumentType.contract)
                    FilledButton.tonalIcon(
                      onPressed: _busy
                          ? null
                          : () => _review(VolunteerDocumentStatus.approved),
                      icon: const Icon(Icons.check),
                      label: const Text('Valider'),
                    ),
                  OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _review(VolunteerDocumentStatus.rejected),
                    icon: const Icon(Icons.close),
                    label: const Text('Refuser'),
                  ),
                ],
              ],
            ),
            if (document?.storagePath case final path?) ...[
              const SizedBox(height: 4),
              InlineDocumentPreview(
                storagePath: path,
                title: label,
                loadSignedUrl: () => ref
                    .read(volunteerDocumentRepositoryProvider)
                    .signedUrl(path),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _uploadButtonLabel(VolunteerDocument? document) {
    if (widget.type == VolunteerDocumentType.contract) {
      return 'Déposer la version contresignée';
    }
    return document?.hasFile == true ? 'Remplacer' : 'Ajouter pour le bénévole';
  }
}
