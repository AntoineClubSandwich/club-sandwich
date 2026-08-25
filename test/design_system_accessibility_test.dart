import 'package:club_sandwich/design_system/components/buttons/ds_primary_button.dart';
import 'package:club_sandwich/design_system/components/ds_reveal_on_scroll.dart';
import 'package:club_sandwich/design_system/tokens/ds_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('un bouton du design system est focalisable et activable', (
    tester,
  ) async {
    var activationCount = 0;
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        theme: DsTheme.light,
        home: Scaffold(
          body: DsPrimaryButton(
            label: 'Continuer',
            onPressed: () => activationCount += 1,
          ),
        ),
      ),
    );

    final button = find.text('Continuer');
    final semanticsNode = tester.getSemantics(button);
    expect(semanticsNode.flagsCollection.isButton, isTrue);
    expect(
      semanticsNode.getSemanticsData().hasAction(SemanticsAction.tap),
      isTrue,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(activationCount, 1);
    final size = tester.getSize(find.byType(DsPrimaryButton));
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, 48);
    semantics.dispose();
  });

  testWidgets('la barre espace active également le contrôle focalisé', (
    tester,
  ) async {
    var activationCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: DsTheme.light,
        home: Scaffold(
          body: DsPrimaryButton(
            label: 'Valider',
            onPressed: () => activationCount += 1,
          ),
        ),
      ),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();

    expect(activationCount, 1);
  });

  testWidgets(
    'les révélations décoratives sont supprimées en mouvement réduit',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: DsRevealOnScroll(child: Text('Contenu accessible')),
          ),
        ),
      );

      expect(find.text('Contenu accessible'), findsOneWidget);
      expect(find.byType(AnimatedOpacity), findsNothing);
      expect(find.byType(AnimatedSlide), findsNothing);
    },
  );
}
