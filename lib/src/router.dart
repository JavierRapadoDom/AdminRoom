import 'package:adminroom/src/screens/reports/reports_screen.dart';
import 'package:adminroom/src/screens/users/users_screen.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'shell.dart';
import 'screens/dashboard_screen.dart';


GoRouter buildRouter() {
  return GoRouter(
    initialLocation: '/',
    routes: [
      ShellRoute(
        builder: (context, state, child) => ShellScaffold(child: child),
        routes: [
          GoRoute(path: '/', builder: (c, s) => const DashboardScreen()),
          GoRoute(path: '/users', builder: (c, s) => const UsersScreen()),
          GoRoute(path: '/reports', builder: (c, s) => const ReportsScreen()),
        ],
      ),
    ],
  );
}
