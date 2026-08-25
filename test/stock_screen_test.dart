import 'package:club_sandwich/design_system/tokens/ds_theme.dart';
import 'package:club_sandwich/features/consumables/data/consumable_providers.dart';
import 'package:club_sandwich/features/equipment/data/equipment_providers.dart';
import 'package:club_sandwich/features/stock/presentation/stock_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('sépare consommables et parc matériel sur la page Stock', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          consumablesProvider.overrideWith((ref) async => const []),
          equipmentAssetsProvider.overrideWith((ref) async => const []),
        ],
        child: MaterialApp(theme: DsTheme.light, home: const StockScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Stock'), findsOneWidget);
    expect(find.text('Aucun consommable'), findsOneWidget);
    expect(find.text('Aucun matériel'), findsNothing);

    await tester.tap(find.text('Parc matériel'));
    await tester.pumpAndSettle();

    expect(find.text('Aucun consommable'), findsNothing);
    expect(find.text('Aucun matériel'), findsOneWidget);
  });

  testWidgets('peut ouvrir directement la section matériel', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          consumablesProvider.overrideWith((ref) async => const []),
          equipmentAssetsProvider.overrideWith((ref) async => const []),
        ],
        child: MaterialApp(
          theme: DsTheme.light,
          home: const StockScreen(initialSection: StockSection.equipment),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Aucun matériel'), findsOneWidget);
    expect(find.text('Aucun consommable'), findsNothing);
  });

  testWidgets('reste utilisable à 320 px dans les deux sections', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 800);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          consumablesProvider.overrideWith((ref) async => const []),
          equipmentAssetsProvider.overrideWith((ref) async => const []),
        ],
        child: MaterialApp(theme: DsTheme.light, home: const StockScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Aucun consommable'), findsOneWidget);
    await tester.tap(find.text('Parc matériel'));
    await tester.pumpAndSettle();
    expect(find.text('Aucun matériel'), findsOneWidget);
  });
}
