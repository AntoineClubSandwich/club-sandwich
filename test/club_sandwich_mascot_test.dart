import 'package:club_sandwich/design_system/widgets/club_sandwich_mascot.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('affiche le logo officiel bleu sans exception', (tester) async {
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

  testWidgets('respecte la taille demandée', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Center(child: ClubSandwichMascot(size: 48))),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SvgPicture), findsOneWidget);
    expect(tester.takeException(), isNull);

    final svgWidget = tester.widget<SvgPicture>(find.byType(SvgPicture));
    expect(svgWidget.width, 48);
    expect(svgWidget.height, 48);
  });
}
