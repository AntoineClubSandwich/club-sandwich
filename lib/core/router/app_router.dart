import 'package:club_sandwich/core/router/ds_page_transition.dart';
import 'package:club_sandwich/design_system/style_guide/style_guide_screen.dart';
import 'package:club_sandwich/features/administration/presentation/administration_screen.dart';
import 'package:club_sandwich/features/auth/application/auth_providers.dart';
import 'package:club_sandwich/features/auth/domain/user_account.dart';
import 'package:club_sandwich/features/auth/presentation/activation_screen.dart';
import 'package:club_sandwich/features/auth/presentation/forgot_password_screen.dart';
import 'package:club_sandwich/features/auth/presentation/login_screen.dart';
import 'package:club_sandwich/features/auth/presentation/reset_password_screen.dart';
import 'package:club_sandwich/features/concerts/presentation/concerts_screen.dart';
import 'package:club_sandwich/features/concerts/presentation/concert_detail_screen.dart';
import 'package:club_sandwich/features/dashboard/presentation/dashboard_screen.dart';
import 'package:club_sandwich/features/encounters/presentation/encounter_map_screen.dart';
import 'package:club_sandwich/features/invitations/presentation/invitations_screen.dart';
import 'package:club_sandwich/features/organizations/presentation/organizations_screen.dart';
import 'package:club_sandwich/features/operations/presentation/maraude_operation_screen.dart';
import 'package:club_sandwich/features/profiles/presentation/profile_screen.dart';
import 'package:club_sandwich/features/stock/presentation/stock_screen.dart';
import 'package:club_sandwich/features/venues/presentation/venues_screen.dart';
import 'package:club_sandwich/features/volunteers/presentation/volunteers_screen.dart';
import 'package:club_sandwich/shared/widgets/app_shell.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

abstract final class AppRoutes {
  static const login = '/login';
  static const forgotPassword = '/forgot-password';
  static const resetPassword = '/reset-password';
  static const activate = '/activate';
  static const dashboard = '/dashboard';
  static const maraudes = '/maraudes';
  static const invitations = '/invitations';
  static const organizations = '/organizations';
  static const venues = '/venues';
  static const stock = '/stock';
  static const consumables = '/consumables';
  static const equipment = '/equipment';
  static const volunteers = '/volunteers';
  static const administration = '/administration';
  static const encounterMap = '/encounters-map';
  static const profile = '/profile';
  static const account = '/account';

  /// Design-system showcase — admin-only, deliberately absent from
  /// `AppShell`'s navigation menu (see `_destinationsFor` in
  /// `lib/shared/widgets/app_shell.dart`). Reachable only by typing the
  /// URL directly; never linked to from any real user flow.
  static const styleGuide = '/style-guide';
}

final appRouterProvider = Provider<GoRouter>((ref) {
  ref.watch(authStateProvider);
  ref.watch(currentUserContextProvider);
  final repository = ref.read(authRepositoryProvider);

  return GoRouter(
    redirect: (context, state) {
      final isAuthenticated = repository.session != null;
      final isOnLogin = state.matchedLocation == AppRoutes.login;
      final isOnForgotPassword =
          state.matchedLocation == AppRoutes.forgotPassword;
      final isOnResetPassword =
          state.matchedLocation == AppRoutes.resetPassword;
      final isOnActivation = state.matchedLocation == AppRoutes.activate;

      // Supabase opens a real authenticated session as soon as the
      // password-recovery link is opened, so this must be checked before
      // the generic isAuthenticated branch below — otherwise the user
      // would land straight on the dashboard instead of the reset form.
      if (ref.watch(passwordRecoveryProvider)) {
        return isOnResetPassword ? null : AppRoutes.resetPassword;
      }

      if (!isAuthenticated && !isOnLogin && !isOnForgotPassword) {
        return AppRoutes.login;
      }
      if (!isAuthenticated) return null;
      if (isOnResetPassword) return AppRoutes.dashboard;

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
        path: AppRoutes.forgotPassword,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.resetPassword,
        builder: (context, state) => const ResetPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.activate,
        builder: (context, state) => const ActivationScreen(),
      ),
      GoRoute(
        path: AppRoutes.styleGuide,
        builder: (context, state) => const StyleGuideScreen(),
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
            pageBuilder: (context, state) {
              final child = ConcertDetailScreen(
                concertId: state.pathParameters['concertId']!,
              );
              if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
                return NoTransitionPage(key: state.pageKey, child: child);
              }
              return dsFadeScalePage(key: state.pageKey, child: child);
            },
            routes: [
              GoRoute(
                path: 'operation',
                pageBuilder: (context, state) => dsFadeScalePage(
                  key: state.pageKey,
                  child: MaraudeOperationScreen(
                    concertId: state.pathParameters['concertId']!,
                  ),
                ),
              ),
            ],
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
            path: AppRoutes.venues,
            builder: (context, state) => const VenuesScreen(),
          ),
          GoRoute(
            path: AppRoutes.stock,
            builder: (context, state) => StockScreen(
              initialSection:
                  state.uri.queryParameters['section'] == 'equipment'
                  ? StockSection.equipment
                  : StockSection.consumables,
            ),
          ),
          GoRoute(
            path: AppRoutes.consumables,
            redirect: (context, state) =>
                '${AppRoutes.stock}?section=consumables',
          ),
          GoRoute(
            path: AppRoutes.equipment,
            redirect: (context, state) =>
                '${AppRoutes.stock}?section=equipment',
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
            path: AppRoutes.encounterMap,
            builder: (context, state) => const EncounterMapScreen(),
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
      AppRoutes.venues,
      AppRoutes.stock,
      AppRoutes.consumables,
      AppRoutes.equipment,
      AppRoutes.volunteers,
      AppRoutes.administration,
      AppRoutes.encounterMap,
      AppRoutes.styleGuide,
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
