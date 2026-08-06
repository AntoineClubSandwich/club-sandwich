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
    final accountPanel = _UserAccountPanel(
      onSignedOut: () {
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
      },
    );

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

    return Scaffold(
      appBar: AppBar(
        title: Text(destinations[selectedIndex].label),
        actions: const [WorkflowNotificationsButton()],
      ),
      body: Row(
        children: [
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
          Expanded(child: child),
        ],
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
