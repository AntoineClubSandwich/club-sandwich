import 'package:club_sandwich/features/administration/presentation/administration_screen.dart';
import 'package:club_sandwich/features/auth/application/auth_providers.dart';
import 'package:club_sandwich/features/organizations/data/organization_providers.dart';
import 'package:club_sandwich/shared/data/document_template_providers.dart';
import 'package:club_sandwich/shared/data/document_template_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'l’écran d’administration affiche l’état des modèles de documents',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1280, 900);
      addTearDown(() {
        tester.view.resetDevicePixelRatio();
        tester.view.resetPhysicalSize();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            managedUsersProvider.overrideWith((ref) async => const []),
            organizationsProvider.overrideWith((ref) async => const []),
            documentTemplateProvider(
              DocumentTemplateKey.volunteerContract,
            ).overrideWith(
              (ref) async => const DocumentTemplate(
                key: 'volunteer_contract',
                storagePath: 'document-templates/volunteer_contract.pdf',
              ),
            ),
            documentTemplateProvider(
              DocumentTemplateKey.organizationConvention,
            ).overrideWith((ref) async => null),
          ],
          child: const MaterialApp(home: AdministrationScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.dragUntilVisible(
        find.text('Modèles de documents'),
        find.byType(ListView),
        const Offset(0, -300),
      );

      expect(find.text('Modèles de documents'), findsOneWidget);
      expect(find.text('Contrat de bénévolat (modèle vierge)'), findsOneWidget);
      expect(
        find.text('Convention de partenariat (modèle vierge)'),
        findsOneWidget,
      );
      expect(find.text('Télécharger le modèle vierge'), findsOneWidget);
      expect(find.text('Remplacer'), findsOneWidget);
      expect(find.text('Déposer'), findsOneWidget);
    },
  );
}
