// ============================================================
// PokéGrading — Home Screen (Hello World)
// Pantalla principal que verifica la conexión con el backend.
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_theme.dart';
import '../application/health_provider.dart';

/// Pantalla principal — Hello World + Health Check
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final healthAsync = ref.watch(healthCheckProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ─── Logo / Título ────────────────────────
              _PokeGradingLogo(),
              const SizedBox(height: 48),

              // ─── Tarjeta de Bienvenida ────────────────
              _WelcomeCard(theme: theme),
              const SizedBox(height: 24),

              // ─── Health Check del Backend ─────────────
              _HealthCheckCard(healthAsync: healthAsync, ref: ref),
              const SizedBox(height: 32),

              // ─── Stack Info ───────────────────────────
              _StackInfoRow(),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Widgets Privados ────────────────────────────────────────

class _PokeGradingLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Ícono con gradiente
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
                color: AppColors.primary.withValues(alpha: 0.4),
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
          'Sistema Asistido de Pre-Grading',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
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
            color: Colors.black.withValues(alpha: 0.3),
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
              Text('¡Hola, Mundo!',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: AppColors.textPrimary,
                  )),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'La estructura base del proyecto PokéGrading está lista. '
            'Este es el punto de partida del Sprint 1.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 16),
          const Divider(color: AppColors.borderDark),
          const SizedBox(height: 16),
          _InfoRow(
            icon: Icons.architecture_rounded,
            label: 'Arquitectura',
            value: 'Layered + Feature-based',
          ),
          const SizedBox(height: 8),
          _InfoRow(
            icon: Icons.layers_rounded,
            label: 'Estado',
            value: 'Riverpod',
          ),
          const SizedBox(height: 8),
          _InfoRow(
            icon: Icons.storage_rounded,
            label: 'Base de datos',
            value: 'PostgreSQL 16',
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
  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 16),
        const SizedBox(width: 8),
        Text('$label: ',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            )),
        Text(value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            )),
      ],
    );
  }
}

class _HealthCheckCard extends StatelessWidget {
  final AsyncValue<Map<String, dynamic>> healthAsync;
  final WidgetRef ref;
  const _HealthCheckCard({required this.healthAsync, required this.ref});

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
                  Text('Backend Health Check',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                      )),
                ],
              ),
              // Botón de refresh
              IconButton(
                icon: const Icon(Icons.refresh_rounded,
                    color: AppColors.textSecondary, size: 18),
                tooltip: 'Refrescar',
                onPressed: () => ref.invalidate(healthCheckProvider),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          healthAsync.when(
            loading: () => const Row(
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
                Text('Conectando con el backend...',
                    style: TextStyle(color: AppColors.textSecondary)),
              ],
            ),
            error: (err, _) => Row(
              children: [
                const Icon(Icons.error_outline_rounded,
                    color: AppColors.error, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Backend no disponible — Asegúrate de ejecutar:\n'
                    'cd backend && dart run bin/server.dart',
                    style: const TextStyle(
                        color: AppColors.error, fontSize: 13, height: 1.5),
                  ),
                ),
              ],
            ),
            data: (data) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('Backend conectado',
                        style: TextStyle(
                            color: AppColors.success,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 8),
                ...data.entries.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('${e.key}: ${e.value}',
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StackInfoRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const items = [
      (icon: '🎯', label: 'Flutter Web'),
      (icon: '🎯', label: 'Dart + Shelf'),
      (icon: '🐘', label: 'PostgreSQL'),
      (icon: '🔄', label: 'Riverpod'),
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: items
          .map((item) => Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
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
              ))
          .toList(),
    );
  }
}
