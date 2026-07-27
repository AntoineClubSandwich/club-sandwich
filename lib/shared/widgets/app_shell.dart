import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppShell extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 840;
    final selectedIndex = _selectedIndex;

    if (!isDesktop) {
      return Scaffold(
        appBar: AppBar(title: Text(_destinations[selectedIndex].label)),
        drawer: Drawer(
          child: SafeArea(
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
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
        ),
        body: child,
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(_destinations[selectedIndex].label)),
      body: Row(
        children: [
          NavigationRail(
            extended: MediaQuery.sizeOf(context).width >= 1200,
            selectedIndex: selectedIndex,
            onDestinationSelected: (index) => _navigate(context, index),
            labelType: MediaQuery.sizeOf(context).width >= 1200
                ? NavigationRailLabelType.none
                : NavigationRailLabelType.all,
            destinations: [
              for (final destination in _destinations)
                NavigationRailDestination(
                  icon: Icon(destination.icon),
                  selectedIcon: Icon(destination.selectedIcon),
                  label: Text(destination.label),
                ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: child),
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
