import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

class DocumentPreviewFrame extends StatefulWidget {
  const DocumentPreviewFrame({
    super.key,
    required this.url,
    required this.title,
  });

  final String url;
  final String title;

  @override
  State<DocumentPreviewFrame> createState() => _DocumentPreviewFrameState();
}

class _DocumentPreviewFrameState extends State<DocumentPreviewFrame> {
  late final String _viewType;

  @override
  void initState() {
    super.initState();
    _viewType = 'document-preview-${identityHashCode(this)}';
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (viewId) {
      return web.HTMLIFrameElement()
        ..src = widget.url
        ..title = widget.title
        ..setAttribute('loading', 'lazy')
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.border = '0';
    });
  }

  @override
  Widget build(BuildContext context) => HtmlElementView(viewType: _viewType);
}
