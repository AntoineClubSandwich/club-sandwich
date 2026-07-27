import 'package:club_sandwich/core/router/app_router.dart';
import 'package:club_sandwich/features/auth/application/auth_providers.dart';
import 'package:club_sandwich/features/auth/data/auth_repository.dart';
import 'package:club_sandwich/features/concerts/data/concert_providers.dart';
import 'package:club_sandwich/features/concerts/presentation/concert_detail_screen.dart';
import 'package:club_sandwich/features/concerts/presentation/concerts_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  testWidgets('les routes Concerts ouvrent les écrans attendus', (
    tester,
  ) async {
    final authRepository = _AuthenticatedAuthRepository();
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(authRepository),
        authStateProvider.overrideWithValue(
          AsyncData(
            AuthState(AuthChangeEvent.signedIn, authRepository.session),
          ),
        ),
        concertsProvider.overrideWith((ref) async => const []),
        concertDetailsProvider.overrideWith((ref, concertId) async => null),
      ],
    );
    addTearDown(() async {
      container.read(appRouterProvider).dispose();
      container.dispose();
    });
    final router = container.read(appRouterProvider);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    router.go('/concerts');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(ConcertsScreen), findsOneWidget);

    router.go('/concerts/concert-id');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(ConcertDetailScreen), findsOneWidget);
    expect(find.text('Concert introuvable'), findsOneWidget);
  });
}

class _AuthenticatedAuthRepository extends AuthRepository {
  factory _AuthenticatedAuthRepository() {
    final client = SupabaseClient(
      'http://localhost',
      'test-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      accessToken: () async => 'test-token',
    );
    return _AuthenticatedAuthRepository._(client);
  }

  // The superclass positional parameter is private to its library.
  // ignore: use_super_parameters
  _AuthenticatedAuthRepository._(SupabaseClient client) : super(client);

  late final Session _session = Session(
    accessToken: 'test-token',
    tokenType: 'bearer',
    user: const User(
      id: 'profile-id',
      appMetadata: {},
      userMetadata: {},
      aud: 'authenticated',
      createdAt: '2026-07-25T10:00:00.000Z',
    ),
  );

  @override
  Session get session => _session;

  @override
  Stream<AuthState> get authStateChanges =>
      Stream.value(AuthState(AuthChangeEvent.signedIn, _session));
}
