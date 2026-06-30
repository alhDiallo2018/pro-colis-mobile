// ignore: unused_import
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';
import '../screens/auth/login_screen.dart';
import '../screens/dashboard/dashboard_screen.dart';

class AppRouter {
  static GoRouter router(AuthState authState) {
    return GoRouter(
      initialLocation: authState.isAuthenticated ? '/dashboard' : '/login',
      routes: [
        GoRoute(
          path: '/login',
          name: 'login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/dashboard',
          name: 'dashboard',
          builder: (context, state) => const DashboardScreen(),
        ),
      ],
    );
  }
}
