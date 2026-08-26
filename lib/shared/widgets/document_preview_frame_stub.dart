import 'package:flutter/material.dart';

class DocumentPreviewFrame extends StatelessWidget {
  const DocumentPreviewFrame({
    super.key,
    required this.url,
    required this.title,
  });

  final String url;
  final String title;

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('La prévisualisation PDF est disponible sur le Web.'),
    );
  }
}
