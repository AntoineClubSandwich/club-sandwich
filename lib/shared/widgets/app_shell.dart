import 'package:club_sandwich/features/auth/application/auth_providers.dart';
import 'package:club_sandwich/features/concerts/data/concert_providers.dart';
import 'package:club_sandwich/features/organizations/data/organization_providers.dart';
import 'package:club_sandwich/features/profiles/data/profile_providers.dart';
import 'package:club_sandwich/features/profiles/domain/profile.dart';
import 'package:club_sandwich/features/volunteers/data/concert_volunteer_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class AppShell extends ConsumerWidget {
  const AppShell({required this.location, required this.child, super.key});

  final String location;
  final Widget child;

  static const _destinations = [
    _AppDestination(
      label: 'Tableau de bord',
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard,
      path: '/dashboard',
    ),
    _AppDestination(
      label: 'Concerts',
      icon: Icons.music_note_outlined,
      selectedIcon: Icons.music_note,
      path: '/concerts',
    ),
    _AppDestination(
      label: 'Opérations',
      icon: Icons.local_shipping_outlined,
      selectedIcon: Icons.local_shipping,
      path: '/operations',
    ),
    _AppDestination(
      label: 'Bénévoles',
      icon: Icons.groups_outlined,
      selectedIcon: Icons.groups,
      path: '/volunteers',
    ),
    _AppDestination(
      label: 'Lieux',
      icon: Icons.place_outlined,
      selectedIcon: Icons.place,
      path: '/venues',
    ),
    _AppDestination(
      label: 'Paramètres',
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
      path: '/settings',
    ),
  ];

  int get _selectedIndex {
    final index = _destinations.indexWhere(
      (destination) => location.startsWith(destination.path),
    );
    return index < 0 ? 0 : index;
  }

  void _navigate(BuildContext context, int index) {
    context.go(_destinations[index].path);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 840;
    final selectedIndex = _selectedIndex;
    final accountPanel = _UserAccountPanel(
      onSignedOut: () {
        ref.invalidate(currentProfileProvider);
        ref.invalidate(organizationsProvider);
        ref.invalidate(membershipsProvider);
        ref.invalidate(concertsProvider);
        ref.invalidate(concertDetailsProvider);
        ref.invalidate(concertVolunteerSectionProvider);
      },
    );

    if (!isDesktop) {
      return Scaffold(
        appBar: AppBar(title: Text(_destinations[selectedIndex].label)),
        drawer: Drawer(
          child: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: NavigationDrawer(
                    selectedIndex: selectedIndex,
                    onDestinationSelected: (index) {
                      Navigator.of(context).pop();
                      _navigate(context, index);
                    },
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(28, 20, 28, 24),
                        child: Text(
                          'Club Sandwich',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      for (final destination in _destinations)
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
      appBar: AppBar(title: Text(_destinations[selectedIndex].label)),
      body: Row(
        children: [
          SizedBox(
            width: 280,
            child: Column(
              children: [
                Expanded(
                  child: NavigationRail(
                    extended: true,
                    selectedIndex: selectedIndex,
                    onDestinationSelected: (index) => _navigate(context, index),
                    destinations: [
                      for (final destination in _destinations)
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
    } on Exception {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'La déconnexion a échoué. Vérifiez votre connexion et réessayez.',
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
                    Text(
                      primaryLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    if (showEmail)
                      Text(
                        email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
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
