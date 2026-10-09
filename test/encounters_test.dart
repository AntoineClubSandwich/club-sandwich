import 'package:club_sandwich/features/auth/application/auth_providers.dart';
import 'package:club_sandwich/features/auth/domain/user_account.dart';
import 'package:club_sandwich/features/concerts/data/concert_providers.dart';
import 'package:club_sandwich/features/concerts/domain/concert.dart';
import 'package:club_sandwich/features/consumables/domain/consumable.dart';
import 'package:club_sandwich/features/distributions/domain/maraude_distribution.dart';
import 'package:club_sandwich/features/encounters/data/encounter_location_service.dart';
import 'package:club_sandwich/features/encounters/data/encounter_providers.dart';
import 'package:club_sandwich/features/encounters/data/encounter_repository.dart';
import 'package:club_sandwich/features/encounters/domain/encounter_cluster.dart';
import 'package:club_sandwich/features/encounters/domain/maraude_encounter.dart';
import 'package:club_sandwich/features/encounters/presentation/encounter_map_screen.dart';
import 'package:club_sandwich/features/equipment/domain/equipment_asset.dart';
import 'package:club_sandwich/features/operations/data/maraude_operation_providers.dart';
import 'package:club_sandwich/features/operations/data/maraude_operation_repository.dart';
import 'package:club_sandwich/features/operations/domain/maraude_workflow.dart';
import 'package:club_sandwich/features/operations/presentation/maraude_operation_screen.dart';
import 'package:club_sandwich/features/volunteers/data/concert_volunteer_providers.dart';
import 'package:club_sandwich/features/volunteers/domain/concert_volunteer_application.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('Rencontres', () {
    test('parse les données groupées de la carte Admin', () {
      final encounter = MaraudeEncounter.fromJson({
        'id': 'encounter-1',
        'maraude_id': 'maraude-1',
        'latitude': 48.856614,
        'longitude': 2.3522219,
        'accuracy': 18.46,
        'created_at': '2026-08-25T22:14:00Z',
        'maraude_date': '2026-08-25',
        'artist': 'Beyoncé',
        'venue_id': 'venue-1',
        'venue_name': 'L’Olympia',
        'created_by': 'user-1',
        'created_by_name': 'Hugo Martin',
        'team_names': ['Hugo Martin', 'Inès Dupont'],
      });

      expect(encounter.latitude, 48.856614);
      expect(encounter.longitude, 2.3522219);
      expect(encounter.artist, 'Beyoncé');
      expect(encounter.teamNames, ['Hugo Martin', 'Inès Dupont']);
    });

    test('calcule les KPI sans confondre rencontres et maraudes', () {
      final summary = EncounterMapSummary.from([
        _encounter('1', maraudeId: 'm1', latitude: 48.857),
        _encounter('2', maraudeId: 'm1', latitude: 48.857),
        _encounter('3', maraudeId: 'm2', latitude: 48.86),
      ]);

      expect(summary.encounterCount, 3);
      expect(summary.maraudeCount, 2);
      expect(summary.encountersPerMaraude, 1.5);
      expect(summary.activeZoneCount, 2);
    });

    test('regroupe les points proches puis les sépare en zoomant', () {
      final encounters = [
        _encounter('1', latitude: 48.856, longitude: 2.351),
        _encounter('2', latitude: 48.857, longitude: 2.352),
      ];

      expect(clusterEncounters(encounters, 10), hasLength(1));
      expect(clusterEncounters(encounters, 17), hasLength(2));
    });

    testWidgets('la carte Admin gère un résultat vide', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1280, 850);
      addTearDown(() {
        tester.view.resetDevicePixelRatio();
        tester.view.resetPhysicalSize();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserContextProvider.overrideWith(
              (ref) async => const CurrentUserContext(
                profileId: 'admin-1',
                role: AppUserRole.admin,
                status: UserAccountStatus.active,
              ),
            ),
            adminEncounterMapProvider.overrideWith(
              (ref, period) async => const [],
            ),
          ],
          child: const MaterialApp(home: EncounterMapScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Carte des rencontres'), findsOneWidget);
      expect(find.text('Aucune rencontre pour ces filtres.'), findsOneWidget);
      expect(find.text('Points'), findsOneWidget);
      expect(find.text('Clusters'), findsOneWidget);
      expect(find.text('Carte de chaleur'), findsOneWidget);
    });

    testWidgets('Distribution enregistre une rencontre en une action', (
      tester,
    ) async {
      final repository = _FakeEncounterRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserContextProvider.overrideWith(
              (ref) async => const CurrentUserContext(
                profileId: 'user-1',
                role: AppUserRole.volunteer,
                status: UserAccountStatus.active,
              ),
            ),
            concertDetailsProvider(
              'maraude-1',
            ).overrideWith((ref) async => _concert),
            concertVolunteerSectionProvider('maraude-1').overrideWith(
              (ref) async => const ConcertVolunteerSectionData(
                counts: ConcertVolunteerCounts.empty(),
                isAdmin: false,
                applications: [],
              ),
            ),
            maraudeOperationBundleProvider(
              'maraude-1',
            ).overrideWith((ref) async => _bundle),
            encounterLocationServiceProvider.overrideWithValue(
              const _FakeLocationService(),
            ),
            encounterRepositoryProvider.overrideWithValue(repository),
          ],
          child: const MaterialApp(
            home: MaraudeOperationScreen(concertId: 'maraude-1'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('2 rencontres enregistrées'), findsOneWidget);
      final recordButton = find.text('Enregistrer une rencontre');
      await tester.ensureVisible(recordButton);
      await tester.pumpAndSettle();
      await tester.tap(recordButton);
      await tester.pumpAndSettle();

      expect(repository.recordCalls, 1);
      expect(repository.lastMaraudeId, 'maraude-1');
      expect(find.text('Rencontre enregistrée ✓'), findsOneWidget);
    });

    testWidgets(
      'Distribution déduit les boîtes distribuées des boîtes remises au stock',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currentUserContextProvider.overrideWith(
                (ref) async => const CurrentUserContext(
                  profileId: 'user-1',
                  role: AppUserRole.volunteer,
                  status: UserAccountStatus.active,
                ),
              ),
              concertDetailsProvider(
                'maraude-1',
              ).overrideWith((ref) async => _concert),
              concertVolunteerSectionProvider('maraude-1').overrideWith(
                (ref) async => const ConcertVolunteerSectionData(
                  counts: ConcertVolunteerCounts.empty(),
                  isAdmin: false,
                  applications: [],
                ),
              ),
              maraudeOperationBundleProvider(
                'maraude-1',
              ).overrideWith((ref) async => _bundle),
            ],
            child: const MaterialApp(
              home: MaraudeOperationScreen(concertId: 'maraude-1'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('50 boîtes emportées · 2 références'), findsOneWidget);
        expect(find.text('Boîtes alimentaires'), findsOneWidget);
        expect(find.text('Petites barquettes'), findsOneWidget);
        // Rien n'a encore été remis au stock : tout est à distribuer.
        expect(find.text('38 boîtes distribuées'), findsOneWidget);
        expect(find.text('12 boîtes distribuées'), findsOneWidget);
        expect(find.text('Boîtes remises au stock'), findsNWidgets(2));

        await tester.enterText(
          find.byKey(const ValueKey('returned-allocation-1')),
          '13',
        );
        await tester.enterText(
          find.byKey(const ValueKey('returned-allocation-2')),
          '11',
        );
        await tester.pump();

        expect(find.text('25 boîtes distribuées'), findsOneWidget);
        expect(find.text('1 boîte distribuée'), findsOneWidget);
      },
    );

    testWidgets('la distribution envoie les boîtes remises au stock', (
      tester,
    ) async {
      final repository = _FakeOperationRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserContextProvider.overrideWith(
              (ref) async => const CurrentUserContext(
                profileId: 'admin-1',
                role: AppUserRole.admin,
                status: UserAccountStatus.active,
              ),
            ),
            concertDetailsProvider(
              'maraude-1',
            ).overrideWith((ref) async => _concert),
            concertVolunteerSectionProvider('maraude-1').overrideWith(
              (ref) async => const ConcertVolunteerSectionData(
                counts: ConcertVolunteerCounts.empty(),
                isAdmin: true,
                applications: [],
              ),
            ),
            maraudeOperationRepositoryProvider.overrideWithValue(repository),
            maraudeOperationBundleProvider(
              'maraude-1',
            ).overrideWith((ref) async => _bundle),
          ],
          child: const MaterialApp(
            home: MaraudeOperationScreen(concertId: 'maraude-1'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('returned-allocation-1')),
        '13',
      );
      await tester.enterText(
        find.byKey(const ValueKey('returned-allocation-2')),
        '2',
      );
      final finish = find.text('Terminer la distribution');
      await tester.ensureVisible(finish);
      await tester.pumpAndSettle();
      await tester.tap(finish);
      await tester.pumpAndSettle();

      expect(repository.lastReturnedBoxes, {
        'allocation-1': 13,
        'allocation-2': 2,
      });
    });

    testWidgets('on ne peut pas remettre plus de boîtes que celles emportées', (
      tester,
    ) async {
      final repository = _FakeOperationRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserContextProvider.overrideWith(
              (ref) async => const CurrentUserContext(
                profileId: 'admin-1',
                role: AppUserRole.admin,
                status: UserAccountStatus.active,
              ),
            ),
            concertDetailsProvider(
              'maraude-1',
            ).overrideWith((ref) async => _concert),
            concertVolunteerSectionProvider('maraude-1').overrideWith(
              (ref) async => const ConcertVolunteerSectionData(
                counts: ConcertVolunteerCounts.empty(),
                isAdmin: true,
                applications: [],
              ),
            ),
            maraudeOperationRepositoryProvider.overrideWithValue(repository),
            maraudeOperationBundleProvider(
              'maraude-1',
            ).overrideWith((ref) async => _bundle),
          ],
          child: const MaterialApp(
            home: MaraudeOperationScreen(concertId: 'maraude-1'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('returned-allocation-2')),
        '13',
      );
      final finish = find.text('Terminer la distribution');
      await tester.ensureVisible(finish);
      await tester.pumpAndSettle();
      await tester.tap(finish);
      await tester.pumpAndSettle();

      expect(repository.lastReturnedBoxes, isNull);
      expect(
        find.textContaining('ne peuvent pas dépasser les 12 emportées'),
        findsOneWidget,
      );
    });

    testWidgets('le retour matériel se valide d’un seul OUI', (tester) async {
      final repository = _FakeOperationRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserContextProvider.overrideWith(
              (ref) async => const CurrentUserContext(
                profileId: 'admin-1',
                role: AppUserRole.admin,
                status: UserAccountStatus.active,
              ),
            ),
            concertDetailsProvider(
              'maraude-1',
            ).overrideWith((ref) async => _concert),
            concertVolunteerSectionProvider('maraude-1').overrideWith(
              (ref) async => const ConcertVolunteerSectionData(
                counts: ConcertVolunteerCounts.empty(),
                isAdmin: true,
                applications: [],
              ),
            ),
            maraudeOperationRepositoryProvider.overrideWithValue(repository),
            maraudeOperationBundleProvider(
              'maraude-1',
            ).overrideWith((ref) async => _equipmentReturnBundle),
          ],
          child: const MaterialApp(
            home: MaraudeOperationScreen(concertId: 'maraude-1'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('4. Retour matériel'), findsOneWidget);
      expect(
        find.text('Le matériel est-il restitué et propre ?'),
        findsOneWidget,
      );
      expect(
        find.textContaining('les sacs, les cabas et le pack logistique'),
        findsOneWidget,
      );
      await tester.tap(find.text('OUI'));
      await tester.pumpAndSettle();

      expect(repository.equipmentReturnCount, 1);
      expect(repository.lastEquipmentReturns, hasLength(1));
      expect(repository.lastEquipmentReturns!.single.allocationId, 'equip-1');
      expect(repository.lastEquipmentReturns!.single.returnedQuantity, 3);
      expect(repository.lastEquipmentReturns!.single.incidentType, isNull);
      expect(repository.stepValidationCount, 1);
      expect(find.text('Retour matériel validé.'), findsOneWidget);
    });

    testWidgets('on peut signaler un problème matériel au retour', (
      tester,
    ) async {
      final repository = _FakeOperationRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserContextProvider.overrideWith(
              (ref) async => const CurrentUserContext(
                profileId: 'admin-1',
                role: AppUserRole.admin,
                status: UserAccountStatus.active,
              ),
            ),
            concertDetailsProvider(
              'maraude-1',
            ).overrideWith((ref) async => _concert),
            concertVolunteerSectionProvider('maraude-1').overrideWith(
              (ref) async => const ConcertVolunteerSectionData(
                counts: ConcertVolunteerCounts.empty(),
                isAdmin: true,
                applications: [],
              ),
            ),
            maraudeOperationRepositoryProvider.overrideWithValue(repository),
            maraudeOperationBundleProvider(
              'maraude-1',
            ).overrideWith((ref) async => _equipmentReturnBundle),
          ],
          child: const MaterialApp(
            home: MaraudeOperationScreen(concertId: 'maraude-1'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Signaler un problème'));
      await tester.pumpAndSettle();
      // Sans problème choisi, on ne peut pas valider par ce chemin.
      final validate = find.text('Valider le retour avec ces problèmes');
      await tester.ensureVisible(validate);
      await tester.pumpAndSettle();
      await tester.tap(validate);
      await tester.pumpAndSettle();
      expect(repository.equipmentReturnCount, 0);

      await tester.tap(find.text('Aucun problème'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('À nettoyer').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Précisions (quantité, état…)'),
        'Sale',
      );
      await tester.ensureVisible(validate);
      await tester.pumpAndSettle();
      await tester.tap(validate);
      await tester.pumpAndSettle();

      expect(repository.equipmentReturnCount, 1);
      final sent = repository.lastEquipmentReturns!.single;
      expect(sent.allocationId, 'equip-1');
      expect(sent.incidentType, EquipmentIncidentType.needsCleaning);
      expect(sent.incidentNote, 'Sale');
      expect(repository.stepValidationCount, 1);
    });

    testWidgets('une validation ouvre automatiquement l’étape suivante', (
      tester,
    ) async {
      final repository = _FakeOperationRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserContextProvider.overrideWith(
              (ref) async => const CurrentUserContext(
                profileId: 'admin-1',
                role: AppUserRole.admin,
                status: UserAccountStatus.active,
              ),
            ),
            concertDetailsProvider(
              'maraude-1',
            ).overrideWith((ref) async => _concert),
            concertVolunteerSectionProvider('maraude-1').overrideWith(
              (ref) async => const ConcertVolunteerSectionData(
                counts: ConcertVolunteerCounts.empty(),
                isAdmin: true,
                applications: [],
              ),
            ),
            maraudeOperationRepositoryProvider.overrideWithValue(repository),
            maraudeOperationBundleProvider(
              'maraude-1',
            ).overrideWith((ref) async => _preparationBundle),
          ],
          child: const MaterialApp(
            home: MaraudeOperationScreen(concertId: 'maraude-1'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1. Préparation'), findsOneWidget);
      expect(
        find.text('Avez-vous bien tout le matériel nécessaire ?'),
        findsOneWidget,
      );
      expect(
        find.textContaining('les sacs, les cabas et le pack logistique'),
        findsOneWidget,
      );
      // Tant que le matériel n'est pas confirmé, on ne peut pas continuer.
      final validate = find.text('Valider et continuer');
      await tester.ensureVisible(validate);
      await tester.pumpAndSettle();
      await tester.tap(validate);
      await tester.pumpAndSettle();
      expect(repository.preparationValidationCount, 0);

      await tester.tap(find.text('OUI'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(validate);
      await tester.pumpAndSettle();
      await tester.tap(validate);
      await tester.pumpAndSettle();

      expect(repository.preparationValidationCount, 1);
      expect(find.text('2. Collecte catering'), findsOneWidget);
      expect(find.text('Préparation validée.'), findsOneWidget);
    });
  });
}

MaraudeEncounter _encounter(
  String id, {
  String maraudeId = 'maraude-1',
  double latitude = 48.856,
  double longitude = 2.352,
}) => MaraudeEncounter(
  id: id,
  maraudeId: maraudeId,
  latitude: latitude,
  longitude: longitude,
  accuracy: 20,
  createdAt: DateTime.utc(2026, 8, 25),
  createdBy: 'user-1',
);

final _concert = Concert(
  id: 'maraude-1',
  organizationId: 'organization-1',
  artist: 'Beyoncé',
  date: DateTime(2026, 8, 25),
  status: ConcertStatus.confirmed,
  maraudeStatus: MaraudeStatus.inProgress,
  createdBy: 'admin-1',
  createdAt: DateTime(2026, 8, 1),
  updatedAt: DateTime(2026, 8, 25),
);

final _bundle = MaraudeOperationBundle(
  operation: MaraudeOperation(
    concertId: 'maraude-1',
    currentStep: MaraudeOperationalStep.distribution,
    createdAt: DateTime(2026, 8, 25),
    updatedAt: DateTime(2026, 8, 25),
  ),
  consumables: const [
    MaraudeConsumableAllocation(
      id: 'allocation-1',
      concertId: 'maraude-1',
      consumableId: 'consumable-1',
      name: 'Boîtes alimentaires',
      unit: InventoryUnit.box,
      plannedQuantity: 40,
      actualQuantity: 38,
      availableQuantity: 262,
    ),
    MaraudeConsumableAllocation(
      id: 'allocation-2',
      concertId: 'maraude-1',
      consumableId: 'consumable-2',
      name: 'Petites barquettes',
      unit: InventoryUnit.box,
      plannedQuantity: 12,
      actualQuantity: 12,
      availableQuantity: 88,
    ),
  ],
  equipment: const [],
  collections: const [],
  history: const [],
  encounterCount: 2,
);

final _preparationBundle = MaraudeOperationBundle(
  operation: MaraudeOperation(
    concertId: 'maraude-1',
    currentStep: MaraudeOperationalStep.preparation,
    createdAt: DateTime(2026, 8, 25),
    updatedAt: DateTime(2026, 8, 25),
  ),
  consumables: const [],
  equipment: const [],
  collections: const [],
  history: const [],
);

final _equipmentReturnBundle = MaraudeOperationBundle(
  operation: MaraudeOperation(
    concertId: 'maraude-1',
    currentStep: MaraudeOperationalStep.equipmentReturn,
    createdAt: DateTime(2026, 8, 25),
    updatedAt: DateTime(2026, 8, 25),
  ),
  consumables: const [],
  equipment: const [
    MaraudeEquipmentAllocation(
      id: 'equip-1',
      concertId: 'maraude-1',
      equipmentId: 'asset-1',
      name: 'Glacières',
      status: EquipmentStatus.inUse,
      quantityTotal: 4,
      plannedQuantity: 3,
      takenQuantity: 3,
    ),
  ],
  collections: const [],
  history: const [],
);

class _FakeLocationService extends EncounterLocationService {
  const _FakeLocationService();

  @override
  Future<EncounterPosition> currentPosition() async => const EncounterPosition(
    latitude: 48.8566,
    longitude: 2.3522,
    accuracy: 18,
  );
}

class _FakeEncounterRepository extends EncounterRepository {
  _FakeEncounterRepository()
    : super(
        SupabaseClient(
          'https://example.supabase.co',
          'test-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );

  int recordCalls = 0;
  String? lastMaraudeId;

  @override
  Future<MaraudeEncounter> record({
    required String maraudeId,
    required double latitude,
    required double longitude,
    required double accuracy,
  }) async {
    recordCalls++;
    lastMaraudeId = maraudeId;
    return MaraudeEncounter(
      id: 'saved',
      maraudeId: maraudeId,
      latitude: latitude,
      longitude: longitude,
      accuracy: accuracy,
      createdAt: DateTime.utc(2026, 8, 25),
      createdBy: 'user-1',
    );
  }
}

class _FakeOperationRepository extends MaraudeOperationRepository {
  _FakeOperationRepository()
    : super(
        SupabaseClient(
          'https://example.supabase.co',
          'test-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );

  int preparationValidationCount = 0;
  Map<String, int>? lastReturnedBoxes;
  int equipmentReturnCount = 0;
  int stepValidationCount = 0;

  @override
  Future<void> validatePreparation({
    required String concertId,
    required Map<String, double> consumableQuantities,
    required Map<String, int> equipmentQuantities,
  }) async {
    preparationValidationCount++;
  }

  @override
  Future<MaraudeDistribution> saveDistribution({
    required String concertId,
    required Map<String, int> returnedBoxesByAllocation,
    required int beneficiaries,
    String? comment,
  }) async {
    lastReturnedBoxes = returnedBoxesByAllocation;
    return MaraudeDistribution(
      id: 'distribution-1',
      concertId: concertId,
      estimatedBeneficiaries: beneficiaries,
      createdAt: DateTime(2026, 8, 25),
      updatedAt: DateTime(2026, 8, 25),
    );
  }

  @override
  Future<void> recordEquipmentReturn({
    required String concertId,
    required List<EquipmentReturnDraft> returns,
  }) async {
    equipmentReturnCount++;
    lastEquipmentReturns = returns;
  }

  @override
  Future<void> validateStep(
    String concertId,
    MaraudeOperationalStep step,
  ) async {
    stepValidationCount++;
  }

  List<EquipmentReturnDraft>? lastEquipmentReturns;
}
