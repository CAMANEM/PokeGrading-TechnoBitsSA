// ============================================================
// PokéGrading — Router Principal (Core)
// Configuración de rutas con go_router + Riverpod.
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/home/presentation/home_screen.dart';

/// Provider del router principal de la aplicación.
///
/// Usar [appRouterProvider] en lugar de instanciar GoRouter directamente
/// para mantener el router dentro del árbol de Riverpod y poder
/// redirigir basado en estado de autenticación en el futuro.
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: true,
    routes: [
      // ─── Rutas Públicas ────────────────────────────────
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) => const HomeScreen(),
      ),

      // ─── Sprint 1: Rutas de Auth (stub) ───────────────
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

      // ─── Sprint 1: Rutas de Catálogo (stub) ───────────
      // GoRoute(
      //   path: '/catalog',
      //   name: 'catalog',
      //   builder: (context, state) => const CatalogScreen(),
      // ),
    ],
    errorBuilder: (context, state) => _NotFoundScreen(error: state.error),
  );
});

/// Pantalla 404 — Ruta no encontrada
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
            const Text('Página no encontrada'),
            if (error != null) Text('$error'),
          ],
        ),
      ),
    );
  }
}
