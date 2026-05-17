// ============================================================
// PokéGrading Frontend — Entry Point
// Flutter Web App con Riverpod como gestor de estado.
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/app_config.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';

void main() {
  // Asegurar que Flutter esté inicializado antes de usar plugins
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    // ProviderScope es el contenedor raíz de Riverpod.
    // Envuelve TODA la app para que cualquier widget pueda
    // acceder a los providers.
    const ProviderScope(
      child: PokéGradingApp(),
    ),
  );
}

/// Widget raíz de la aplicación PokéGrading.
///
/// [ConsumerWidget] de Riverpod permite leer providers
/// directamente desde el método build.
class PokéGradingApp extends ConsumerWidget {
  const PokéGradingApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      // ─── SEO & Metadata ──────────────────────────────────
      title: 'PokéGrading — Pre-Grading Asistido',
      debugShowCheckedModeBanner: false,

      // ─── Tema ────────────────────────────────────────────
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark, // Por defecto modo oscuro

      // ─── Navegación (go_router) ───────────────────────────
      routerConfig: router,
    );
  }
}
