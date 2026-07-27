import 'dart:convert';

import 'package:club_sandwich/features/collections/data/maraude_collection_providers.dart';
import 'package:club_sandwich/features/collections/data/maraude_collection_repository.dart';
import 'package:club_sandwich/features/collections/domain/maraude_collection.dart';
import 'package:club_sandwich/features/concerts/data/concert_providers.dart';
import 'package:club_sandwich/features/concerts/data/concert_repository.dart';
import 'package:club_sandwich/features/concerts/domain/concert.dart';
import 'package:club_sandwich/features/concerts/presentation/concert_detail_screen.dart';
import 'package:club_sandwich/features/volunteers/data/concert_volunteer_providers.dart';
import 'package:club_sandwich/features/volunteers/domain/concert_volunteer_application.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'helpers/test_data.dart';

void main() {
  group('MaraudeCollection', () {
    test('parse, sérialise et compare un lot complet', () {
      final collection = MaraudeCollection.fromJson(_collectionJson());

      expect(collection.category, CollectionCategory.preparedMeals);
      expect(collection.quantity, 25);
      expect(collection.unit, CollectionUnit.piece);
      expect(collection.weightKg, 12.5);
      expect(collection, MaraudeCollection.fromJson(collection.toJson()));
    });

    test('rejette les catégories et unités inconnues', () {
      expect(
        () => CollectionCategory.fromJson('unknown'),
        throwsFormatException,
      );
      expect(() => CollectionUnit.fromJson('pallet'), throwsFormatException);
    });

    test('calcule les synthèses sans extrapolation', () {
      final summary = MaraudeCollectionSummary.fromCollections([
        _collection(quantity: 25, weightKg: 12.5),
        _collection(
          id: 'crate',
          category: CollectionCategory.fruitsVegetables,
          quantity: 3,
          unit: CollectionUnit.crate,
          weightKg: 18,
        ),
        _collection(
          id: 'unweighted',
          category: CollectionCategory.bakery,
          quantity: 4,
          unit: CollectionUnit.bag,
          weightKg: null,
        ),
      ]);

      expect(summary.lotCount, 3);
      expect(summary.totalWeightKg, 30.5);
      expect(summary.totalPieces, 25);
    });

    test('normalise les champs facultatifs vides du brouillon', () {
      const draft = MaraudeCollectionDraft(
        category: CollectionCategory.other,
        description: ' ',
        quantity: 1,
        unit: CollectionUnit.other,
        comment: '',
      );

      expect(draft.toJson()['description'], isNull);
      expect(draft.toJson()['comment'], isNull);
    });
  });

  group('MaraudeCollectionRepository', () {
    test('crée, modifie puis supprime un lot', () async {
      final requests = <Request>[];
      final client = _client((request) async {
        requests.add(request);
        if (request.method == 'DELETE') {
          return Response('', 204, request: request);
        }
        return Response(
          jsonEncode(_collectionJson()),
          200,
          headers: _jsonHeaders,
          request: request,
        );
      });
      addTearDown(client.dispose);
      final repository = MaraudeCollectionRepository(client);
      const draft = MaraudeCollectionDraft(
        category: CollectionCategory.preparedMeals,
        description: 'Plateaux',
        quantity: 25,
        unit: CollectionUnit.piece,
        weightKg: 12.5,
        comment: 'Complet',
      );

      await repository.create('concert-id', draft);
      await repository.update('collection-id', draft);
      await repository.delete('collection-id');

      expect(requests.map((request) => request.method), [
        'POST',
        'PATCH',
        'DELETE',
      ]);
      expect(jsonDecode(requests[0].body), {
        ...draft.toJson(),
        'concert_id': 'concert-id',
      });
      expect(requests[1].url.queryParameters['id'], 'eq.collection-id');
      expect(requests[2].url.queryParameters['id'], 'eq.collection-id');
    });

    test('précharge tous les lots avec le détail du concert', () async {
      final requests = <Request>[];
      final client = _client((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/memberships')) {
          return Response(
            jsonEncode([
              {
                'organization_id': 'organization-id',
                'organizations': {
                  'kind': 'club_sandwich',
                  'slug': 'club-sandwich',
                },
              },
            ]),
            200,
            headers: _jsonHeaders,
            request: request,
          );
        }
        return Response(
          jsonEncode({
            'id': 'concert-id',
            'organization_id': 'organization-id',
            'artist': 'Artiste',
            'concert_date': '2026-09-15',
            'status': 'planned',
            'maraude_status': 'in_progress',
            'actual_start_at': '2026-09-15T20:00:00.000Z',
            'actual_end_at': null,
            'created_by': 'user-id',
            'created_at': '2026-07-25T10:00:00.000Z',
            'updated_at': '2026-07-25T10:00:00.000Z',
            'collections': [
              _collectionJson(),
              _collectionJson(id: 'second-collection'),
            ],
          }),
          200,
          headers: _jsonHeaders,
          request: request,
        );
      }, withAccessToken: false);
      await client.auth.recoverSession(
        jsonEncode({
          'access_token': 'test-token',
          'token_type': 'bearer',
          'user': {
            'id': 'user-id',
            'aud': 'authenticated',
            'app_metadata': <String, dynamic>{},
            'user_metadata': <String, dynamic>{},
            'created_at': '2026-07-25T10:00:00.000Z',
          },
        }),
      );
      addTearDown(client.dispose);

      final concert = await ConcertRepository(
        client,
      ).fetchConcert('concert-id');

      expect(concert!.collections, hasLength(2));
      expect(requests, hasLength(1));
      expect(
        requests.last.url.queryParameters['select'],
        contains('collections:maraude_collections(*)'),
      );
    });
  });

  testWidgets('affiche la synthèse et permet le CRUD pendant la maraude', (
    tester,
  ) async {
    final store = _CollectionStore([
      _collection(),
      _collection(
        id: 'crate',
        category: CollectionCategory.fruitsVegetables,
        quantity: 3,
        unit: CollectionUnit.crate,
        weightKg: 18,
      ),
    ]);
    await _pumpCollections(tester, store, isAdmin: true);

    expect(find.text('Nombre de lots'), findsOneWidget);
    expect(find.text('Poids total (kg)'), findsOneWidget);
    expect(find.text('30.5'), findsOneWidget);
    expect(find.text('Nombre total de pièces'), findsOneWidget);
    expect(find.text('25'), findsOneWidget);
    expect(find.text('Repas préparés'), findsOneWidget);
    expect(find.text('25 pièces'), findsOneWidget);

    await tester.ensureVisible(find.text('Ajouter un lot'));
    await tester.tap(find.text('Ajouter un lot'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Ajouter le lot'));
    await tester.tap(find.text('Ajouter le lot'));
    await tester.pump();
    expect(find.text('La quantité est obligatoire.'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Quantité'),
      '10',
    );
    await tester.enterText(
      find.byKey(const ValueKey('collection-comment')),
      'Nouveau lot',
    );
    await tester.tap(find.text('Ajouter le lot'));
    await tester.pumpAndSettle();

    expect(store.collections, hasLength(3));
    expect(find.text('Nouveau lot'), findsOneWidget);

    final firstActions = find.byTooltip('Actions du lot').first;
    await tester.ensureVisible(firstActions);
    await tester.tap(firstActions);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Modifier').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Quantité'),
      '30',
    );
    await tester.ensureVisible(find.text('Enregistrer les modifications'));
    await tester.tap(find.text('Enregistrer les modifications'));
    await tester.pumpAndSettle();

    expect(store.collections.first.quantity, 30);

    final deleteActions = find.byTooltip('Actions du lot').first;
    await tester.ensureVisible(deleteActions);
    await tester.tap(deleteActions);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Supprimer').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Supprimer'));
    await tester.pumpAndSettle();

    expect(store.collections, hasLength(2));
  });

  testWidgets('une maraude terminée affiche la collecte en lecture seule', (
    tester,
  ) async {
    final store = _CollectionStore([
      _collection(),
    ], status: MaraudeStatus.completed);
    await _pumpCollections(tester, store, isAdmin: true);

    expect(find.text('Cette collecte est en lecture seule.'), findsOneWidget);
    expect(find.text('Repas préparés'), findsOneWidget);
    expect(find.text('Ajouter un lot'), findsNothing);
    expect(find.byTooltip('Actions du lot'), findsNothing);
  });
}

