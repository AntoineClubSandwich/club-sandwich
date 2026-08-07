import 'package:club_sandwich/design_system/components/ds_pressable.dart';
import 'package:club_sandwich/design_system/icons/ds_icons.dart';
import 'package:club_sandwich/design_system/tokens/ds_borders.dart';
import 'package:club_sandwich/design_system/tokens/ds_motion.dart';
import 'package:club_sandwich/design_system/tokens/ds_radius.dart';
import 'package:club_sandwich/design_system/tokens/ds_shadows.dart';
import 'package:club_sandwich/design_system/tokens/ds_spacing.dart';
import 'package:club_sandwich/design_system/tokens/ds_theme.dart';
import 'package:club_sandwich/design_system/tokens/ds_tokens.dart';
import 'package:club_sandwich/design_system/tokens/ds_typography.dart';
import 'package:club_sandwich/design_system/widgets/club_sandwich_mascot.dart';
import 'package:club_sandwich/features/auth/application/auth_providers.dart';
import 'package:club_sandwich/features/auth/domain/user_account.dart';
import 'package:club_sandwich/features/concerts/data/concert_providers.dart';
import 'package:club_sandwich/features/organizations/data/organization_providers.dart';
import 'package:club_sandwich/features/invitations/data/invitation_providers.dart';
import 'package:club_sandwich/features/notifications/data/workflow_notification_providers.dart';
import 'package:club_sandwich/features/notifications/presentation/workflow_notifications_button.dart';
import 'package:club_sandwich/features/profiles/data/profile_providers.dart';
import 'package:club_sandwich/features/profiles/domain/profile.dart';
import 'package:club_sandwich/features/volunteers/data/concert_volunteer_providers.dart';
import 'package:club_sandwich/shared/utils/error_messages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class AppShell extends ConsumerWidget {
  const AppShell({required this.location, required this.child, super.key});

  final String location;
  final Widget child;

  int _selectedIndex(List<_AppDestination> destinations) {
    final index = destinations.indexWhere(
      (destination) => location.startsWith(destination.path),
    );
    return index < 0 ? 0 : index;
  }

  void _navigate(
    BuildContext context,
    List<_AppDestination> destinations,
    int index,
  ) {
    context.go(destinations[index].path);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 840;
    final userContext = ref.watch(currentUserContextProvider).value;
    final destinations = _destinationsFor(
      userContext?.role ?? AppUserRole.volunteer,
    );
    final selectedIndex = _selectedIndex(destinations);
    void onSignedOut() {
      ref.invalidate(currentProfileProvider);
      ref.invalidate(organizationsProvider);
      ref.invalidate(membershipsProvider);
      ref.invalidate(concertsProvider);
      ref.invalidate(concertDetailsProvider);
      ref.invalidate(maraudeOverviewProvider);
      ref.invalidate(concertVolunteerSectionProvider);
      ref.invalidate(invitationCampaignsProvider);
      ref.invalidate(workflowNotificationsProvider);
      ref.invalidate(currentUserContextProvider);
      ref.invalidate(managedUsersProvider);
    }

    final accountPanel = _UserAccountPanel(onSignedOut: onSignedOut);

    if (!isDesktop) {
      return Scaffold(
        appBar: AppBar(
          title: Text(destinations[selectedIndex].label),
          actions: const [WorkflowNotificationsButton()],
        ),
        drawer: Drawer(
          child: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: NavigationDrawer(
                    selectedIndex: selectedIndex,
                    onDestinationSelected: (index) {
                      Navigator.of(context).pop();
                      _navigate(context, destinations, index);
                    },
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(20, 20, 20, 24),
                        child: Row(
                          children: [
                            ClubSandwichMascot(
                              size: 28,
                              color: MascotColor.blue,
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Club Sandwich',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      for (final destination in destinations)
                        NavigationDrawerDestination(
                          icon: Icon(destination.icon),
                          selectedIcon: Icon(destination.selectedIcon),
                          label: Text(destination.label),
                        ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                accountPanel,
              ],
            ),
          ),
        ),
        body: child,
      );
    }

    final isAdmin =
        (userContext?.role ?? AppUserRole.volunteer) == AppUserRole.admin;

    return Scaffold(
      appBar: AppBar(
        title: Text(destinations[selectedIndex].label),
        actions: const [WorkflowNotificationsButton()],
      ),
      body: Row(
        children: [
          if (isAdmin)
            Theme(
              data: DsTheme.light,
              child: _AdminDesktopSidebar(
                destinations: destinations,
                selectedIndex: selectedIndex,
                onSelected: (index) => _navigate(context, destinations, index),
                accountPanel: _UserAccountPanel(
                  onSignedOut: onSignedOut,
                  admin: true,
                ),
              ),
            )
          else ...[
            SizedBox(
              width: 280,
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 20, 20, 12),
                    child: Row(
                      children: [
                        ClubSandwichMascot(size: 28, color: MascotColor.blue),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Club Sandwich',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: NavigationRail(
                      extended: true,
                      selectedIndex: selectedIndex,
                      onDestinationSelected: (index) =>
                          _navigate(context, destinations, index),
                      destinations: [
                        for (final destination in destinations)
                          NavigationRailDestination(
                            icon: Icon(destination.icon),
                            selectedIcon: Icon(destination.selectedIcon),
                            label: Text(destination.label),
                          ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  accountPanel,
                ],
              ),
            ),
            const VerticalDivider(width: 1),
          ],
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _UserAccountPanel extends ConsumerStatefulWidget {
  const _UserAccountPanel({required this.onSignedOut, this.admin = false});

  final VoidCallback onSignedOut;

  /// When true, renders the neo-brutalist admin-sidebar variant (ink
  /// border, hard shadow, thick-bordered sign-out button) instead of the
  /// plain Material card used by the mobile drawer and non-admin roles.
  /// Same underlying sign-out logic either way.
  final bool admin;

  @override
  ConsumerState<_UserAccountPanel> createState() => _UserAccountPanelState();
}

class _UserAccountPanelState extends ConsumerState<_UserAccountPanel> {
  bool _isSigningOut = false;

  Future<void> _signOut() async {
    if (_isSigningOut) return;

    setState(() => _isSigningOut = true);
    try {
      await ref.read(authRepositoryProvider).signOut();
      widget.onSignedOut();
      if (mounted) context.go('/login');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            describeError(
              error,
              'La déconnexion a échoué. Vérifiez votre connexion et '
              'réessayez.',
            ),
          ),
        ),
      );
      setState(() => _isSigningOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider).value;
    final user = ref.watch(currentAuthUserProvider);
    final email = user?.email?.trim();
    final displayName = _profileDisplayName(profile);
    final primaryLabel = displayName ?? email ?? 'Compte connecté';
    final showEmail =
        email != null && email.isNotEmpty && email != primaryLabel;

    if (widget.admin) {
      final tokens = Theme.of(context).extension<DsTokens>()!;
      final colors = tokens.colors;
      return Container(
        margin: const EdgeInsets.all(DsSpacing.lg),
        padding: const EdgeInsets.all(DsSpacing.md),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: DsRadius.mdRadius,
          border: Border.all(
            color: colors.borderStrong,
            width: DsBorders.thick,
          ),
          boxShadow: DsShadows.card(colors.borderStrong),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: colors.borderStrong,
                      width: DsBorders.standard,
                    ),
                  ),
                  child: Text(
                    _accountInitial(primaryLabel),
                    semanticsLabel: 'Compte utilisateur',
                    style: DsTypography.body.copyWith(
                      color: colors.textOnColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: DsSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Tooltip(
                        message: primaryLabel,
                        child: Text(
                          primaryLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: DsTypography.body.copyWith(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (showEmail)
                        Tooltip(
                          message: email,
                          child: Text(
                            email,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: DsTypography.caption.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: DsSpacing.md),
            DsPressable(
              enabled: !_isSigningOut,
              onTap: _signOut,
              builder: (context, state) {
                final shadow = DsShadows.card(colors.borderStrong);
                final pressDelta = state.pressed
                    ? shadow.first.offset
                    : Offset.zero;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  transform: Matrix4.translationValues(
                    pressDelta.dx,
                    pressDelta.dy,
                    0,
                  ),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: DsSpacing.sm + 2,
                  ),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colors.primary,
                    borderRadius: DsRadius.smRadius,
                    border: Border.all(
                      color: colors.borderStrong,
                      width: DsBorders.thick,
                    ),
                    boxShadow: state.pressed ? const [] : shadow,
                  ),
                  child: _isSigningOut
                      ? SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colors.textOnColor,
                          ),
                        )
                      : Text(
                          'SE DÉCONNECTER',
                          style: DsTypography.caption.copyWith(
                            color: colors.textOnColor,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                );
              },
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                child: Text(
                  _accountInitial(primaryLabel),
                  semanticsLabel: 'Compte utilisateur',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Tooltip(
                      message: primaryLabel,
                      child: Text(
                        primaryLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    if (showEmail)
                      Tooltip(
                        message: email,
                        child: Text(
                          email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: _isSigningOut ? null : _signOut,
            icon: _isSigningOut
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.logout),
            label: Text(_isSigningOut ? 'Déconnexion…' : 'Se déconnecter'),
          ),
        ],
      ),
    );
  }
}

String? _profileDisplayName(Profile? profile) {
  if (profile == null) return null;
  final name = '${profile.firstName.trim()} ${profile.lastName.trim()}'.trim();
  return name.isEmpty ? null : name;
}

String _accountInitial(String label) {
  final normalizedLabel = label.trim();
  return normalizedLabel.isEmpty ? '?' : normalizedLabel[0].toUpperCase();
}

/// Neo-brutalist admin sidebar (desktop only) — same [_AppDestination]
/// route list and navigation behavior as the stock rail it replaces, only
/// the visuals differ: navy background, ink-bordered logo chip and nav
/// pills, a mascot widget, and the restyled [_UserAccountPanel].
class _AdminDesktopSidebar extends StatelessWidget {
  const _AdminDesktopSidebar({
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
    required this.accountPanel,
  });

  final List<_AppDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final Widget accountPanel;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<DsTokens>()!;
    final colors = tokens.colors;

    return Container(
      width: 280,
      color: colors.secondary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              DsSpacing.lg,
              DsSpacing.lg,
              DsSpacing.lg,
              DsSpacing.sm,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: DsSpacing.sm,
                vertical: DsSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: colors.primary,
                borderRadius: DsRadius.smRadius,
                border: Border.all(
                  color: colors.borderStrong,
                  width: DsBorders.thick,
                ),
                boxShadow: DsShadows.card(colors.borderStrong),
              ),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: DsRadius.smRadius,
                      border: Border.all(
                        color: colors.borderStrong,
                        width: DsBorders.standard,
                      ),
                    ),
                    padding: const EdgeInsets.all(3),
                    child: const ClubSandwichMascot(
                      size: 22,
                      color: MascotColor.orange,
                    ),
                  ),
                  const SizedBox(width: DsSpacing.sm),
                  Expanded(
                    child: Text(
                      'CLUB SANDWICH',
                      overflow: TextOverflow.ellipsis,
                      style: DsTypography.caption.copyWith(
                        color: colors.textOnColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: DsSpacing.lg,
                vertical: DsSpacing.sm,
              ),
              child: Column(
                children: [
                  for (var i = 0; i < destinations.length; i++) ...[
                    if (i > 0) const SizedBox(height: DsSpacing.sm),
                    _AdminNavItem(
                      label: destinations[i].label,
                      icon: _adminSidebarIcon(destinations[i].path),
                      selected: i == selectedIndex,
                      onTap: () => onSelected(i),
                    ),
                  ],
                  const SizedBox(height: DsSpacing.xl),
                  const _AdminMascotWidget(),
                ],
              ),
            ),
          ),
          accountPanel,
        ],
      ),
    );
  }
}

/// Maps an admin route path to the Lucide icon shown in the neo-brutalist
/// sidebar. Purely a visual lookup — does not affect routing.
IconData _adminSidebarIcon(String path) => switch (path) {
  '/maraudes' => DsIcons.truck,
  '/invitations' => DsIcons.mail,
  '/organizations' => DsIcons.building2,
  '/volunteers' => DsIcons.users2,
  '/administration' => DsIcons.settings,
  _ => DsIcons.layoutDashboard,
};

class _AdminNavItem extends StatelessWidget {
  const _AdminNavItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<DsTokens>()!;
    final colors = tokens.colors;

    return DsPressable(
      onTap: onTap,
      builder: (context, state) {
        final background = selected
            ? colors.primary
            : (state.hovered ? colors.secondaryHover : colors.surface);
        final foreground = selected ? colors.textOnColor : colors.textPrimary;

        return Semantics(
          selected: selected,
          button: true,
          label: label,
          child: AnimatedContainer(
            duration: DsMotion.standard,
            curve: DsMotion.curve,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: DsSpacing.md,
              vertical: DsSpacing.sm + 2,
            ),
            decoration: BoxDecoration(
              color: background,
              borderRadius: DsRadius.smRadius,
              border: selected
                  ? Border.all(
                      color: colors.borderStrong,
                      width: DsBorders.standard,
                    )
                  : null,
              boxShadow: selected ? DsShadows.card(colors.borderStrong) : null,
            ),
            child: Row(
              children: [
                Icon(icon, size: 20, color: foreground),
                const SizedBox(width: DsSpacing.md),
                Expanded(
                  child: Text(
                    label,
                    style: DsTypography.body.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Decorative mascot widget in the admin sidebar. The "Personnaliser"
/// button is intentionally disabled — no mascot-customization feature
/// exists yet; this reserves the spot without simulating one.
class _AdminMascotWidget extends StatelessWidget {
  const _AdminMascotWidget();

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<DsTokens>()!;
    final colors = tokens.colors;

    return Container(
      padding: const EdgeInsets.all(DsSpacing.md),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: DsRadius.smRadius,
        border: Border.all(color: colors.borderStrong, width: DsBorders.heavy),
        boxShadow: DsShadows.elevated(colors.borderStrong),
      ),
      child: Column(
        children: [
          const ClubSandwichMascot(size: 140, color: MascotColor.orange),
          const SizedBox(height: DsSpacing.md),
          ExcludeSemantics(
            child: Opacity(
              opacity: 0.5,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: DsSpacing.sm),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.primary,
                  borderRadius: DsRadius.smRadius,
                  border: Border.all(
                    color: colors.borderStrong,
                    width: DsBorders.thick,
                  ),
                ),
                child: Text(
                  'PERSONNALISER',
                  style: DsTypography.caption.copyWith(
                    color: colors.textOnColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AppDestination {
  const _AppDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.path,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String path;
}

List<_AppDestination> _destinationsFor(AppUserRole role) {
  const dashboard = _AppDestination(
    label: 'Tableau de bord',
    icon: Icons.dashboard_outlined,
    selectedIcon: Icons.dashboard,
    path: '/dashboard',
  );
  const maraudes = _AppDestination(
    label: 'Maraudes',
    icon: Icons.volunteer_activism_outlined,
    selectedIcon: Icons.volunteer_activism,
    path: '/maraudes',
  );
  const invitations = _AppDestination(
    label: 'Invitations',
    icon: Icons.confirmation_number_outlined,
    selectedIcon: Icons.confirmation_number,
    path: '/invitations',
  );
  return switch (role) {
    AppUserRole.admin => const [
      dashboard,
      maraudes,
      invitations,
      _AppDestination(
        label: 'Organisations',
        icon: Icons.business_outlined,
        selectedIcon: Icons.business,
        path: '/organizations',
      ),
      _AppDestination(
        label: 'Bénévoles',
        icon: Icons.groups_outlined,
        selectedIcon: Icons.groups,
        path: '/volunteers',
      ),
      _AppDestination(
        label: 'Administration',
        icon: Icons.admin_panel_settings_outlined,
        selectedIcon: Icons.admin_panel_settings,
        path: '/administration',
      ),
    ],
    AppUserRole.promoter => const [
      dashboard,
      _AppDestination(
        label: 'Mes maraudes',
        icon: Icons.volunteer_activism_outlined,
        selectedIcon: Icons.volunteer_activism,
        path: '/maraudes',
      ),
      _AppDestination(
        label: 'Mes invitations',
        icon: Icons.confirmation_number_outlined,
        selectedIcon: Icons.confirmation_number,
        path: '/invitations',
      ),
      _AppDestination(
        label: 'Mon compte',
        icon: Icons.account_circle_outlined,
        selectedIcon: Icons.account_circle,
        path: '/account',
      ),
    ],
    AppUserRole.volunteer => const [
      _AppDestination(
        label: 'Accueil',
        icon: Icons.home_outlined,
        selectedIcon: Icons.home,
        path: '/dashboard',
      ),
      _AppDestination(
        label: 'Mes maraudes',
        icon: Icons.volunteer_activism_outlined,
        selectedIcon: Icons.volunteer_activism,
        path: '/maraudes',
      ),
      invitations,
      _AppDestination(
        label: 'Mon profil',
        icon: Icons.person_outline,
        selectedIcon: Icons.person,
        path: '/profile',
      ),
    ],
  };
}
