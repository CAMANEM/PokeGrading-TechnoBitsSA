// ============================================================
// PokéGrading Frontend — Entry Point
// Flutter Web App with Riverpod as state manager.
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';

void main() {
  // Ensure that Flutter is initialized before using plugins
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    // ProviderScope is the root container of Riverpod.
    // Wraps the entire app so any widget can access providers.
    const ProviderScope(
      child: PokeGradingApp(),
    ),
  );
}

/// Root widget of the PokéGrading application.
///
/// Riverpod's [ConsumerWidget] allows reading providers
/// directly within the build method.
class PokeGradingApp extends ConsumerWidget {
  const PokeGradingApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      // --- SEO & Metadata ---
      title: 'PokéGrading — Assisted Pre-Grading',
      debugShowCheckedModeBanner: false,

      // --- Theme ---
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark, // Dark mode by default

      // --- Navigation (go_router) ---
      routerConfig: router,
    );
  }
}
