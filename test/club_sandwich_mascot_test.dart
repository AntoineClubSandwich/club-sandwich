import 'package:club_sandwich/design_system/widgets/club_sandwich_mascot.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('affiche la variante bleue sans exception', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Center(child: ClubSandwichMascot(size: 96))),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SvgPicture), findsOneWidget);
    expect(tester.takeException(), isNull);

    final svgWidget = tester.widget<SvgPicture>(find.byType(SvgPicture));
    final size = svgWidget.width;
    expect(size, 96);
  });

  testWidgets('affiche la variante orange sans exception', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: ClubSandwichMascot(size: 48, color: MascotColor.orange),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SvgPicture), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
