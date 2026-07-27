import 'dart:convert';

import 'package:club_sandwich/features/concerts/data/concert_providers.dart';
import 'package:club_sandwich/features/concerts/presentation/concert_detail_screen.dart';
import 'package:club_sandwich/features/volunteers/data/concert_volunteer_providers.dart';
import 'package:club_sandwich/features/volunteers/data/concert_volunteer_repository.dart';
import 'package:club_sandwich/features/volunteers/domain/concert_volunteer_application.dart';
import 'package:club_sandwich/features/volunteers/domain/volunteer_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'helpers/test_data.dart';

void main() {
  group('ConcertVolunteerApplication', () {
    test('parse, sérialise, copie et compare une candidature', () {
      final application = ConcertVolunteerApplication.fromJson({
        'id': 'application-id',
        'concert_id': 'concert-id',
        'user_id': 'user-id',
        'status': 'pending',
        'team_role': null,
        'created_at': '2026-07-25T10:00:00.000Z',
        'updated_at': '2026-07-25T10:30:00.000Z',
        'profile': {'first_name': 'Camille', 'last_name': 'Martin'},
      });

      expect(application.status.label, 'En attente');
      expect(application.displayName, 'Camille Martin');
      expect(application.toJson()['status'], 'pending');
      expect(application.teamRole, isNull);
      expect(application.attendanceStatus, isNull);
      expect(application.copyWith(), application);
      expect(
        application.copyWith(status: ConcertVolunteerStatus.selected).status,
        ConcertVolunteerStatus.selected,
      );
    });

    test('gère un profil absent et rejette un statut inconnu', () {
      final application = _application();

      expect(application.displayName, 'Bénévole');
      expect(
        () => ConcertVolunteerStatus.fromDatabase('accepted'),
        throwsFormatException,
      );
      expect(ConcertVolunteerStatus.notSelected.label, 'Non sélectionné');
      expect(ConcertVolunteerStatus.withdrawn.label, 'Désisté');
    });

    test('parse des compteurs absents comme zéro', () {
      expect(ConcertVolunteerCounts.fromJson(const {}).applicationCount, 0);
      expect(ConcertVolunteerCounts.fromJson(const {}).selectedCount, 0);
    });

    test('parse un profil bénévole complet et ses statistiques', () {
      final application = ConcertVolunteerApplication.fromJson({
        ..._applicationJson(),
        'first_name': 'Camille',
        'last_name': 'Martin',
        'email': 'camille@example.test',
        'phone': '+33 6 00 00 00 00',
        'avatar_url': 'https://example.test/avatar.png',
        'birth_date': '1992-04-12',
        'has_driving_license': true,
        'can_lift_heavy_loads': false,
        'emergency_contact_name': 'Sophie Martin',
        'emergency_contact_phone': '+33 6 99 99 99 99',
        'total_applications': 12,
        'selected_applications': 8,
        'not_selected_applications': 2,
        'withdrawn_applications': 1,
        'team_role': 'logistics',
        'attendance_status': 'present',
        'last_selected_date': '2026-07-15',
        'history': [
          {
            'concert_id': 'older-concert',
            'concert_date': '2026-07-02',
            'artist': 'Aupinard',
            'venue_name': 'Bataclan',
            'status': 'withdrawn',
          },
          {
            'concert_id': 'recent-concert',
            'concert_date': '2026-07-15',
            'artist': 'The Blaze',
            'venue_name': 'Olympia',
            'status': 'selected',
          },
        ],
      });

      expect(application.profile!.birthDate, DateTime(1992, 4, 12));
      expect(application.profile!.email, 'camille@example.test');
      expect(application.profile!.hasDrivingLicense, isTrue);
      expect(application.profile!.canLiftHeavyLoads, isFalse);
      expect(application.profile!.hasEmergencyContact, isTrue);
      expect(application.statistics.totalApplications, 12);
      expect(application.statistics.selectedApplications, 8);
      expect(application.statistics.notSelectedApplications, 2);
      expect(application.statistics.withdrawnApplications, 1);
      expect(application.statistics.lastSelectedDate, DateTime(2026, 7, 15));
      expect(application.statistics.history.first.artist, 'The Blaze');
      expect(application.statistics.history.last.artist, 'Aupinard');
      expect(application.teamRole, MaraudeRole.logistics);
      expect(application.attendanceStatus, VolunteerAttendanceStatus.present);
      expect(application.toJson()['team_role'], 'logistics');
      expect(application.toJson()['attendance_status'], 'present');
      expect(application.profile!.toJson()['birth_date'], '1992-04-12');
      expect(MaraudeRole.communication.label, 'Chargé.e de communication');
      expect(
        MaraudeRole.collectionDistribution.label,
        'Chargé.e de récolte et distribution',
      );
    });

    test('accepte une candidature sans profil bénévole', () {
      final application = ConcertVolunteerApplication.fromJson(
        _applicationJson(),
      );

      expect(application.profile, isNull);
      expect(application.statistics.totalApplications, 0);
      expect(application.displayName, 'Bénévole');
    });

    test('calcule les taux et masque ceux d’un historique vide', () {
      final statistics = VolunteerStatistics.fromJson({
        'total_applications': 9,
        'selected_applications': 7,
        'not_selected_applications': 1,
        'withdrawn_applications': 1,
      });
      const emptyStatistics = VolunteerStatistics.empty();

      expect(statistics.selectionRate, 78);
      expect(statistics.withdrawalRate, 11);
      expect(emptyStatistics.selectionRate, isNull);
      expect(emptyStatistics.withdrawalRate, isNull);
      expect(emptyStatistics.lastSelectedDate, isNull);
    });

    test('calcule les compteurs de présence des seuls sélectionnés', () {
      final counts = TeamAttendanceCounts.fromApplications([
        _application(status: ConcertVolunteerStatus.pending),
        _application(
          id: 'legacy-selected',
          status: ConcertVolunteerStatus.selected,
        ),
        _application(
          id: 'present',
          status: ConcertVolunteerStatus.selected,
          attendanceStatus: VolunteerAttendanceStatus.present,
        ),
        _application(
          id: 'absent',
          status: ConcertVolunteerStatus.selected,
          attendanceStatus: VolunteerAttendanceStatus.absent,
        ),
      ]);

      expect(counts.selectedCount, 3);
      expect(counts.pendingCount, 1);
      expect(counts.presentCount, 1);
      expect(counts.absentCount, 1);
    });
  });

  group('ConcertVolunteerRepository', () {
    test(
      'précharge en lot les profils et statistiques administrateur',
      () async {
        final requests = <Request>[];
        final client = await _authenticatedClient((request) async {
          requests.add(request);
          final path = request.url.path;
          if (path.endsWith('/get_concert_volunteer_counts')) {
            return Response(
              jsonEncode([
                {'application_count': 1, 'selected_count': 0},
              ]),
              200,
              headers: _jsonHeaders,
              request: request,
            );
          }
          if (path.endsWith('/memberships')) {
            return Response(
              jsonEncode([
                {
                  'role': 'admin',
                  'organizations': {'kind': 'club_sandwich'},
                },
              ]),
              200,
              headers: _jsonHeaders,
              request: request,
            );
          }
          if (path.endsWith('/get_concert_volunteer_team_details')) {
            return Response(
              jsonEncode([
                {
                  ..._applicationJson(),
                  'first_name': 'Camille',
                  'last_name': 'Martin',
                  'phone': '+33 6 00 00 00 00',
                  'has_driving_license': true,
                  'total_applications': 12,
                  'selected_applications': 8,
                  'not_selected_applications': 2,
                  'withdrawn_applications': 1,
                  'attendance_status': 'present',
                  'last_selected_date': '2026-07-15',
                  'history': [
                    {
                      'concert_id': 'recent-concert',
                      'concert_date': '2026-07-15',
                      'artist': 'The Blaze',
                      'venue_name': 'Olympia',
                      'status': 'selected',
                    },
                  ],
                },
              ]),
              200,
              headers: _jsonHeaders,
              request: request,
            );
          }
          return Response('Not found', 404, request: request);
        });
        addTearDown(client.dispose);

        final section = await ConcertVolunteerRepository(
          client,
        ).fetchSection('concert-id');

        expect(section.applications, hasLength(1));
        expect(section.applications.single.displayName, 'Camille Martin');
        expect(section.applications.single.statistics.totalApplications, 12);
        expect(
          section.applications.single.attendanceStatus,
          VolunteerAttendanceStatus.present,
        );
        expect(requests, hasLength(3));
        expect(
          requests
              .where(
                (request) => request.url.path.endsWith(
                  '/get_concert_volunteer_team_details',
                ),
              )
              .length,
          1,
        );
      },
    );

    test(
      'crée une candidature pending et propage le doublon Supabase',
      () async {
        var requestCount = 0;
        final client = await _authenticatedClient((request) async {
          requestCount++;
          if (requestCount == 1) {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            expect(body['concert_id'], 'concert-id');
            expect(body['user_id'], 'user-id');
            expect(body['status'], 'pending');
            return Response(
              jsonEncode(_applicationJson()),
              201,
              headers: _jsonHeaders,
              request: request,
            );
          }
          return Response(
            jsonEncode({
              'code': '23505',
              'message': 'duplicate key value violates unique constraint',
              'details': null,
              'hint': null,
            }),
            409,
            headers: _jsonHeaders,
            request: request,
          );
        });
        addTearDown(client.dispose);
        final repository = ConcertVolunteerRepository(client);

        final created = await repository.apply('concert-id');

        expect(created.status, ConcertVolunteerStatus.pending);
        expect(
          repository.apply('concert-id'),
          throwsA(isA<PostgrestException>()),
        );
      },
    );

    test('enregistre un désistement sans supprimer la ligne', () async {
      late Request capturedRequest;
      final client = await _authenticatedClient((request) async {
        capturedRequest = request;
        return Response('', 204, request: request);
      });
      addTearDown(client.dispose);

      await ConcertVolunteerRepository(client).withdraw('application-id');

      expect(capturedRequest.method, 'PATCH');
      expect(capturedRequest.url.path, endsWith('/concert_volunteers'));
      expect(jsonDecode(capturedRequest.body), {'status': 'withdrawn'});
      expect(capturedRequest.url.queryParameters['id'], 'eq.application-id');
      expect(capturedRequest.url.queryParameters['user_id'], 'eq.user-id');
    });

    test('renouvelle explicitement une disponibilité par RPC', () async {
      late Request capturedRequest;
      final client = await _authenticatedClient((request) async {
        capturedRequest = request;
        return Response('null', 200, headers: _jsonHeaders, request: request);
      });
      addTearDown(client.dispose);

      await ConcertVolunteerRepository(client).reapply('concert-id');

      expect(capturedRequest.url.path, endsWith('/rpc/reapply_to_concert'));
      expect(jsonDecode(capturedRequest.body), {
        'requested_concert_id': 'concert-id',
      });
    });

    test(
      'limite le changement administrateur aux deux statuts prévus',
      () async {
        final requests = <Request>[];
        final client = await _authenticatedClient((request) async {
          requests.add(request);
          return Response('', 204, request: request);
        });
        addTearDown(client.dispose);
        final repository = ConcertVolunteerRepository(client);

        await repository.setStatus(
          'application-id',
          ConcertVolunteerStatus.selected,
        );
        await repository.setStatus(
          'application-id',
          ConcertVolunteerStatus.notSelected,
        );

        expect(jsonDecode(requests[0].body), {'status': 'selected'});
        expect(jsonDecode(requests[1].body), {'status': 'not_selected'});
        expect(
          () => repository.setStatus(
            'application-id',
            ConcertVolunteerStatus.pending,
          ),
          throwsArgumentError,
        );
      },
    );

    test('sélectionne plusieurs candidatures en une seule requête', () async {
      late Request capturedRequest;
      final client = await _authenticatedClient((request) async {
        capturedRequest = request;
        return Response('null', 200, headers: _jsonHeaders, request: request);
      });
      addTearDown(client.dispose);

      await ConcertVolunteerRepository(
        client,
      ).selectVolunteers('concert-id', ['application-1', 'application-2']);

      expect(
        capturedRequest.url.path,
        endsWith('/rpc/select_concert_volunteers'),
      );
      expect(jsonDecode(capturedRequest.body), {
        'requested_concert_id': 'concert-id',
        'requested_application_ids': ['application-1', 'application-2'],
      });
    });

    test('enregistre l’équipe complète en une seule RPC', () async {
      late Request capturedRequest;
      final client = await _authenticatedClient((request) async {
        capturedRequest = request;
        return Response('null', 200, headers: _jsonHeaders, request: request);
      });
      addTearDown(client.dispose);

      await ConcertVolunteerRepository(client).saveTeam('concert-id', const [
        MaraudeTeamMemberDraft(
          applicationId: 'application-1',
          role: MaraudeRole.teamLeader,
        ),
        MaraudeTeamMemberDraft(
          applicationId: 'application-2',
          role: MaraudeRole.communication,
        ),
      ]);

      expect(capturedRequest.url.path, endsWith('/rpc/save_maraude_team'));
      expect(jsonDecode(capturedRequest.body), {
        'requested_concert_id': 'concert-id',
        'requested_team': [
          {'application_id': 'application-1', 'team_role': 'team_leader'},
          {'application_id': 'application-2', 'team_role': 'communication'},
        ],
      });
    });

    test('enregistre un rôle sans règle d’unicité applicative', () async {
      final client = await _authenticatedClient((request) async {
        expect(jsonDecode(request.body), {'team_role': 'logistics'});
        return Response('', 204, request: request);
      });
      addTearDown(client.dispose);
      final repository = ConcertVolunteerRepository(client);

      await repository.setTeamRole('application-id', MaraudeRole.logistics);
    });

    test('enregistre les trois états de présence', () async {
      final requests = <Request>[];
      final client = await _authenticatedClient((request) async {
        requests.add(request);
        return Response('', 204, request: request);
      });
      addTearDown(client.dispose);
      final repository = ConcertVolunteerRepository(client);

      for (final status in VolunteerAttendanceStatus.values) {
        await repository.setAttendanceStatus('application-id', status);
      }

      expect(requests.map((request) => jsonDecode(request.body)), [
        {'attendance_status': 'pending'},
        {'attendance_status': 'present'},
        {'attendance_status': 'absent'},
      ]);
      expect(
        requests.every(
          (request) => request.url.queryParameters['id'] == 'eq.application-id',
        ),
        isTrue,
      );
    });
  });

  test('le provider se recharge après invalidation', () async {
    final repository = _FakeConcertVolunteerRepository();
    final container = ProviderContainer(
      overrides: [
        concertVolunteerRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    await container.read(concertVolunteerSectionProvider('concert-id').future);
    container.invalidate(concertVolunteerSectionProvider('concert-id'));
    await container.read(concertVolunteerSectionProvider('concert-id').future);

    expect(repository.fetchCount, 2);
  });

  testWidgets('crée une candidature et rafraîchit les compteurs', (
    tester,
  ) async {
    final repository = _FakeConcertVolunteerRepository();
    await _pumpDetail(tester, repository);

    expect(find.text('0 candidatures'), findsOneWidget);
    expect(find.text('Je me propose'), findsOneWidget);

    await tester.ensureVisible(find.text('Je me propose'));
    await tester.tap(find.text('Je me propose'));
    await tester.pumpAndSettle();

    expect(find.text('1 candidature'), findsOneWidget);
    expect(find.text('En attente'), findsOneWidget);
    expect(find.text('Je me désiste'), findsOneWidget);
    expect(
      find.text(
        'Votre candidature a été enregistrée.\n\n'
        'Vous serez informé si vous êtes sélectionné.',
      ),
      findsOneWidget,
    );
    expect(repository.fetchCount, greaterThanOrEqualTo(2));
  });

  testWidgets('conserve la ligne lors du désistement', (tester) async {
    final repository = _FakeConcertVolunteerRepository(
      ownApplication: _application(),
    );
    await _pumpDetail(tester, repository);

    await tester.ensureVisible(find.text('Je me désiste'));
    await tester.tap(find.text('Je me désiste'));
    await tester.pumpAndSettle();
    expect(find.text('Confirmer le désistement ?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Je me désiste'));
    await tester.pumpAndSettle();

    expect(find.text('Désisté'), findsOneWidget);
    expect(find.text('0 candidatures'), findsOneWidget);
    expect(repository.ownApplication, isNotNull);
    expect(repository.ownApplication!.status, ConcertVolunteerStatus.withdrawn);
  });

  testWidgets('permet un nouveau positionnement après un désistement', (
    tester,
  ) async {
    final repository = _FakeConcertVolunteerRepository(
      ownApplication: _application(status: ConcertVolunteerStatus.withdrawn),
    );
    await _pumpDetail(tester, repository);

    expect(find.text('Désisté'), findsOneWidget);
    final reapply = find.byKey(const ValueKey('reapply-to-concert'));
    await tester.ensureVisible(reapply);
    await tester.tap(reapply);
    await tester.pumpAndSettle();

    expect(repository.ownApplication?.status, ConcertVolunteerStatus.pending);
    expect(find.text('Votre disponibilité a été transmise.'), findsOneWidget);
  });

  testWidgets('le bénévole ouvre son propre historique', (tester) async {
    final repository = _FakeConcertVolunteerRepository(
      ownApplication: _application(
        status: ConcertVolunteerStatus.selected,
        teamRole: MaraudeRole.teamLeader,
        statistics: VolunteerStatistics(
          totalApplications: 1,
          selectedApplications: 1,
          notSelectedApplications: 0,
          withdrawnApplications: 0,
          lastSelectedDate: DateTime(2026, 7, 15),
          history: [
            VolunteerHistoryEntry(
              concertId: 'recent-concert',
              concertDate: DateTime(2026, 7, 15),
              artist: 'The Blaze',
              venueName: 'Olympia',
              status: ConcertVolunteerStatus.selected,
            ),
          ],
        ),
      ),
    );
    await _pumpDetail(tester, repository);

    await tester.ensureVisible(find.text('Voir mon profil'));
    await tester.tap(find.text('Voir mon profil'));
    await tester.pumpAndSettle();

    expect(find.text('Historique des maraudes'), findsOneWidget);
    expect(find.text('The Blaze'), findsOneWidget);
    expect(find.text('Olympia'), findsOneWidget);
    expect(find.text('Rôle : Chef.fe d’équipe'), findsOneWidget);
    expect(find.text('Présence : En attente'), findsOneWidget);
  });

  testWidgets('sélectionne en un clic et met le résumé à jour sans requête', (
    tester,
  ) async {
    final repository = _FakeConcertVolunteerRepository(
      isAdmin: true,
      applications: [
        _application(
          id: 'pending-id',
          userId: 'user-1',
          profile: const VolunteerProfile(
            userId: 'user-1',
            firstName: 'Camille',
            lastName: 'Martin',
          ),
        ),
        _application(
          id: 'selected-id',
          userId: 'user-2',
          status: ConcertVolunteerStatus.selected,
          teamRole: MaraudeRole.teamLeader,
          profile: const VolunteerProfile(
            userId: 'user-2',
            firstName: 'Alex',
            lastName: 'Durand',
          ),
        ),
      ],
    );
    await _pumpDetail(tester, repository);

    expect(find.text('2 candidatures'), findsOneWidget);
    expect(find.text('1 bénévole sélectionné'), findsOneWidget);
    expect(find.text('Camille Martin'), findsOneWidget);
    expect(find.text('Alex Durand'), findsWidgets);

    final selectButton = find.byKey(
      const ValueKey('select-volunteer-pending-id'),
    );
    await tester.ensureVisible(selectButton);
    await tester.tap(selectButton);
    await tester.pump();

    await tester.ensureVisible(find.byKey(const ValueKey('team-mobile-tabs')));
    await tester.tap(find.text('Équipe').last);
    await tester.pump();
    expect(find.text('2 / 4 bénévoles'), findsOneWidget);
    expect(find.text('Camille Martin'), findsWidgets);
    expect(find.text('Récolte & distribution'), findsWidgets);
    expect(
      repository.applications
          .firstWhere((application) => application.id == 'pending-id')
          .status,
      ConcertVolunteerStatus.pending,
    );
    expect(repository.saveTeamCount, 0);
  });

  testWidgets('attribue le rôle directement sur la carte', (tester) async {
    final repository = _FakeConcertVolunteerRepository(
      isAdmin: true,
      applications: [
        _application(
          status: ConcertVolunteerStatus.selected,
          teamRole: MaraudeRole.collectionDistribution,
          profile: const VolunteerProfile(
            userId: 'user-id',
            firstName: 'Camille',
            lastName: 'Martin',
          ),
        ),
      ],
    );
    await _pumpDetail(tester, repository);

    final leaderRole = find.byKey(
      const ValueKey('team-role-application-id-teamLeader'),
    );
    await tester.ensureVisible(leaderRole);
    await tester.tap(leaderRole);
    await tester.pump();

    expect(find.text('Chef.fe d’équipe'), findsWidgets);
    expect(
      repository.applications.single.teamRole,
      MaraudeRole.collectionDistribution,
    );
    expect(repository.saveTeamCount, 0);
  });

  testWidgets('enregistre une équipe d’un bénévole sans chef', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });
    final repository = _FakeConcertVolunteerRepository(
      isAdmin: true,
      applications: [
        _application(
          profile: const VolunteerProfile(
            userId: 'user-id',
            firstName: 'Camille',
          ),
        ),
      ],
    );
    await _pumpDetail(tester, repository);

    final select = find.byKey(
      const ValueKey('select-volunteer-application-id'),
    );
    await tester.ensureVisible(select);
    await tester.tap(select);
    await tester.pump();
    final save = find.byKey(const ValueKey('save-maraude-team'));
    expect(tester.widget<FilledButton>(save).onPressed, isNotNull);
    expect(
      find.textContaining('Cette recommandation ne bloque pas'),
      findsOneWidget,
    );
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(repository.saveTeamCount, 1);
    expect(
      repository.applications.single.status,
      ConcertVolunteerStatus.selected,
    );
  });

  testWidgets('enregistre une équipe vide après le retrait du dernier membre', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });
    final repository = _FakeConcertVolunteerRepository(
      isAdmin: true,
      applications: [
        _application(
          status: ConcertVolunteerStatus.selected,
          teamRole: MaraudeRole.communication,
          profile: const VolunteerProfile(
            userId: 'user-id',
            firstName: 'Camille',
          ),
        ),
      ],
    );
    await _pumpDetail(tester, repository);

    final remove = find.byKey(
      const ValueKey('remove-volunteer-application-id'),
    );
    await tester.ensureVisible(remove);
    await tester.tap(remove);
    await tester.pump();

    final save = find.byKey(const ValueKey('save-maraude-team'));
    expect(tester.widget<FilledButton>(save).onPressed, isNotNull);
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(repository.saveTeamCount, 1);
    expect(repository.lastSavedTeam, isEmpty);
  });

  testWidgets('autorise plusieurs chefs d’équipe dans le brouillon', (
    tester,
  ) async {
    final repository = _FakeConcertVolunteerRepository(
      isAdmin: true,
      applications: [
        _application(
          id: 'first',
          profile: const VolunteerProfile(
            userId: 'first-user',
            firstName: 'Camille',
            lastName: 'Martin',
          ),
        ),
        _application(
          id: 'second',
          userId: 'second-user',
          profile: const VolunteerProfile(
            userId: 'second-user',
            firstName: 'Hugo',
            lastName: 'Durand',
          ),
        ),
      ],
    );
    await _pumpDetail(tester, repository);

    await tester.ensureVisible(
      find.byKey(const ValueKey('select-volunteer-first')),
    );
    await tester.tap(find.byKey(const ValueKey('select-volunteer-first')));
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(const ValueKey('team-role-first-teamLeader')),
    );
    await tester.tap(find.byKey(const ValueKey('team-role-first-teamLeader')));
    await tester.pump();

    await tester.ensureVisible(
      find.byKey(const ValueKey('select-volunteer-second')),
    );
    await tester.tap(find.byKey(const ValueKey('select-volunteer-second')));
    await tester.pump();
    final secondLeader = tester.widget<RadioListTile<MaraudeRole>>(
      find.byKey(const ValueKey('team-role-second-teamLeader')),
    );

    expect(secondLeader.enabled, isTrue);
  });

  testWidgets('valide atomiquement une équipe complète avec un chef', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 1100);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });
    final repository = _FakeConcertVolunteerRepository(
      isAdmin: true,
      applications: [
        for (var index = 1; index <= 4; index++)
          _application(
            id: 'candidate-$index',
            userId: 'user-$index',
            profile: VolunteerProfile(
              userId: 'user-$index',
              firstName: 'Bénévole $index',
            ),
          ),
      ],
    );
    await _pumpDetail(tester, repository);

    for (var index = 1; index <= 4; index++) {
      final button = find.byKey(ValueKey('select-volunteer-candidate-$index'));
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pump();
    }

    var saveButton = tester.widget<FilledButton>(
      find.byKey(const ValueKey('save-maraude-team')),
    );
    expect(saveButton.onPressed, isNotNull);

    final leaderRole = find.byKey(
      const ValueKey('team-role-candidate-1-teamLeader'),
    );
    await tester.ensureVisible(leaderRole);
    await tester.tap(leaderRole);
    await tester.pump();

    saveButton = tester.widget<FilledButton>(
      find.byKey(const ValueKey('save-maraude-team')),
    );
    expect(saveButton.onPressed, isNotNull);
    await tester.ensureVisible(find.byKey(const ValueKey('save-maraude-team')));
    await tester.tap(find.byKey(const ValueKey('save-maraude-team')));
    await tester.pumpAndSettle();

    expect(repository.saveTeamCount, 1);
    expect(
      repository.applications
          .where(
            (application) =>
                application.status == ConcertVolunteerStatus.selected,
          )
          .length,
      4,
    );
    expect(
      repository.applications
          .firstWhere((application) => application.id == 'candidate-1')
          .teamRole,
      MaraudeRole.teamLeader,
    );
    expect(find.text('Équipe enregistrée.'), findsOneWidget);
  });

  testWidgets('affiche Candidatures et Équipe sous forme d’onglets mobiles', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });
    final repository = _FakeConcertVolunteerRepository(
      isAdmin: true,
      applications: [
        _application(
          profile: const VolunteerProfile(
            userId: 'user-id',
            firstName: 'Camille',
          ),
        ),
      ],
    );
    await _pumpDetail(tester, repository);

    expect(find.byKey(const ValueKey('team-builder-mobile')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('team-candidates-column')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('team-builder-summary')), findsNothing);

    await tester.ensureVisible(find.byKey(const ValueKey('team-mobile-tabs')));
    await tester.ensureVisible(find.byKey(const ValueKey('team-mobile-tabs')));
    await tester.tap(find.text('Équipe').last);
    await tester.pump();

    expect(find.byKey(const ValueKey('team-builder-summary')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('recherche, filtre et ordonne les candidatures', (tester) async {
    final repository = _FakeConcertVolunteerRepository(
      isAdmin: true,
      applications: [
        _application(
          id: 'not-selected-id',
          status: ConcertVolunteerStatus.notSelected,
          profile: const VolunteerProfile(
            userId: 'user-4',
            firstName: 'Zoé',
            lastName: 'Bernard',
            email: 'zoe@example.test',
          ),
        ),
        _application(
          id: 'withdrawn-id',
          status: ConcertVolunteerStatus.withdrawn,
          profile: const VolunteerProfile(
            userId: 'user-3',
            firstName: 'Inès',
            lastName: 'Robert',
            email: 'ines@example.test',
          ),
        ),
        _application(
          id: 'pending-id',
          profile: const VolunteerProfile(
            userId: 'user-2',
            firstName: 'Barthélémy',
            lastName: 'Durand',
            email: 'barthelemy@example.test',
            phone: '06 11 22 33 44',
          ),
        ),
        _application(
          id: 'selected-id',
          status: ConcertVolunteerStatus.selected,
          teamRole: MaraudeRole.teamLeader,
          profile: const VolunteerProfile(
            userId: 'user-1',
            firstName: 'Antoine',
            lastName: 'Vignol',
            email: 'antoine@example.test',
          ),
        ),
      ],
    );
    await _pumpDetail(tester, repository);

    await tester.ensureVisible(find.byKey(const ValueKey('team-mobile-tabs')));
    await tester.tap(find.text('Équipe').last);
    await tester.pump();
    expect(find.text('1 / 4 bénévoles'), findsOneWidget);
    expect(find.textContaining('généralement recommandés'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('team-mobile-tabs')));
    await tester.tap(find.text('Candidatures').last);
    await tester.pump();
    final selectedCard = find.byKey(
      const ValueKey('volunteer-card-selected-id'),
    );
    final pendingCard = find.byKey(const ValueKey('volunteer-card-pending-id'));
    final withdrawnCard = find.byKey(
      const ValueKey('volunteer-card-withdrawn-id'),
    );
    final notSelectedCard = find.byKey(
      const ValueKey('volunteer-card-not-selected-id'),
    );
    expect(
      tester.getTopLeft(selectedCard).dy,
      lessThan(tester.getTopLeft(pendingCard).dy),
    );
    expect(
      tester.getTopLeft(pendingCard).dy,
      lessThan(tester.getTopLeft(withdrawnCard).dy),
    );
    expect(
      tester.getTopLeft(withdrawnCard).dy,
      lessThan(tester.getTopLeft(notSelectedCard).dy),
    );

    final searchField = find.byKey(const ValueKey('volunteer-search-field'));
    await tester.ensureVisible(searchField);
    await tester.enterText(searchField, 'barthelemy@example.test');
    await tester.pump();

    expect(pendingCard, findsOneWidget);
    expect(selectedCard, findsNothing);

    await tester.enterText(searchField, '');
    await tester.tap(find.byKey(const ValueKey('volunteer-filter-selected')));
    await tester.pump();

    expect(selectedCard, findsOneWidget);
    expect(pendingCard, findsNothing);
  });

  testWidgets('affiche les deux colonnes desktop et le résumé des rôles', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 1000);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });
    final repository = _FakeConcertVolunteerRepository(
      isAdmin: true,
      applications: [
        _application(
          id: 'leader-id',
          status: ConcertVolunteerStatus.selected,
          teamRole: MaraudeRole.teamLeader,
          profile: const VolunteerProfile(
            userId: 'leader',
            firstName: 'Antoine',
          ),
        ),
        _application(
          id: 'driver-id',
          status: ConcertVolunteerStatus.selected,
          teamRole: MaraudeRole.logistics,
          profile: const VolunteerProfile(userId: 'driver', firstName: 'Hugo'),
        ),
        _application(
          id: 'photographer-id',
          status: ConcertVolunteerStatus.selected,
          teamRole: MaraudeRole.communication,
          profile: const VolunteerProfile(
            userId: 'photographer',
            firstName: 'Inès',
          ),
        ),
        _application(
          id: 'volunteer-id',
          status: ConcertVolunteerStatus.selected,
          teamRole: MaraudeRole.collectionDistribution,
          profile: const VolunteerProfile(
            userId: 'volunteer',
            firstName: 'Barthélémy',
          ),
        ),
      ],
    );
    await _pumpDetail(tester, repository);

    expect(find.byKey(const ValueKey('team-builder-desktop')), findsOneWidget);
    expect(find.byType(DataTable), findsNothing);
    expect(find.text('4 / 4 bénévoles'), findsOneWidget);
    expect(find.text('Équipe enregistrable'), findsOneWidget);
    expect(find.text('Équipe retenue'), findsOneWidget);
    expect(find.text('Chargé.e de communication'), findsWidgets);
    expect(find.text('Chargé.e de logistique'), findsWidgets);
    expect(find.text('Chargé.e de récolte et distribution'), findsWidgets);
    expect(find.text('Équipe enregistrée'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('affiche et met à jour la synthèse des présences', (
    tester,
  ) async {
    final repository = _FakeConcertVolunteerRepository(
      isAdmin: true,
      applications: [
        _application(
          id: 'pending-attendance',
          status: ConcertVolunteerStatus.selected,
          teamRole: MaraudeRole.collectionDistribution,
          profile: const VolunteerProfile(
            userId: 'user-1',
            firstName: 'Julie',
            lastName: 'Martin',
          ),
        ),
        _application(
          id: 'present-attendance',
          userId: 'user-2',
          status: ConcertVolunteerStatus.selected,
          teamRole: MaraudeRole.logistics,
          attendanceStatus: VolunteerAttendanceStatus.present,
        ),
        _application(
          id: 'absent-attendance',
          userId: 'user-3',
          status: ConcertVolunteerStatus.selected,
          teamRole: MaraudeRole.collectionDistribution,
          attendanceStatus: VolunteerAttendanceStatus.absent,
        ),
      ],
    );
    await _pumpDetail(tester, repository);

    await tester.ensureVisible(find.byKey(const ValueKey('team-mobile-tabs')));
    await tester.tap(find.text('Équipe').last);
    await tester.pump();
    expect(find.text('3 sélectionnés'), findsOneWidget);
    expect(find.text('Présents : 1'), findsOneWidget);
    expect(find.text('Absents : 1'), findsOneWidget);
    expect(find.text('En attente : 1'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const ValueKey('team-mobile-tabs')));
    await tester.tap(find.text('Candidatures').last);
    await tester.pump();
    final dropdown = find.byKey(
      const ValueKey(
        'attendance-pending-attendance-'
        'VolunteerAttendanceStatus.pending',
      ),
    );
    await tester.ensureVisible(dropdown);
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Présent').last);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const ValueKey('team-mobile-tabs')));
    await tester.tap(find.text('Équipe').last);
    await tester.pump();
    expect(find.text('Présents : 2'), findsOneWidget);
    expect(find.text('En attente : 0'), findsOneWidget);
    expect(
      repository.applications
          .firstWhere((application) => application.id == 'pending-attendance')
          .attendanceStatus,
      VolunteerAttendanceStatus.present,
    );
    expect(repository.fetchCount, greaterThanOrEqualTo(2));
  });

  testWidgets('affiche les informations utiles à la décision sur la carte', (
    tester,
  ) async {
    final application = _application(
      profile: VolunteerProfile(
        userId: 'user-id',
        firstName: 'Camille',
        lastName: 'Martin',
        phone: '+33 6 00 00 00 00',
        birthDate: DateTime(1992, 4, 12),
        hasDrivingLicense: true,
        canLiftHeavyLoads: true,
        emergencyContactName: 'Sophie Martin',
        emergencyContactPhone: '+33 6 99 99 99 99',
      ),
      statistics: const VolunteerStatistics(
        totalApplications: 12,
        selectedApplications: 8,
        notSelectedApplications: 2,
        withdrawnApplications: 1,
        lastSelectedDate: null,
        history: [],
      ),
    );
    final repository = _FakeConcertVolunteerRepository(
      isAdmin: true,
      applications: [application],
    );
    await _pumpDetail(tester, repository);

    expect(find.text('Camille Martin'), findsOneWidget);
    expect(find.text('Maraudes'), findsOneWidget);
    expect(find.text('8'), findsOneWidget);
    expect(find.text('Dernière participation'), findsOneWidget);
    expect(find.text('Aucune'), findsOneWidget);
    expect(find.text('Désistements'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('Disponibilité'), findsOneWidget);
    expect(find.text('Confirmée'), findsOneWidget);
    expect(find.text('+33 6 00 00 00 00'), findsNothing);
    expect(find.text('Permis : Oui'), findsNothing);
    expect(find.text('Sophie Martin'), findsNothing);
    expect(find.text('+33 6 99 99 99 99'), findsNothing);
  });

  testWidgets('ouvre le profil complet en lecture seule', (tester) async {
    final application = _application(
      profile: VolunteerProfile(
        userId: 'user-id',
        firstName: 'Camille',
        lastName: 'Martin',
        phone: '+33 6 00 00 00 00',
        birthDate: DateTime(1992, 4, 12),
        hasDrivingLicense: true,
        canLiftHeavyLoads: false,
        emergencyContactName: 'Sophie Martin',
        emergencyContactPhone: '+33 6 99 99 99 99',
      ),
      statistics: VolunteerStatistics(
        totalApplications: 12,
        selectedApplications: 8,
        notSelectedApplications: 2,
        withdrawnApplications: 1,
        lastSelectedDate: DateTime(2026, 7, 15),
        history: [
          VolunteerHistoryEntry(
            concertId: 'recent-concert',
            concertDate: DateTime(2026, 7, 15),
            artist: 'The Blaze',
            venueName: 'Olympia',
            status: ConcertVolunteerStatus.selected,
          ),
          VolunteerHistoryEntry(
            concertId: 'older-concert',
            concertDate: DateTime(2026, 7, 2),
            artist: 'Aupinard',
            venueName: 'Bataclan',
            status: ConcertVolunteerStatus.withdrawn,
          ),
        ],
      ),
    );
    final repository = _FakeConcertVolunteerRepository(
      isAdmin: true,
      applications: [application],
    );
    await _pumpDetail(tester, repository);

    final card = find.byKey(const ValueKey('volunteer-card-application-id'));
    await tester.ensureVisible(card);
    await tester.tap(
      find.descendant(of: card, matching: find.byType(InkWell)).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Profil bénévole'), findsOneWidget);
    expect(find.text('12 avril 1992'), findsOneWidget);
    expect(find.text('Port de charges lourdes'), findsOneWidget);
    expect(find.text('Contact d’urgence'), findsOneWidget);
    expect(find.text('Sophie Martin'), findsOneWidget);
    expect(find.text('+33 6 99 99 99 99'), findsOneWidget);
    expect(find.text('2 non-sélections'), findsOneWidget);
    expect(find.text('Dernière participation'), findsNWidgets(2));
    expect(find.text('15 juillet 2026'), findsNWidgets(2));
    expect(find.text('Taux de sélection : 67 %'), findsOneWidget);
    expect(find.text('Taux de désistement : 8 %'), findsOneWidget);
    expect(find.text('Historique des maraudes'), findsOneWidget);
    expect(find.text('The Blaze'), findsOneWidget);
    expect(find.text('Olympia'), findsOneWidget);
    expect(find.text('Aupinard'), findsOneWidget);
    expect(find.text('Bataclan'), findsOneWidget);
    expect(find.text('Fermer'), findsOneWidget);
    expect(find.text('Modifier'), findsNothing);
  });

  testWidgets('affiche les valeurs manquantes et la photo par défaut', (
    tester,
  ) async {
    final repository = _FakeConcertVolunteerRepository(
      isAdmin: true,
      applications: [
        _application(
          profile: const VolunteerProfile(
            userId: 'user-id',
            firstName: 'Camille',
            lastName: 'Martin',
          ),
        ),
      ],
    );
    await _pumpDetail(tester, repository);

    expect(find.text('Maraudes'), findsOneWidget);
    final card = find.byKey(const ValueKey('volunteer-card-application-id'));
    expect(find.descendant(of: card, matching: find.text('0')), findsOneWidget);
    expect(find.text('Dernière participation'), findsOneWidget);
    expect(find.text('Aucune'), findsOneWidget);
    expect(find.text('Confirmée'), findsOneWidget);
    expect(find.byIcon(Icons.person_outline), findsWidgets);

    await tester.ensureVisible(card);
    await tester.tap(
      find.descendant(of: card, matching: find.byType(InkWell)).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Non renseignée'), findsOneWidget);
    expect(find.text('Non renseigné'), findsWidgets);
    expect(find.text('Aucune'), findsNWidgets(2));
    expect(find.text('Aucun historique.'), findsOneWidget);
    expect(find.textContaining('Taux de sélection'), findsNothing);
  });
}

const _jsonHeaders = {'content-type': 'application/json'};

Future<SupabaseClient> _authenticatedClient(
  Future<Response> Function(Request request) handler,
) async {
  final client = SupabaseClient(
    'http://localhost',
    'test-key',
    httpClient: MockClient(handler),
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );
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
  return client;
}

Map<String, dynamic> _applicationJson({
  String id = 'application-id',
  String userId = 'user-id',
  String status = 'pending',
}) {
  return {
    'id': id,
    'concert_id': 'concert-id',
    'user_id': userId,
    'status': status,
    'created_at': '2026-07-25T10:00:00.000Z',
    'updated_at': '2026-07-25T10:00:00.000Z',
  };
}

ConcertVolunteerApplication _application({
  String id = 'application-id',
  String userId = 'user-id',
  ConcertVolunteerStatus status = ConcertVolunteerStatus.pending,
  VolunteerProfile? profile,
  VolunteerStatistics statistics = const VolunteerStatistics.empty(),
  MaraudeRole? teamRole,
  VolunteerAttendanceStatus? attendanceStatus,
}) {
  return ConcertVolunteerApplication(
    id: id,
    concertId: 'concert-id',
    userId: userId,
    status: status,
    createdAt: DateTime.utc(2026, 7, 25, 10),
    updatedAt: DateTime.utc(2026, 7, 25, 10),
    profile: profile,
    statistics: statistics,
    teamRole: teamRole,
    attendanceStatus: attendanceStatus,
  );
}

Future<void> _pumpDetail(
  WidgetTester tester,
  _FakeConcertVolunteerRepository repository,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        concertDetailsProvider.overrideWith(
          (ref, concertId) async => buildConcert(),
        ),
        concertVolunteerRepositoryProvider.overrideWithValue(repository),
      ],
      child: const MaterialApp(
        home: ConcertDetailScreen(concertId: 'concert-id'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _FakeConcertVolunteerRepository extends ConcertVolunteerRepository {
  _FakeConcertVolunteerRepository({
    this.ownApplication,
    this.isAdmin = false,
    List<ConcertVolunteerApplication> applications = const [],
  }) : applications = [...applications],
       super(
         SupabaseClient(
           'http://localhost',
           'test-key',
           authOptions: const AuthClientOptions(autoRefreshToken: false),
         ),
       );

  ConcertVolunteerApplication? ownApplication;
  final bool isAdmin;
  final List<ConcertVolunteerApplication> applications;
  int fetchCount = 0;
  int saveTeamCount = 0;
  List<MaraudeTeamMemberDraft> lastSavedTeam = const [];

  @override
  Future<ConcertVolunteerSectionData> fetchSection(String concertId) async {
    fetchCount++;
    final visibleApplications = isAdmin
        ? List<ConcertVolunteerApplication>.unmodifiable(applications)
        : const <ConcertVolunteerApplication>[];
    final allApplications = isAdmin ? applications : [?ownApplication];
    return ConcertVolunteerSectionData(
      ownApplication: ownApplication,
      counts: ConcertVolunteerCounts(
        applicationCount: allApplications
            .where(
              (application) =>
                  application.status != ConcertVolunteerStatus.withdrawn,
            )
            .length,
        selectedCount: allApplications
            .where(
              (application) =>
                  application.status == ConcertVolunteerStatus.selected,
            )
            .length,
        presentCount: allApplications
            .where(
              (application) =>
                  application.status == ConcertVolunteerStatus.selected &&
                  application.effectiveAttendanceStatus ==
                      VolunteerAttendanceStatus.present,
            )
            .length,
        absentCount: allApplications
            .where(
              (application) =>
                  application.status == ConcertVolunteerStatus.selected &&
                  application.effectiveAttendanceStatus ==
                      VolunteerAttendanceStatus.absent,
            )
            .length,
      ),
      isAdmin: isAdmin,
      applications: visibleApplications,
    );
  }

  @override
  Future<ConcertVolunteerApplication> apply(String concertId) async {
    if (ownApplication != null) {
      throw StateError('Une candidature existe déjà.');
    }
    ownApplication = _application();
    return ownApplication!;
  }

  @override
  Future<void> withdraw(String applicationId) async {
    ownApplication = ownApplication?.copyWith(
      status: ConcertVolunteerStatus.withdrawn,
      teamRole: null,
      attendanceStatus: null,
    );
    final index = applications.indexWhere(
      (application) => application.id == applicationId,
    );
    if (index >= 0) {
      applications[index] = applications[index].copyWith(
        status: ConcertVolunteerStatus.withdrawn,
        teamRole: null,
        attendanceStatus: null,
      );
    }
  }

  @override
  Future<void> reapply(String concertId) async {
    ownApplication = ownApplication?.copyWith(
      status: ConcertVolunteerStatus.pending,
      teamRole: null,
      attendanceStatus: null,
    );
  }

  @override
  Future<void> setStatus(
    String applicationId,
    ConcertVolunteerStatus status,
  ) async {
    final index = applications.indexWhere(
      (application) => application.id == applicationId,
    );
    applications[index] = applications[index].copyWith(
      status: status,
      teamRole: status == ConcertVolunteerStatus.selected
          ? applications[index].teamRole ?? MaraudeRole.collectionDistribution
          : null,
      attendanceStatus: status == ConcertVolunteerStatus.selected
          ? applications[index].attendanceStatus ??
                VolunteerAttendanceStatus.pending
          : null,
    );
  }

  @override
  Future<void> selectVolunteers(
    String concertId,
    Iterable<String> applicationIds,
  ) async {
    for (final applicationId in applicationIds) {
      final index = applications.indexWhere(
        (application) => application.id == applicationId,
      );
      applications[index] = applications[index].copyWith(
        status: ConcertVolunteerStatus.selected,
        teamRole:
            applications[index].teamRole ?? MaraudeRole.collectionDistribution,
        attendanceStatus:
            applications[index].attendanceStatus ??
            VolunteerAttendanceStatus.pending,
      );
    }
  }

  @override
  Future<void> saveTeam(
    String concertId,
    Iterable<MaraudeTeamMemberDraft> members,
  ) async {
    saveTeamCount++;
    lastSavedTeam = members.toList(growable: false);
    final roles = {
      for (final member in lastSavedTeam) member.applicationId: member.role,
    };
    for (var index = 0; index < applications.length; index++) {
      final application = applications[index];
      final role = roles[application.id];
      if (role != null) {
        applications[index] = application.copyWith(
          status: ConcertVolunteerStatus.selected,
          teamRole: role,
          attendanceStatus:
              application.attendanceStatus ?? VolunteerAttendanceStatus.pending,
        );
      } else if (application.status == ConcertVolunteerStatus.selected) {
        applications[index] = application.copyWith(
          status: ConcertVolunteerStatus.notSelected,
          teamRole: null,
          attendanceStatus: null,
        );
      }
    }
  }

  @override
  Future<void> setTeamRole(String applicationId, MaraudeRole role) async {
    final index = applications.indexWhere(
      (application) => application.id == applicationId,
    );
    applications[index] = applications[index].copyWith(teamRole: role);
  }

  @override
  Future<void> setAttendanceStatus(
    String applicationId,
    VolunteerAttendanceStatus status,
  ) async {
    final index = applications.indexWhere(
      (application) => application.id == applicationId,
    );
    if (applications[index].status != ConcertVolunteerStatus.selected) {
      throw StateError('Le bénévole n’est pas sélectionné.');
    }
    applications[index] = applications[index].copyWith(
      attendanceStatus: status,
    );
  }
}
