import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'widgets/sidebar.dart';

class ShellScaffold extends StatelessWidget {
  final Widget child;
  const ShellScaffold({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          const Sidebar(),
          const VerticalDivider(width: 1),
          Expanded(
            child: Column(
              children: [
                const _TopBar(),
                const Divider(height: 1),
                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  String _titleFor(String path) {
    // Puedes ampliar este switch según vayas añadiendo rutas
    switch (path) {
      case '/':
        return 'Dashboard';
      case '/users':
        return 'Usuarios';
      case '/reports':
        return 'Reportes';
      case '/photos':
        return 'Control de fotos';
      case '/feedback':
        return 'Feedbacks';
      case '/theme':
        return 'Tema semanal';
      case '/posts':
        return 'Posts';
      case '/promotions':
        return 'Promociones';
      default:
        return 'AdminRoom';
    }
  }

  @override
  Widget build(BuildContext context) {
    // go_router 14.x: ruta actual
    final location = GoRouterState.of(context).uri.toString();

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Text(
            _titleFor(location),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Ir a Dashboard',
            onPressed: () => context.go('/'),
            icon: const Icon(Icons.home_outlined),
          ),
        ],
      ),
    );
  }
}
