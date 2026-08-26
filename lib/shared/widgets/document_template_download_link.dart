import 'package:club_sandwich/shared/data/document_template_providers.dart';
import 'package:club_sandwich/shared/data/document_template_repository.dart';
import 'package:club_sandwich/shared/utils/error_messages.dart';
import 'package:club_sandwich/shared/widgets/inline_document_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

class DocumentTemplateDownloadLink extends ConsumerWidget {
  const DocumentTemplateDownloadLink({super.key, required this.templateKey});
  final DocumentTemplateKey templateKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final template = ref.watch(documentTemplateProvider(templateKey));
    return template.maybeWhen(
      data: (value) {
        if (value == null) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextButton.icon(
              onPressed: () => _open(context, ref, value.storagePath),
              icon: const Icon(Icons.download_outlined),
              label: const Text('Télécharger le modèle vierge'),
            ),
            InlineDocumentPreview(
              storagePath: value.storagePath,
              title: templateKey.label,
              loadSignedUrl: () => ref
                  .read(documentTemplateRepositoryProvider)
                  .signedUrl(value.storagePath),
            ),
          ],
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }

  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    String storagePath,
  ) async {
    try {
      final url = await ref
          .read(documentTemplateRepositoryProvider)
          .signedUrl(storagePath);
      await launchUrl(Uri.parse(url));
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              describeError(error, 'Impossible d’ouvrir le modèle.'),
            ),
          ),
        );
      }
    }
  }
}
