import 'dart:async';

import 'package:club_sandwich/core/router/app_router.dart';
import 'package:club_sandwich/features/auth/application/auth_providers.dart';
import 'package:club_sandwich/features/auth/data/auth_repository.dart';
import 'package:club_sandwich/features/auth/domain/user_account.dart';
import 'package:club_sandwich/features/auth/presentation/forgot_password_screen.dart';
import 'package:club_sandwich/features/auth/presentation/reset_password_screen.dart';
import 'package:club_sandwich/features/concerts/data/concert_providers.dart';
import 'package:club_sandwich/features/concerts/presentation/concert_detail_screen.dart';
import 'package:club_sandwich/features/concerts/presentation/concerts_screen.dart';
import 'package:club_sandwich/features/dashboard/presentation/dashboard_screen.dart';
import 'package:club_sandwich/features/profiles/data/profile_providers.dart';
import 'package:club_sandwich/features/profiles/domain/profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  testWidgets('les routes Concerts ouvrent les écrans attendus', (
    tester,
  ) async {
    final authRepository = _AuthenticatedAuthRepository();
    addTearDown(authRepository.dispose);
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
        currentProfileProvider.overrideWith((ref) async => null),
        currentUserContextProvider.overrideWith(
          (ref) async => const CurrentUserContext(
            profileId: 'profile-id',
            role: AppUserRole.admin,
            status: UserAccountStatus.active,
          ),
        ),
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

    router.go('/maraudes');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(ConcertsScreen), findsOneWidget);

    router.go('/maraudes/concert-id');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(ConcertDetailScreen), findsOneWidget);
    expect(find.text('Maraude introuvable'), findsOneWidget);
  });

  testWidgets(
    'la déconnexion protège les routes privées et permet une reconnexion',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1280, 800);
      addTearDown(() {
        tester.view.resetDevicePixelRatio();
        tester.view.resetPhysicalSize();
      });

      final authRepository = _AuthenticatedAuthRepository();
      addTearDown(authRepository.dispose);
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(authRepository),
          currentProfileProvider.overrideWith(
            (ref) async => Profile(
              id: 'profile-id',
              firstName: 'Antoine',
              lastName: 'Vignol',
              createdAt: DateTime(2026, 7, 25),
            ),
          ),
          concertsProvider.overrideWith((ref) async => const []),
          concertDetailsProvider.overrideWith((ref, concertId) async => null),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const _RouterTestApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DashboardScreen), findsOneWidget);
      expect(find.text('Antoine Vignol'), findsOneWidget);
      expect(find.text('antoine@clubsandwich-records.com'), findsOneWidget);

      await tester.tap(find.text('Se déconnecter'));
      await tester.pumpAndSettle();

      expect(authRepository.signOutCount, 1);
      expect(find.text('Se connecter'), findsOneWidget);
      expect(find.byType(DashboardScreen), findsNothing);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Se connecter'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Adresse e-mail'),
        'antoine@clubsandwich-records.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Mot de passe'),
        'mot-de-passe',
      );
      await tester.tap(find.text('Se connecter'));
      await tester.pumpAndSettle();

      expect(authRepository.signInCount, 1);
      expect(find.byType(DashboardScreen), findsOneWidget);
    },
  );

  testWidgets(
    'un lien de récupération force l’écran de réinitialisation du mot de '
    'passe',
    (tester) async {
      final authRepository = _AuthenticatedAuthRepository();
      addTearDown(authRepository.dispose);
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(authRepository),
          currentProfileProvider.overrideWith(
            (ref) async => Profile(
              id: 'profile-id',
              firstName: 'Antoine',
              lastName: 'Vignol',
              createdAt: DateTime(2026, 7, 25),
            ),
          ),
          currentUserContextProvider.overrideWith(
            (ref) async => const CurrentUserContext(
              profileId: 'profile-id',
              role: AppUserRole.admin,
              status: UserAccountStatus.active,
            ),
          ),
          concertsProvider.overrideWith((ref) async => const []),
          concertDetailsProvider.overrideWith((ref, concertId) async => null),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const _RouterTestApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DashboardScreen), findsOneWidget);

      authRepository.emitPasswordRecovery();
      await tester.pumpAndSettle();

      expect(find.byType(ResetPasswordScreen), findsOneWidget);
      expect(find.byType(DashboardScreen), findsNothing);
    },
  );

  testWidgets(
    'le lien mot de passe oublié ouvre l’écran dédié depuis la connexion',
    (tester) async {
      final authRepository = _AuthenticatedAuthRepository();
      addTearDown(authRepository.dispose);
      final container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(authRepository)],
      );
      addTearDown(container.dispose);
      await authRepository.signOut();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const _RouterTestApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Se connecter'), findsOneWidget);

      await tester.tap(find.text('Mot de passe oublié ?'));
      await tester.pumpAndSettle();

      expect(find.byType(ForgotPasswordScreen), findsOneWidget);
    },
  );

  testWidgets(
    'le drawer mobile affiche l’e-mail lorsque le profil est indisponible',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(() {
        tester.view.resetDevicePixelRatio();
        tester.view.resetPhysicalSize();
      });

      final authRepository = _AuthenticatedAuthRepository();
      addTearDown(authRepository.dispose);
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(authRepository),
          currentProfileProvider.overrideWith((ref) async => null),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const _RouterTestApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();

      expect(find.text('antoine@clubsandwich-records.com'), findsOneWidget);
      expect(find.text('Se déconnecter'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
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

  final _authStateController = StreamController<AuthState>.broadcast();
  int signInCount = 0;
  int signOutCount = 0;

  @override
  Session? get session => _session;

  @override
  User? get currentUser => _session?.user;

  @override
  Stream<AuthState> get authStateChanges => _authStateController.stream;

  Session? _session = _testSession();

  @override
  Future<void> signIn({required String email, required String password}) async {
    signInCount++;
    _session = _testSession();
    _authStateController.add(AuthState(AuthChangeEvent.signedIn, _session));
  }

  @override
  Future<void> signOut() async {
    signOutCount++;
    _session = null;
    _authStateController.add(const AuthState(AuthChangeEvent.signedOut, null));
  }

  void emitPasswordRecovery() {
    _authStateController.add(
      AuthState(AuthChangeEvent.passwordRecovery, _session),
    );
  }

  Future<void> dispose() => _authStateController.close();
}

class _RouterTestApp extends ConsumerWidget {
  const _RouterTestApp();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(routerConfig: ref.watch(appRouterProvider));
  }
}

Session _testSession() {
  return Session(
    accessToken: 'test-token',
    tokenType: 'bearer',
    user: const User(
      id: 'profile-id',
      appMetadata: {},
      userMetadata: {},
      aud: 'authenticated',
      email: 'antoine@clubsandwich-records.com',
      createdAt: '2026-07-25T10:00:00.000Z',
    ),
  );
}
