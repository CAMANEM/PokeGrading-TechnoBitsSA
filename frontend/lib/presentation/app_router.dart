import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'home/home_screen.dart';
import 'submitter_catalog/create_card/create_card_screen.dart';
import 'user/register/register_screen.dart';
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
