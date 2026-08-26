import 'package:club_sandwich/shared/utils/error_messages.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'document_preview_frame.dart';

typedef SignedDocumentUrlLoader = Future<String> Function();

/// Displays a private document inside its current page. The signed URL is
/// requested only when the preview is expanded and is not shared between
/// documents.
class InlineDocumentPreview extends StatefulWidget {
  const InlineDocumentPreview({
    super.key,
    required this.storagePath,
    required this.loadSignedUrl,
    required this.title,
  });

  final String storagePath;
  final SignedDocumentUrlLoader loadSignedUrl;
  final String title;

  @override
  State<InlineDocumentPreview> createState() => _InlineDocumentPreviewState();
}

class _InlineDocumentPreviewState extends State<InlineDocumentPreview> {
  bool _expanded = false;
  Future<String>? _url;

  bool get _isImage {
    final path = widget.storagePath.toLowerCase();
    return path.endsWith('.jpg') ||
        path.endsWith('.jpeg') ||
        path.endsWith('.png') ||
        path.endsWith('.webp');
  }

  void _toggle() {
    setState(() {
      _expanded = !_expanded;
      if (_expanded) _url ??= widget.loadSignedUrl();
    });
  }

  Future<void> _openExternally(String url) async {
    final opened = await launchUrl(Uri.parse(url), webOnlyWindowName: '_blank');
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d’ouvrir ce document.')),
      );
    }
  }

  void _retry() {
    setState(() => _url = widget.loadSignedUrl());
  }

  @override
  Widget build(BuildContext context) {
    final previewHeight = MediaQuery.sizeOf(context).width < 600
        ? 360.0
        : 520.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton.icon(
          key: ValueKey('preview-${widget.storagePath}'),
          onPressed: _toggle,
          icon: Icon(
            _expanded
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
          ),
          label: Text(_expanded ? 'Masquer le document' : 'Prévisualiser'),
        ),
        if (_expanded) ...[
          const SizedBox(height: 8),
          FutureBuilder<String>(
            future: _url,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const SizedBox(
                  height: 180,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError || snapshot.data == null) {
                return _PreviewError(
                  message: describeError(
                    snapshot.error ?? Exception(),
                    'Impossible de prévisualiser ce document.',
                  ),
                  onRetry: _retry,
                );
              }
              final url = snapshot.data!;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    height: previewHeight,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: _isImage
                        ? InteractiveViewer(
                            minScale: 0.5,
                            maxScale: 4,
                            child: Image.network(
                              url,
                              fit: BoxFit.contain,
                              errorBuilder: (_, _, _) => _PreviewError(
                                message: 'Impossible d’afficher cette image.',
                                onRetry: _retry,
                              ),
                            ),
                          )
                        : DocumentPreviewFrame(
                            key: ValueKey(url),
                            url: url,
                            title: widget.title,
                          ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => _openExternally(url),
                      icon: const Icon(Icons.open_in_new, size: 18),
                      label: const Text('Ouvrir dans un nouvel onglet'),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ],
    );
  }
}

class _PreviewError extends StatelessWidget {
  const _PreviewError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.broken_image_outlined),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            TextButton(onPressed: onRetry, child: const Text('Réessayer')),
          ],
        ),
      ),
    );
  }
}
