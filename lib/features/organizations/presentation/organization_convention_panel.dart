import 'package:club_sandwich/features/auth/application/auth_providers.dart';
import 'package:club_sandwich/features/auth/domain/user_account.dart';
import 'package:club_sandwich/features/organizations/data/organization_convention_providers.dart';
import 'package:club_sandwich/features/organizations/domain/organization_convention.dart';
import 'package:club_sandwich/features/volunteers/domain/volunteer_document.dart'
    show VolunteerDocumentStatus;
import 'package:club_sandwich/shared/data/document_template_repository.dart';
import 'package:club_sandwich/shared/utils/error_messages.dart';
import 'package:club_sandwich/shared/widgets/app_state_panel.dart';
import 'package:club_sandwich/shared/widgets/document_template_download_link.dart';
import 'package:club_sandwich/shared/widgets/inline_document_preview.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class OrganizationConventionPanel extends ConsumerWidget {
  const OrganizationConventionPanel({super.key, required this.organizationId});
  final String organizationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(currentUserContextProvider).value?.role;
    final convention = ref.watch(
      organizationConventionProvider(organizationId),
    );
    return convention.when(
      loading: () =>
          const AppLoadingState(label: 'Chargement de la convention'),
      error: (_, _) => AppErrorState(
        message: 'Convention indisponible.',
        onRetry: () =>
            ref.invalidate(organizationConventionProvider(organizationId)),
      ),
      data: (value) => role == AppUserRole.admin
          ? _AdminConventionTile(
              organizationId: organizationId,
              convention: value,
            )
          : _PromoterConventionTile(
              organizationId: organizationId,
              convention: value,
            ),
    );
  }
}

class _PromoterConventionTile extends ConsumerStatefulWidget {
  const _PromoterConventionTile({
    required this.organizationId,
    this.convention,
  });
  final String organizationId;
  final OrganizationConvention? convention;

  @override
  ConsumerState<_PromoterConventionTile> createState() =>
      _PromoterConventionTileState();
}

class _PromoterConventionTileState
    extends ConsumerState<_PromoterConventionTile> {
  bool _uploading = false;

  Future<void> _upload() async {
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
    setState(() => _uploading = true);
    try {
      final repository = ref.read(organizationConventionRepositoryProvider);
      final path = await repository.uploadFile(
        organizationId: widget.organizationId,
        bytes: file.bytes!,
        extension: extension,
        contentType: contentType,
      );
      await repository.submitMyConvention(
        organizationId: widget.organizationId,
        storagePath: path,
      );
      ref.invalidate(organizationConventionProvider(widget.organizationId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Convention enregistrée.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              describeError(error, 'Impossible d’envoyer la convention.'),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final convention = widget.convention;
    final colors = Theme.of(context).colorScheme;
    final statusLabel = convention == null || !convention.hasFile
        ? null
        : convention.status == VolunteerDocumentStatus.pending
        ? 'En attente de contre-signature'
        : convention.status.label;
    final (icon, color) = switch (convention?.status) {
      VolunteerDocumentStatus.approved => (
        Icons.check_circle_outline,
        Colors.green,
      ),
      VolunteerDocumentStatus.rejected => (Icons.error_outline, colors.error),
      VolunteerDocumentStatus.pending when convention?.hasFile == true => (
        Icons.hourglass_top_outlined,
        Colors.orange,
      ),
      _ => (Icons.upload_file, colors.outline),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const DocumentTemplateDownloadLink(
          templateKey: DocumentTemplateKey.organizationConvention,
        ),
        const SizedBox(height: 4),
        OutlinedButton.icon(
          onPressed: _uploading ? null : _upload,
          icon: _uploading
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(icon, color: color),
          label: Text(
            statusLabel != null
                ? 'Convention de partenariat - $statusLabel'
                : 'Joindre la convention signée',
          ),
        ),
        if (convention?.storagePath case final path?)
          InlineDocumentPreview(
            storagePath: path,
            title: 'Convention de partenariat',
            loadSignedUrl: () => ref
                .read(organizationConventionRepositoryProvider)
                .signedUrl(path),
          ),
        if (convention?.status == VolunteerDocumentStatus.rejected &&
            convention?.rejectionReason != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              convention!.rejectionReason!,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.error),
            ),
          ),
      ],
    );
  }
}

class _AdminConventionTile extends ConsumerStatefulWidget {
  const _AdminConventionTile({required this.organizationId, this.convention});
  final String organizationId;
  final OrganizationConvention? convention;

  @override
  ConsumerState<_AdminConventionTile> createState() =>
      _AdminConventionTileState();
}

class _AdminConventionTileState extends ConsumerState<_AdminConventionTile> {
  bool _busy = false;

  Future<void> _uploadCountersigned() async {
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
      final repository = ref.read(organizationConventionRepositoryProvider);
      final path = await repository.uploadFile(
        organizationId: widget.organizationId,
        bytes: file.bytes!,
        extension: extension,
        contentType: contentType,
      );
      await repository.adminSetConvention(
        organizationId: widget.organizationId,
        storagePath: path,
      );
      ref.invalidate(organizationConventionProvider(widget.organizationId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Convention contresignée enregistrée.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              describeError(error, 'Impossible d’enregistrer la convention.'),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject() async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Refuser cette convention'),
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
    setState(() => _busy = true);
    try {
      await ref
          .read(organizationConventionRepositoryProvider)
          .reject(
            organizationId: widget.organizationId,
            rejectionReason: reason.trim(),
          );
      ref.invalidate(organizationConventionProvider(widget.organizationId));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(describeError(error, 'Impossible de refuser.')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final convention = widget.convention;
    final colors = Theme.of(context).colorScheme;
    final statusColor = switch (convention?.status) {
      VolunteerDocumentStatus.approved => Colors.green,
      VolunteerDocumentStatus.rejected => colors.error,
      VolunteerDocumentStatus.pending when convention?.hasFile == true =>
        Colors.orange,
      _ => colors.outline,
    };
    final statusLabel = convention?.hasFile == true
        ? convention!.status.label
        : 'Non fourni';
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
                    'Convention de partenariat',
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
            if (convention?.status == VolunteerDocumentStatus.rejected &&
                convention?.rejectionReason != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  convention!.rejectionReason!,
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
                  onPressed: _busy ? null : _uploadCountersigned,
                  icon: _busy
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.upload_file),
                  label: const Text('Déposer la version contresignée'),
                ),
                if (convention?.hasFile == true &&
                    convention?.status == VolunteerDocumentStatus.pending)
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _reject,
                    icon: const Icon(Icons.close),
                    label: const Text('Refuser'),
                  ),
              ],
            ),
            if (convention?.storagePath case final path?) ...[
              const SizedBox(height: 4),
              InlineDocumentPreview(
                storagePath: path,
                title: 'Convention de partenariat',
                loadSignedUrl: () => ref
                    .read(organizationConventionRepositoryProvider)
                    .signedUrl(path),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
