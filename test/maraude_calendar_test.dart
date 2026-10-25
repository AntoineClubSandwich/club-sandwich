import 'package:club_sandwich/design_system/tokens/ds_theme.dart';
import 'package:club_sandwich/features/concerts/presentation/maraude_calendar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Lancer avec TZ=Europe/Paris pour reproduire : le 25/10/2026 dure 25 h.
  testWidgets('month grid does not shift days across a DST change', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: DsTheme.light,
        home: Scaffold(
          body: SingleChildScrollView(
            child: MaraudeCalendar(
              month: DateTime(2026, 10),
              items: [
                MaraudeCalendarItem(
                  id: 'after-dst',
                  artist: 'Artiste',
                  date: DateTime(2026, 10, 26),
                  venueName: 'Olympia',
                  selectedVolunteerCount: 0,
                  statusLabel: 'Ouverte',
                  tone: MaraudeCalendarTone.blue,
                ),
              ],
              onPreviousMonth: () {},
              onNextMonth: () {},
              onToday: () {},
              onOpen: (_) {},
            ),
          ),
        ),
      ),
    );

    // Grille du lundi 28/09 au dimanche 08/11 : le 25 n'est pas dupliqué
    // et la grille se termine bien le 8 novembre (pas le 7).
    expect(find.text('25'), findsOneWidget);
    expect(find.text('8'), findsNWidgets(2));
    expect(find.text('9'), findsOneWidget);

    // Le lundi 26 reste dans la colonne « Lun », sous le lundi 19.
    final lunX = tester.getCenter(find.text('Lun')).dx;
    final cell19 = tester.getCenter(find.text('19'));
    final cell26 = tester.getCenter(find.text('26'));
    expect(cell26.dx, closeTo(cell19.dx, 0.5));
    expect((cell26.dx - lunX).abs(), lessThan(100));

    // La maraude du 26 est affichée dans la case du 26.
    final tile = tester.getCenter(find.text('Artiste'));
    expect(tile.dx, closeTo(cell26.dx, 100));
    expect(tile.dy, greaterThan(cell26.dy));
  });
}