const _jsonHeaders = {'content-type': 'application/json'};

SupabaseClient _client(
  Future<Response> Function(Request request) handler, {
  bool withAccessToken = true,
}) {
  return SupabaseClient(
    'http://localhost',
    'test-key',
    httpClient: MockClient(handler),
    authOptions: const AuthClientOptions(autoRefreshToken: false),
    accessToken: withAccessToken ? () async => 'test-token' : null,
  );
}

Map<String, dynamic> _collectionJson({String id = 'collection-id'}) {
  return {
    'id': id,
    'concert_id': 'concert-id',
    'category': 'prepared_meals',
    'description': 'Plateaux',
    'quantity': 25,
    'unit': 'piece',
    'weight_kg': 12.5,
    'comment': 'Complet',
    'created_at': '2026-07-27T20:00:00.000Z',
    'updated_at': '2026-07-27T20:00:00.000Z',
  };
}

MaraudeCollection _collection({
  String id = 'collection-id',
  CollectionCategory category = CollectionCategory.preparedMeals,
  double quantity = 25,
  CollectionUnit unit = CollectionUnit.piece,
  double? weightKg = 12.5,
  String? comment = 'Complet',
}) {
  return MaraudeCollection(
    id: id,
    concertId: 'concert-id',
    category: category,
    quantity: quantity,
    unit: unit,
    weightKg: weightKg,
    comment: comment,
    createdAt: DateTime.utc(2026, 7, 27, 20),
    updatedAt: DateTime.utc(2026, 7, 27, 20),
  );
}

