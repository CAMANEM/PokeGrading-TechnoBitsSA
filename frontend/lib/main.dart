/*
 Main entrypoint for the Flutter frontend.

 Initializes Flutter bindings and configures `MaterialApp.router` with the
 application's theme and route configuration defined in `app_router.dart`.
*/
import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'presentation/app_router.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PokeGradingApp());
}

/// @brief PokeGradingApp
class PokeGradingApp extends StatelessWidget {
  const PokeGradingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'PokéGrading — Assisted Pre-Grading',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      routerConfig: appRouter,
    );
  }
}
