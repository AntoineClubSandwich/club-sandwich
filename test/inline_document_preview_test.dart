import 'package:club_sandwich/shared/widgets/inline_document_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('charge une URL signée seulement à l’ouverture de la preview', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: InlineDocumentPreview(
              storagePath: 'user/contract.pdf',
              title: 'Contrat de bénévolat',
              loadSignedUrl: () async {
                calls += 1;
                return 'https://example.test/contract.pdf?token=signed';
              },
            ),
          ),
        ),
      ),
    );

    expect(calls, 0);
    expect(find.text('Prévisualiser'), findsOneWidget);

    await tester.tap(find.text('Prévisualiser'));
    await tester.pumpAndSettle();

    expect(calls, 1);
    expect(find.text('Masquer le document'), findsOneWidget);
    expect(
      find.text('La prévisualisation PDF est disponible sur le Web.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Masquer le document'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Prévisualiser'));
    await tester.pumpAndSettle();

    expect(calls, 1);
  });
}
