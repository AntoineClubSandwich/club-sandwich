import 'dart:convert';

import 'package:club_sandwich/features/concerts/data/concert_providers.dart';
import 'package:club_sandwich/features/concerts/data/concert_repository.dart';
import 'package:club_sandwich/features/concerts/domain/concert.dart';
import 'package:club_sandwich/features/concerts/presentation/concert_detail_screen.dart';
import 'package:club_sandwich/features/distributions/data/maraude_distribution_providers.dart';
import 'package:club_sandwich/features/distributions/data/maraude_distribution_repository.dart';
import 'package:club_sandwich/features/distributions/domain/maraude_distribution.dart';
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
  group('MaraudeDistribution', () {
    test('parse, sérialise et compare une fiche complète', () {
      final distribution = MaraudeDistribution.fromJson(_distributionJson());

      expect(distribution.distributionLocation, 'Place de la République');
      expect(distribution.estimatedBeneficiaries, 42);
      expect(distribution.distributedMeals, 35);
      expect(distribution.remainingWeightKg, 7.5);
      expect(distribution, MaraudeDistribution.fromJson(distribution.toJson()));
    });

    test('accepte les valeurs facultatives nulles', () {
      final distribution = MaraudeDistribution.fromJson(
        _distributionJson(
          distributionLocation: null,
          estimatedBeneficiaries: null,
          distributedMeals: null,
          remainingWeightKg: null,
          distributionStartedAt: null,
          distributionCompletedAt: null,
          incidentComment: null,
        ),
      );

      expect(distribution.distributionLocation, isNull);
      expect(distribution.distributionStartedAt, isNull);
      expect(distribution.distributionCompletedAt, isNull);
    });

    test('normalise les textes facultatifs vides du brouillon', () {
      const draft = MaraudeDistributionDraft(
        distributionLocation: ' ',
        incidentComment: '',
      );

      expect(draft.toJson()['distribution_location'], isNull);
      expect(draft.toJson()['incident_comment'], isNull);
    });
  });

  group('MaraudeDistributionRepository', () {
    test('crée et modifie la fiche unique', () async {
      final requests = <Request>[];
      final client = _client((request) async {
        requests.add(request);
        return Response(
          jsonEncode(_distributionJson()),
          200,
          headers: _jsonHeaders,
          request: request,
        );
      });
      addTearDown(client.dispose);
      final repository = MaraudeDistributionRepository(client);
      final draft = MaraudeDistributionDraft(
        distributionLocation: 'Place de la République',
        estimatedBeneficiaries: 42,
        distributedMeals: 35,
        remainingWeightKg: 7.5,
        distributionStartedAt: DateTime.utc(2026, 7, 27, 22),
        distributionCompletedAt: DateTime.utc(2026, 7, 27, 23),
        incidentComment: 'RAS',
      );

      await repository.create('concert-id', draft);
      await repository.update('distribution-id', draft);

      expect(requests.map((request) => request.method), ['POST', 'PATCH']);
      expect(jsonDecode(requests.first.body), {
        ...draft.toJson(),
        'concert_id': 'concert-id',
      });
      expect(requests.last.url.queryParameters['id'], 'eq.distribution-id');
    });

    test('précharge la distribution avec le détail du concert', () async {
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
            'collections': <Map<String, dynamic>>[],
            'distribution': [_distributionJson()],
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

      expect(concert!.distribution?.distributedMeals, 35);
      expect(requests, hasLength(1));
      expect(
        requests.last.url.queryParameters['select'],
        contains('distribution:maraude_distributions(*)'),
      );
    });
  });

  testWidgets('affiche l’absence de fiche et permet sa création', (
    tester,
  ) async {
    final store = _DistributionStore();
    await _pumpDistribution(tester, store, isAdmin: true);

    expect(find.text('Aucune distribution enregistrée.'), findsOneWidget);
    await tester.ensureVisible(find.text('Ajouter la distribution'));
    await tester.tap(find.text('Ajouter la distribution'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Lieu de distribution'),
      'Place de la République',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Bénéficiaires estimés'),
      '42',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Repas distribués'),
      '35',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Poids restant (kg)'),
      '7,5',
    );
    await tester.ensureVisible(
      find.widgetWithText(FilledButton, 'Ajouter la distribution').last,
    );
    await tester.tap(
      find.widgetWithText(FilledButton, 'Ajouter la distribution').last,
    );
    await tester.pumpAndSettle();

    expect(store.distribution?.estimatedBeneficiaries, 42);
    expect(find.text('Place de la République'), findsOneWidget);
    expect(find.text('7.5 kg'), findsOneWidget);
  });

  testWidgets('affiche et permet de modifier une fiche existante', (
    tester,
  ) async {
    final store = _DistributionStore(distribution: _distribution());
    await _pumpDistribution(tester, store, isAdmin: true);

    expect(find.text('Place de la République'), findsOneWidget);
    expect(find.text('42'), findsOneWidget);
    expect(find.text('35'), findsOneWidget);
    expect(find.text('RAS'), findsOneWidget);

    await tester.ensureVisible(find.text('Modifier'));
    await tester.tap(find.text('Modifier'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Repas distribués'),
      '40',
    );
    await tester.ensureVisible(find.text('Enregistrer les modifications'));
    await tester.tap(find.text('Enregistrer les modifications'));
    await tester.pumpAndSettle();

    expect(store.distribution?.distributedMeals, 40);
    expect(find.text('40'), findsOneWidget);
  });

  testWidgets('une maraude terminée affiche la distribution en lecture seule', (
    tester,
  ) async {
    final store = _DistributionStore(
      distribution: _distribution(),
      status: MaraudeStatus.completed,
    );
    await _pumpDistribution(tester, store, isAdmin: true);

    expect(
      find.text('Cette distribution est en lecture seule.'),
      findsOneWidget,
    );
    expect(find.text('Place de la République'), findsNWidgets(2));
    expect(find.byKey(const ValueKey('edit-distribution')), findsNothing);
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

Map<String, dynamic> _distributionJson({
  String? distributionLocation = 'Place de la République',
  int? estimatedBeneficiaries = 42,
  int? distributedMeals = 35,
  double? remainingWeightKg = 7.5,
  String? distributionStartedAt = '2026-07-27T22:00:00.000Z',
  String? distributionCompletedAt = '2026-07-27T23:00:00.000Z',
  String? incidentComment = 'RAS',
}) {
  return {
    'id': 'distribution-id',
    'concert_id': 'concert-id',
    'distribution_location': distributionLocation,
    'estimated_beneficiaries': estimatedBeneficiaries,
    'distributed_meals': distributedMeals,
    'remaining_weight_kg': remainingWeightKg,
    'distribution_started_at': distributionStartedAt,
    'distribution_completed_at': distributionCompletedAt,
    'incident_comment': incidentComment,
    'created_at': '2026-07-27T21:00:00.000Z',
    'updated_at': '2026-07-27T21:00:00.000Z',
  };
}

MaraudeDistribution _distribution({int distributedMeals = 35}) {
  return MaraudeDistribution(
    id: 'distribution-id',
    concertId: 'concert-id',
    distributionLocation: 'Place de la République',
    estimatedBeneficiaries: 42,
    distributedMeals: distributedMeals,
    remainingWeightKg: 7.5,
    distributionStartedAt: DateTime.utc(2026, 7, 27, 22),
    distributionCompletedAt: DateTime.utc(2026, 7, 27, 23),
    incidentComment: 'RAS',
    createdAt: DateTime.utc(2026, 7, 27, 21),
    updatedAt: DateTime.utc(2026, 7, 27, 21),
  );
}

Future<void> _pumpDistribution(
  WidgetTester tester,
  _DistributionStore store, {
  required bool isAdmin,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        concertDetailsProvider.overrideWith(
          (ref, concertId) async => store.concert,
        ),
        maraudeDistributionRepositoryProvider.overrideWithValue(
          store.repository,
        ),
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

class _DistributionStore {
  _DistributionStore({
    this.distribution,
    this.status = MaraudeStatus.inProgress,
  }) {
    repository = _FakeMaraudeDistributionRepository(this);
  }

  MaraudeDistribution? distribution;
  final MaraudeStatus status;
  late final _FakeMaraudeDistributionRepository repository;

  Concert get concert => buildConcert(
    maraudeStatus: status,
    actualStartAt: DateTime(2026, 7, 27, 21, 12),
    actualEndAt: status == MaraudeStatus.completed
        ? DateTime(2026, 7, 27, 23, 5)
        : null,
    distribution: distribution,
  );
}

class _FakeMaraudeDistributionRepository extends MaraudeDistributionRepository {
  _FakeMaraudeDistributionRepository(this.store)
    : super(
        SupabaseClient(
          'http://localhost',
          'test-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );

  final _DistributionStore store;

  @override
  Future<MaraudeDistribution> create(
    String concertId,
    MaraudeDistributionDraft draft,
  ) async {
    final distribution = _fromDraft(
      id: 'created-distribution',
      concertId: concertId,
      draft: draft,
      createdAt: DateTime.utc(2026, 7, 27, 21),
    );
    store.distribution = distribution;
    return distribution;
  }

  @override
  Future<MaraudeDistribution> update(
    String distributionId,
    MaraudeDistributionDraft draft,
  ) async {
    final previous = store.distribution!;
    final distribution = _fromDraft(
      id: distributionId,
      concertId: previous.concertId,
      draft: draft,
      createdAt: previous.createdAt,
    );
    store.distribution = distribution;
    return distribution;
  }

  MaraudeDistribution _fromDraft({
    required String id,
    required String concertId,
    required MaraudeDistributionDraft draft,
    required DateTime createdAt,
  }) {
    final json = draft.toJson();
    return MaraudeDistribution(
      id: id,
      concertId: concertId,
      distributionLocation: json['distribution_location'] as String?,
      estimatedBeneficiaries: draft.estimatedBeneficiaries,
      distributedMeals: draft.distributedMeals,
      remainingWeightKg: draft.remainingWeightKg,
      distributionStartedAt: draft.distributionStartedAt,
      distributionCompletedAt: draft.distributionCompletedAt,
      incidentComment: json['incident_comment'] as String?,
      createdAt: createdAt,
      updatedAt: DateTime.utc(2026, 7, 27, 22),
    );
  }
}
