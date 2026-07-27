import 'package:club_sandwich/features/auth/application/auth_providers.dart';
import 'package:club_sandwich/features/auth/presentation/login_screen.dart';
import 'package:club_sandwich/features/concerts/presentation/concerts_screen.dart';
import 'package:club_sandwich/features/concerts/presentation/concert_detail_screen.dart';
import 'package:club_sandwich/features/dashboard/presentation/dashboard_screen.dart';
import 'package:club_sandwich/features/operations/presentation/operations_screen.dart';
import 'package:club_sandwich/features/settings/presentation/settings_screen.dart';
import 'package:club_sandwich/features/venues/presentation/venues_screen.dart';
import 'package:club_sandwich/features/volunteers/presentation/volunteers_screen.dart';
import 'package:club_sandwich/shared/widgets/app_shell.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

abstract final class AppRoutes {
  static const login = '/login';
  static const dashboard = '/dashboard';
  static const concerts = '/concerts';
  static const operations = '/operations';
  static const volunteers = '/volunteers';
  static const venues = '/venues';
  static const settings = '/settings';
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  final repository = ref.read(authRepositoryProvider);
  final isAuthenticated =
      authState.value?.session != null || repository.session != null;

  return GoRouter(
    initialLocation: isAuthenticated ? AppRoutes.dashboard : AppRoutes.login,
    redirect: (context, state) {
      final isOnLogin = state.matchedLocation == AppRoutes.login;

      if (!isAuthenticated && !isOnLogin) return AppRoutes.login;
      if (isAuthenticated && isOnLogin) return AppRoutes.dashboard;
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
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
            path: AppRoutes.concerts,
            builder: (context, state) => const ConcertsScreen(),
          ),
          GoRoute(
            path: '${AppRoutes.concerts}/:concertId',
            builder: (context, state) => ConcertDetailScreen(
              concertId: state.pathParameters['concertId']!,
            ),
          ),
          GoRoute(
            path: AppRoutes.operations,
            builder: (context, state) => const OperationsScreen(),
          ),
          GoRoute(
            path: AppRoutes.volunteers,
            builder: (context, state) => const VolunteersScreen(),
          ),
          GoRoute(
            path: AppRoutes.venues,
            builder: (context, state) => const VenuesScreen(),
          ),
          GoRoute(
            path: AppRoutes.settings,
            builder: (context, state) => const SettingsScreen(),
          ),
        ],
      ),
    ],
  );
});
