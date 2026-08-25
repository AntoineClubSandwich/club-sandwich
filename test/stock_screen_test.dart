import 'package:club_sandwich/design_system/tokens/ds_theme.dart';
import 'package:club_sandwich/features/consumables/data/consumable_providers.dart';
import 'package:club_sandwich/features/consumables/domain/consumable.dart';
import 'package:club_sandwich/features/equipment/data/equipment_providers.dart';
import 'package:club_sandwich/features/equipment/domain/equipment_asset.dart';
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

  testWidgets('le consommable sélectionne un emplacement partagé', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          consumablesProvider.overrideWith((ref) async => const []),
          equipmentAssetsProvider.overrideWith((ref) async => const []),
          equipmentLocationsProvider.overrideWith(
            (ref) async => const [
              EquipmentLocation(id: 'cave-id', name: 'Cave', isActive: true),
              EquipmentLocation(id: 'local-id', name: 'Local', isActive: true),
            ],
          ),
        ],
        child: MaterialApp(theme: DsTheme.light, home: const StockScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Nouveau consommable'));
    await tester.pumpAndSettle();

    expect(find.text('Créer un emplacement'), findsOneWidget);
    final selector = find.byType(DropdownButtonFormField<String?>);
    expect(selector, findsOneWidget);
    await tester.tap(selector);
    await tester.pumpAndSettle();

    expect(find.text('Cave'), findsOneWidget);
    expect(find.text('Local'), findsOneWidget);
  });

  testWidgets('un ancien emplacement libre reste sélectionné en modification', (
    tester,
  ) async {
    final item = Consumable(
      id: 'item-id',
      name: 'Petites boîtes',
      category: 'Conditionnement',
      currentQuantity: 300,
      unit: InventoryUnit.box,
      alertThreshold: 100,
      storageLocation: 'Ancienne cave',
      isArchived: false,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          consumablesProvider.overrideWith((ref) async => [item]),
          equipmentAssetsProvider.overrideWith((ref) async => const []),
          equipmentLocationsProvider.overrideWith((ref) async => const []),
        ],
        child: MaterialApp(theme: DsTheme.light, home: const StockScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Modifier').last);
    await tester.pumpAndSettle();

    final selector = tester.widget<DropdownButtonFormField<String?>>(
      find.byType(DropdownButtonFormField<String?>),
    );
    expect(selector.initialValue, 'Ancienne cave');
  });
}
