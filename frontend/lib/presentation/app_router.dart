/*
 Application route configuration for the frontend.

 Exposes `appRouter` (a `GoRouter`) that maps top-level paths to the main
 screens used in the demo application. The router also provides a minimal
 not-found screen used during development.
*/
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'home/home_screen.dart';
import 'submitter_catalog/create_card/create_card_screen.dart';
import 'user/register/register_screen.dart';
import 'submitter_catalog/submit_evaluation/submit_evaluation_screen.dart';
import 'submitter_catalog/search_card/search_card_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  debugLogDiagnostics: true,
  routes: [
    GoRoute(
      path: '/',
      name: 'home',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/register',
      name: 'register',
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: '/catalog/add-card',
      name: 'catalog_add_card',
      builder: (context, state) => const CreateCardScreen(),
    ),
    GoRoute(
      path: '/evaluations',
      name: 'evaluations',
      builder: (context, state) => const SubmitEvaluationScreen(),
    ),
    GoRoute(
      path: '/catalog/search',
      name: 'catalog_search',
      builder: (context, state) => const SearchCardScreen(),
    ),
  ],
  errorBuilder: (context, state) => _NotFoundScreen(error: state.error),
);

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
