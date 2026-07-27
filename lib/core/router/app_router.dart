import 'package:club_sandwich/features/administration/presentation/administration_screen.dart';
import 'package:club_sandwich/features/auth/application/auth_providers.dart';
import 'package:club_sandwich/features/auth/domain/user_account.dart';
import 'package:club_sandwich/features/auth/presentation/activation_screen.dart';
import 'package:club_sandwich/features/auth/presentation/login_screen.dart';
import 'package:club_sandwich/features/concerts/presentation/concerts_screen.dart';
import 'package:club_sandwich/features/concerts/presentation/concert_detail_screen.dart';
import 'package:club_sandwich/features/dashboard/presentation/dashboard_screen.dart';
import 'package:club_sandwich/features/invitations/presentation/invitations_screen.dart';
import 'package:club_sandwich/features/organizations/presentation/organizations_screen.dart';
import 'package:club_sandwich/features/profiles/presentation/profile_screen.dart';
import 'package:club_sandwich/features/volunteers/presentation/volunteers_screen.dart';
import 'package:club_sandwich/shared/widgets/app_shell.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

abstract final class AppRoutes {
  static const login = '/login';
  static const activate = '/activate';
  static const dashboard = '/dashboard';
  static const maraudes = '/maraudes';
  static const invitations = '/invitations';
  static const organizations = '/organizations';
  static const volunteers = '/volunteers';
  static const administration = '/administration';
  static const profile = '/profile';
  static const account = '/account';
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  ref.watch(currentUserContextProvider);
  final repository = ref.read(authRepositoryProvider);
  final hasInitialSession =
      authState.value?.session != null || repository.session != null;

  return GoRouter(
    initialLocation: hasInitialSession ? AppRoutes.dashboard : AppRoutes.login,
    redirect: (context, state) {
      final isAuthenticated = repository.session != null;
      final isOnLogin = state.matchedLocation == AppRoutes.login;
      final isOnActivation = state.matchedLocation == AppRoutes.activate;

      if (!isAuthenticated && !isOnLogin) return AppRoutes.login;
      if (!isAuthenticated) return null;

      final accountContext = ref.read(currentUserContextProvider).value;
      if (accountContext == null) {
        return isOnLogin || isOnActivation ? null : AppRoutes.dashboard;
      }
      if (accountContext.status == UserAccountStatus.disabled) {
        return isOnLogin ? null : AppRoutes.login;
      }
      if (accountContext.status == UserAccountStatus.invited) {
        return isOnActivation ? null : AppRoutes.activate;
      }
      if (isOnLogin || isOnActivation) return AppRoutes.dashboard;

      final location = state.matchedLocation;
      if (!_isAllowed(accountContext.role, location)) {
        return AppRoutes.dashboard;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.activate,
        builder: (context, state) => const ActivationScreen(),
      ),
      GoRoute(path: '/concerts', redirect: (_, _) => AppRoutes.maraudes),
      GoRoute(
        path: '/concerts/:concertId',
        redirect: (_, state) =>
            '${AppRoutes.maraudes}/${state.pathParameters['concertId']}',
      ),
      ShellRoute(
        builder: (context, state, child) {
          return AppShell(location: state.uri.path, child: child);
        },
        routes: [
          GoRoute(
            path: AppRoutes.dashboard,
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: AppRoutes.maraudes,
            builder: (context, state) =>
                ref.read(currentUserContextProvider).value?.role ==
                    AppUserRole.volunteer
                ? const VolunteersScreen()
                : const ConcertsScreen(),
          ),
          GoRoute(
            path: '${AppRoutes.maraudes}/:concertId',
            builder: (context, state) => ConcertDetailScreen(
              concertId: state.pathParameters['concertId']!,
            ),
          ),
          GoRoute(
            path: AppRoutes.invitations,
            builder: (context, state) => const InvitationsScreen(),
          ),
          GoRoute(
            path: AppRoutes.organizations,
            builder: (context, state) => const OrganizationsScreen(),
          ),
          GoRoute(
            path: AppRoutes.volunteers,
            builder: (context, state) => const VolunteersScreen(),
          ),
          GoRoute(
            path: AppRoutes.administration,
            builder: (context, state) => const AdministrationScreen(),
          ),
          GoRoute(
            path: AppRoutes.profile,
            builder: (context, state) => const ProfileScreen(),
          ),
          GoRoute(
            path: AppRoutes.account,
            builder: (context, state) => const ProfileScreen(),
          ),
        ],
      ),
    ],
  );
});

bool _isAllowed(AppUserRole role, String location) {
  if (location.startsWith('${AppRoutes.maraudes}/')) return true;
  final allowed = switch (role) {
    AppUserRole.admin => {
      AppRoutes.dashboard,
      AppRoutes.maraudes,
      AppRoutes.invitations,
      AppRoutes.organizations,
      AppRoutes.volunteers,
      AppRoutes.administration,
    },
    AppUserRole.promoter => {
      AppRoutes.dashboard,
      AppRoutes.maraudes,
      AppRoutes.invitations,
      AppRoutes.account,
    },
    AppUserRole.volunteer => {
      AppRoutes.dashboard,
      AppRoutes.maraudes,
      AppRoutes.invitations,
      AppRoutes.profile,
    },
  };
  return allowed.contains(location);
}
