import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';
import 'home_api.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _homeApi = HomeApi();
  late Future<Map<String, dynamic>> _healthFuture;

  @override
  void initState() {
    super.initState();
    _healthFuture = _homeApi.fetchHealth();
  }

  void _refreshHealth() {
    setState(() {
      _healthFuture = _homeApi.fetchHealth();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _PokeGradingLogo(),
              const SizedBox(height: 48),
              _WelcomeCard(theme: theme),
              const SizedBox(height: 24),
              _HealthCheckCard(
                healthFuture: _healthFuture,
                onRefresh: _refreshHealth,
              ),
              const SizedBox(height: 32),
              const _StackInfoRow(),
            ],
          ),
        ),
      ),
    );
  }
}

class _PokeGradingLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primary, AppColors.accent],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.4),
                blurRadius: 32,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.catching_pokemon_rounded,
            color: Colors.white,
            size: 52,
          ),
        ),
        const SizedBox(height: 20),
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [AppColors.primary, AppColors.accent],
          ).createShader(bounds),
          child: Text(
            'PokéGrading',
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Assisted Pre-Grading System',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primary.withOpacity(0.3)),
          ),
          child: Text(
            'v${AppConfig.appVersion} — Sprint 1',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.primaryLight,
                ),
          ),
        ),
      ],
    );
  }
}

class _WelcomeCard extends StatelessWidget {
  final ThemeData theme;
  const _WelcomeCard({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 560,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderDark),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.waving_hand_rounded,
                  color: AppColors.accent, size: 22),
              const SizedBox(width: 10),
              Text(
                'Hello, World!',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'The base structure of the PokéGrading project is ready. '
            'This is the starting point for Sprint 2.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 16),
          const Divider(color: AppColors.borderDark),
          const SizedBox(height: 16),
          const _InfoRow(
            icon: Icons.architecture_rounded,
            label: 'Layer Architecture',
            value: 'Presentation → Application → Domain → Persistance → Data',
          ),
          const SizedBox(height: 8),
          const _InfoRow(
            icon: Icons.layers_rounded,
            label: 'Proyect State',
            value: 'in development',
          ),
          const SizedBox(height: 8),
          const _InfoRow(
            icon: Icons.storage_rounded,
            label: 'Database',
            value: 'PostgreSQL 16',
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () => context.goNamed('register'),
            icon: const Icon(Icons.person_add_alt_1_rounded),
            label: const Text('Registrar usuario normal'),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: () => context.goNamed('catalog_add_card'),
            icon: const Icon(Icons.add_photo_alternate_rounded),
            label: const Text('Agregar carta al catalogo'),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 16),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}

class _HealthCheckCard extends StatelessWidget {
  final Future<Map<String, dynamic>> healthFuture;
  final VoidCallback onRefresh;

  const _HealthCheckCard({
    required this.healthFuture,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 560,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.monitor_heart_rounded,
                      color: AppColors.primary, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Backend Health Check',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                        ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded,
                    color: AppColors.textSecondary, size: 18),
                tooltip: 'Refresh',
                onPressed: onRefresh,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FutureBuilder<Map<String, dynamic>>(
            future: healthFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Connecting to backend...',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                );
              }

              if (snapshot.hasError) {
                return const Row(
                  children: [
                    Icon(Icons.error_outline_rounded,
                        color: AppColors.error, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Backend unavailable — Make sure to run:\n'
                        'cd backend && dart run bin/server.dart',
                        style: TextStyle(
                          color: AppColors.error,
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                );
              }

              final data = snapshot.data ?? {};
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      SizedBox(
                        width: 8,
                        height: 8,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: AppColors.success,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Backend connected',
                        style: TextStyle(
                          color: AppColors.success,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...data.entries.map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '${e.key}: ${e.value}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _StackInfoRow extends StatelessWidget {
  const _StackInfoRow();

  @override
  Widget build(BuildContext context) {
    const items = [
      (icon: '🎯', label: 'Flutter Web'),
      (icon: '🎯', label: 'Dart + Shelf'),
      (icon: '🐘', label: 'PostgreSQL'),
      (icon: '🧭', label: 'go_router'),
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: items
          .map(
            (item) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceDark,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.borderDark),
              ),
              child: Text(
                '${item.icon}  ${item.label}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}
