// ============================================================
// PokéGrading — Main Router (Core)
// Route configuration using go_router + Riverpod.
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/home/presentation/home_screen.dart';

/// Provider for the main router of the application.
///
/// Use [appRouterProvider] instead of instantiating GoRouter directly
/// to keep the router inside the Riverpod graph and enable
/// redirection based on authentication state in the future.
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: true,
    routes: [
      // --- Public Routes ---
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) => const HomeScreen(),
      ),

      // --- Sprint 1: Auth Routes (stub) ---
      // GoRoute(
      //   path: '/login',
      //   name: 'login',
      //   builder: (context, state) => const LoginScreen(),
      // ),
      // GoRoute(
      //   path: '/register',
      //   name: 'register',
      //   builder: (context, state) => const RegisterScreen(),
      // ),

      // --- Sprint 1: Catalog Routes (stub) ---
      // GoRoute(
      //   path: '/catalog',
      //   name: 'catalog',
      //   builder: (context, state) => const CatalogScreen(),
      // ),
    ],
    errorBuilder: (context, state) => _NotFoundScreen(error: state.error),
  );
});

/// 404 Screen — Page Not Found
class _NotFoundScreen extends StatelessWidget {
  final Exception? error;
  const _NotFoundScreen({this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('404', style: TextStyle(fontSize: 64)),
            const Text('Page Not Found'),
            if (error != null) Text('$error'),
          ],
        ),
      ),
    );
  }
}