Future<void> _pumpCollections(
  WidgetTester tester,
  _CollectionStore store, {
  required bool isAdmin,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        concertDetailsProvider.overrideWith(
          (ref, concertId) async => store.concert,
        ),
        maraudeCollectionRepositoryProvider.overrideWithValue(store.repository),
        concertVolunteerSectionProvider.overrideWith(
          (ref, concertId) async => ConcertVolunteerSectionData(
            counts: const ConcertVolunteerCounts.empty(),
            isAdmin: isAdmin,
            applications: const [],
          ),
        ),
      ],
      child: const MaterialApp(
        home: ConcertDetailScreen(concertId: 'concert-id'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _CollectionStore {
  _CollectionStore(
    List<MaraudeCollection> initialCollections, {
    this.status = MaraudeStatus.inProgress,
  }) : collections = [...initialCollections] {
    repository = _FakeMaraudeCollectionRepository(this);
  }

  final MaraudeStatus status;
  final List<MaraudeCollection> collections;
  late final _FakeMaraudeCollectionRepository repository;
  var _nextId = 1;

  Concert get concert => buildConcert(
    maraudeStatus: status,
    actualStartAt: DateTime(2026, 7, 27, 21, 12),
    actualEndAt: status == MaraudeStatus.completed
        ? DateTime(2026, 7, 27, 23, 5)
        : null,
    collections: List.unmodifiable(collections),
  );
}

class _FakeMaraudeCollectionRepository extends MaraudeCollectionRepository {
  _FakeMaraudeCollectionRepository(this.store)
    : super(
        SupabaseClient(
          'http://localhost',
          'test-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );

  final _CollectionStore store;

  @override
  Future<MaraudeCollection> create(
    String concertId,
    MaraudeCollectionDraft draft,
  ) async {
    final collection = MaraudeCollection(
      id: 'created-${store._nextId++}',
      concertId: concertId,
      category: draft.category,
      description: draft.description,
      quantity: draft.quantity,
      unit: draft.unit,
      weightKg: draft.weightKg,
      comment: draft.comment,
      createdAt: DateTime.utc(2026, 7, 27, 21),
      updatedAt: DateTime.utc(2026, 7, 27, 21),
    );
    store.collections.add(collection);
    return collection;
  }

  @override
  Future<MaraudeCollection> update(
    String collectionId,
    MaraudeCollectionDraft draft,
  ) async {
    final index = store.collections.indexWhere(
      (collection) => collection.id == collectionId,
    );
    final previous = store.collections[index];
    final collection = MaraudeCollection(
      id: previous.id,
      concertId: previous.concertId,
      category: draft.category,
      description: draft.description,
      quantity: draft.quantity,
      unit: draft.unit,
      weightKg: draft.weightKg,
      comment: draft.comment,
      createdAt: previous.createdAt,
      updatedAt: DateTime.utc(2026, 7, 27, 22),
    );
    store.collections[index] = collection;
    return collection;
  }

  @override
  Future<void> delete(String collectionId) async {
    store.collections.removeWhere(
      (collection) => collection.id == collectionId,
    );
  }
}
