import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';

class Sidebar extends StatelessWidget {
  const Sidebar({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final location = GoRouterState.of(context).uri.toString();

    int selectedIndex = switch (location) {
      '/' => 0,
      _ => 0,
    };

    return NavigationRail(
      extended: MediaQuery.of(context).size.width > 1300,
      leading: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          children: [
            Icon(Iconsax.shield_tick, size: 28, color: theme.colorScheme.primary),
            const SizedBox(height: 6),
            Text('AdminRoom', style: theme.textTheme.labelLarge),
          ],
        ),
      ),
      destinations: const [
        NavigationRailDestination(icon: Icon(Icons.dashboard_outlined), label: Text('Dashboard')),
        NavigationRailDestination(icon: Icon(Icons.person_outline), label: Text('Usuarios')),
        NavigationRailDestination(icon: Icon(Icons.report_outlined), label: Text('Reportes')),
      ],
      selectedIndex: switch (GoRouterState.of(context).uri.toString()) {
        '/' => 0,
        '/users' => 1,
        '/reports' => 2,
        _ => 0,
      },
      onDestinationSelected: (i) {
        switch (i) {
          case 0: context.go('/'); break;
          case 1: context.go('/users'); break;
          case 2: context.go('/reports'); break;
        }
      },
    );
  }
}
