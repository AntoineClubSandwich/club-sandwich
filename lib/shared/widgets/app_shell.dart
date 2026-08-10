import 'package:club_sandwich/design_system/components/ds_pressable.dart';
import 'package:club_sandwich/design_system/components/navigation/ds_top_bar.dart';
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

  /// Key on the desktop sidebar's root container, so widget tests can
  /// assert its presence without depending on Material internals like
  /// `NavigationRail`.
  static const desktopSidebarKey = ValueKey('appShellDesktopSidebar');

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
    final isAdmin =
        (userContext?.role ?? AppUserRole.volunteer) == AppUserRole.admin;

    // Wrapped in a local DsTheme.light regardless of the ambient theme:
    // AppShell is exercised directly (without ClubSandwichApp's app-wide
    // theme) by several widget tests, so DsTokens must not depend on it.
    if (!isDesktop) {
      return Theme(
        data: DsTheme.light,
        child: Scaffold(
          appBar: DsTopBar(
            title: destinations[selectedIndex].label,
            leading: Builder(
              builder: (context) => IconButton(
                icon: Icon(DsIcons.menu),
                tooltip: 'Menu',
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
            actions: const [WorkflowNotificationsButton()],
          ),
          drawer: Drawer(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: Builder(
              builder: (context) {
                final tokens = Theme.of(context).extension<DsTokens>()!;
                final colors = tokens.colors;
                return Container(
                  decoration: BoxDecoration(
                    color: colors.canvas,
                    border: Border(
                      right: BorderSide(
                        color: colors.border,
                        width: DsBorders.hairline,
                      ),
                    ),
                  ),
                  child: SafeArea(
                    child: Column(
                      children: [
                        const Padding(
                          padding: EdgeInsets.fromLTRB(
                            DsSpacing.lg,
                            DsSpacing.lg,
                            DsSpacing.lg,
                            DsSpacing.sm,
                          ),
                          child: _SidebarLogo(),
                        ),
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(
                              horizontal: DsSpacing.lg,
                              vertical: DsSpacing.sm,
                            ),
                            child: Column(
                              children: [
                                for (
                                  var i = 0;
                                  i < destinations.length;
                                  i++
                                ) ...[
                                  if (i > 0)
                                    const SizedBox(height: DsSpacing.sm),
                                  _DsNavItem(
                                    label: destinations[i].label,
                                    icon: _sidebarIcon(destinations[i].path),
                                    selected: i == selectedIndex,
                                    onTap: () {
                                      Navigator.of(context).pop();
                                      _navigate(context, destinations, i);
                                    },
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        accountPanel,
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          body: child,
        ),
      );
    }

    return Theme(
      data: DsTheme.light,
      child: Scaffold(
        appBar: DsTopBar(
          title: destinations[selectedIndex].label,
          actions: const [WorkflowNotificationsButton()],
        ),
        body: Row(
          children: [
            _DsSidebar(
              dark: isAdmin,
              destinations: destinations,
              selectedIndex: selectedIndex,
              onSelected: (index) => _navigate(context, destinations, index),
              accountPanel: accountPanel,
            ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

/// Bordered "CLUB SANDWICH" logo chip shown atop the mobile drawer and the
/// desktop sidebar (both admin and non-admin variants).
class _SidebarLogo extends StatelessWidget {
  const _SidebarLogo();

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<DsTokens>()!;
    final colors = tokens.colors;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DsSpacing.sm,
        vertical: DsSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: colors.primary,
        borderRadius: DsRadius.smRadius,
        boxShadow: DsShadows.accent(colors.primary),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: DsRadius.smRadius,
            ),
            padding: const EdgeInsets.all(3),
            child: const ClubSandwichMascot(size: 22, color: MascotColor.orange),
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
    );
  }
}

/// Small "ADMIN" pill shown under the logo in the tinted admin sidebar —
/// the non-color cue that reinforces the sidebar's purple tint, so the
/// distinction doesn't rely on color alone.
class _AdminBadge extends StatelessWidget {
  const _AdminBadge();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<DsTokens>()!.colors;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DsSpacing.sm,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: DsRadius.pillRadius,
        boxShadow: DsShadows.accent(colors.primary),
      ),
      child: Text(
        'ADMIN',
        style: DsTypography.caption.copyWith(
          color: colors.primary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _UserAccountPanel extends ConsumerStatefulWidget {
  const _UserAccountPanel({required this.onSignedOut});

  final VoidCallback onSignedOut;

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
    final tokens = Theme.of(context).extension<DsTokens>()!;
    final colors = tokens.colors;

    return Container(
      margin: const EdgeInsets.all(DsSpacing.lg),
      padding: const EdgeInsets.all(DsSpacing.md),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: DsRadius.xlRadius,
        border: Border.all(color: colors.border, width: DsBorders.hairline),
        boxShadow: DsShadows.ambient(colors.textPrimary),
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
              return DsPressScale(
                pressed: state.pressed,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: DsSpacing.sm + 2,
                  ),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: state.hovered
                        ? colors.neutralHoverOverlay
                        : Colors.transparent,
                    borderRadius: DsRadius.mdRadius,
                    border: Border.all(
                      color: colors.border,
                      width: DsBorders.hairline,
                    ),
                  ),
                  child: _isSigningOut
                      ? SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colors.textSecondary,
                          ),
                        )
                      : Text(
                          'SE DÉCONNECTER',
                          style: DsTypography.caption.copyWith(
                            color: colors.textSecondary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
              );
            },
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

/// Desktop sidebar. [dark] switches between the admin-only treatment (a
/// deep, softened indigo — [DsColorTokens.secondaryMuted], not a stark
/// black — plus mascot widget + "ADMIN" badge) and the plain canvas
/// treatment used by every other role — same [_AppDestination] route
/// list and navigation behavior either way, only the visuals differ.
class _DsSidebar extends StatelessWidget {
  const _DsSidebar({
    required this.dark,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
    required this.accountPanel,
  });

  final bool dark;
  final List<_AppDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final Widget accountPanel;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<DsTokens>()!;
    final colors = tokens.colors;

    return Container(
      key: AppShell.desktopSidebarKey,
      width: 280,
      decoration: BoxDecoration(
        color: dark ? colors.secondaryMuted : colors.canvas,
        border: Border(
          right: BorderSide(color: colors.border, width: DsBorders.hairline),
        ),
      ),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SidebarLogo(),
                if (dark) ...[
                  const SizedBox(height: DsSpacing.sm),
                  const _AdminBadge(),
                ],
              ],
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
                    _DsNavItem(
                      label: destinations[i].label,
                      icon: _sidebarIcon(destinations[i].path),
                      selected: i == selectedIndex,
                      dark: dark,
                      onTap: () => onSelected(i),
                    ),
                  ],
                  if (dark) ...[
                    const SizedBox(height: DsSpacing.xl),
                    const _AdminMascotWidget(),
                  ],
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

/// Maps a route path to the Lucide icon shown in the desktop sidebar and
/// mobile drawer. Purely a visual lookup — does not affect routing.
IconData _sidebarIcon(String path) => switch (path) {
  '/maraudes' => DsIcons.truck,
  '/invitations' => DsIcons.mail,
  '/organizations' => DsIcons.building2,
  '/volunteers' => DsIcons.users2,
  '/administration' => DsIcons.settings,
  '/profile' || '/account' => DsIcons.user,
  '/dashboard' => DsIcons.home,
  _ => DsIcons.layoutDashboard,
};

class _DsNavItem extends StatelessWidget {
  const _DsNavItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.dark = false,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  /// Whether this item sits on the deep-indigo admin sidebar (unselected
  /// items render as white cards) versus the plain canvas sidebar/drawer
  /// (unselected items are transparent with a subtle hover tint).
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<DsTokens>()!;
    final colors = tokens.colors;

    return DsPressable(
      onTap: onTap,
      builder: (context, state) {
        final background = selected
            ? colors.primary
            : dark
            // Always white, never the sidebar's own tint on hover — that
            // would make the item blend into the background instead of
            // standing out.
            ? colors.surface
            : (state.hovered ? colors.neutralHoverOverlay : Colors.transparent);
        final foreground = selected ? colors.textOnColor : colors.textPrimary;
        final unselectedHoverShadow = dark && state.hovered && !selected
            ? DsShadows.ambient(colors.textPrimary)
            : null;

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
              borderRadius: DsRadius.mdRadius,
              boxShadow: selected
                  ? DsShadows.accent(colors.primary)
                  : unselectedHoverShadow,
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
        borderRadius: DsRadius.xlRadius,
        border: Border.all(color: colors.border, width: DsBorders.hairline),
        boxShadow: DsShadows.ambientElevated(colors.textPrimary),
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
                  borderRadius: DsRadius.mdRadius,
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
