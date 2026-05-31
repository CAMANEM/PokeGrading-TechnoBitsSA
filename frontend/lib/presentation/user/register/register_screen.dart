/*
 Register screen and UI widgets for the user registration flow.

 This file contains the complete registration UI used by the frontend:
 - `RegisterScreen` (entrypoint) builds the two-column layout for wide
   viewports and a stacked layout for small screens.
 - Several small private widgets drive the step-by-step UX and display
   server-driven previews (pending token delivery) and success messages.
*/
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import 'register_api.dart';
import 'register_provider.dart';
import 'register_state.dart';

const supportedCountries = {
  'CR': 'Costa Rica',
  'PA': 'Panamá',
  'MX': 'México',
  'CO': 'Colombia',
  'CL': 'Chile',
  'AR': 'Argentina',
};

const supportedLanguages = {
  'es': 'Español',
  'en': 'English',
};

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  late final RegisterProvider _provider;

  final _registrationFormKey = GlobalKey<FormState>();
  final _confirmationFormKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _tokenController = TextEditingController();

  String? _selectedCountry;
  String? _selectedLanguage = "es";
  bool _acceptedDisclosure = false;

  @override
  void initState() {
    super.initState();
    _provider = RegisterProvider(RegisterApi());
  }

  @override
  void dispose() {
    _provider.dispose();
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _provider,
      builder: (context, _) {
        final authState = _provider.state;

        return Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.backgroundDark, AppColors.surfaceDark2],
              ),
            ),
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 920),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _Header(onBack: () => context.go('/')),
                        const SizedBox(height: 24),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isWide = constraints.maxWidth >= 860;
                            final introPanel = _IntroPanel(
                              pending: authState.pendingRegistration,
                              confirmedUser: authState.confirmedUser,
                            );
                            final formPanel = _FormPanel(
                              authState: authState,
                              registrationFormKey: _registrationFormKey,
                              confirmationFormKey: _confirmationFormKey,
                              emailController: _emailController,
                              usernameController: _usernameController,
                              passwordController: _passwordController,
                              tokenController: _tokenController,
                              selectedCountry: _selectedCountry,
                              selectedLanguage: _selectedLanguage,
                              acceptedDisclosure: _acceptedDisclosure,
                              onCountryChanged: (value) {
                                setState(() {
                                  _selectedCountry = value;
                                });
                              },
                              onLanguageChanged: (value) {
                                setState(() {
                                  _selectedLanguage = value;
                                });
                              },
                              onDisclosureChanged: (value) {
                                setState(() {
                                  _acceptedDisclosure = value ?? false;
                                });
                              },
                              onRegister: () async {
                                if (_registrationFormKey.currentState?.validate() != true) {
                                  return;
                                }

                                await _provider.register(
                                  email: _emailController.text,
                                  username: _usernameController.text,
                                  password: _passwordController.text,
                                  country: _selectedCountry!,
                                  language: _selectedLanguage!,
                                  acceptedDisclosure: _acceptedDisclosure,
                                );
                              },
                              onConfirm: () async {
                                if (_confirmationFormKey.currentState?.validate() != true) {
                                  return;
                                }

                                await _provider.confirm(
                                  token: _tokenController.text,
                                );
                              },
                              onReset: () {
                                _registrationFormKey.currentState?.reset();
                                _confirmationFormKey.currentState?.reset();
                                _emailController.clear();
                                _usernameController.clear();
                                _passwordController.clear();
                                _tokenController.clear();
                                _provider.reset();
                              },
                            );

                            if (isWide) {
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: introPanel),
                                  const SizedBox(width: 24),
                                  Expanded(child: formPanel),
                                ],
                              );
                            }

                            return Column(
                              children: [
                                introPanel,
                                const SizedBox(height: 24),
                                formPanel,
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  final VoidCallback onBack;

  const _Header({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Registro de usuario',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'Flujo de alta asistida con envío real de token por correo.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ],
        ),
        OutlinedButton.icon(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded),
          label: const Text('Volver'),
        ),
      ],
    );
  }
}

class _IntroPanel extends StatelessWidget {
  final PendingRegistrationData? pending;
  final ConfirmedUserData? confirmedUser;

  const _IntroPanel({required this.pending, required this.confirmedUser});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.verified_user_rounded, color: AppColors.accent, size: 34),
          const SizedBox(height: 18),
          Text(
            'Registro escalonado',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppColors.textPrimary,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            'Primero validamos que el email y el username no existan. Luego enviamos un token real al correo registrado para confirmar la cuenta antes de crear el usuario definitivamente.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.6,
                ),
          ),
          const SizedBox(height: 24),
          _FlowCard(
            title: '1. Captura',
            subtitle: 'Email, username y password',
            active: pending == null,
          ),
          const SizedBox(height: 12),
          _FlowCard(
            title: '2. Confirmación',
            subtitle: pending == null
                ? 'Token pendiente de envío'
                : 'Revisa la bandeja de entrada del correo registrado',
            active: pending != null && confirmedUser == null,
          ),
          const SizedBox(height: 12),
          _FlowCard(
            title: '3. Alta final',
            subtitle: confirmedUser != null
                ? 'Usuario ${confirmedUser!.username} registrado'
                : 'Persistencia en memoria',
            active: confirmedUser != null,
          ),
          const SizedBox(height: 24),
          if (pending != null) _DeliveryPreview(email: pending!.email, expiresAt: pending!.expiresAt),
          if (confirmedUser != null) ...[
            const SizedBox(height: 16),
            _SuccessBox(user: confirmedUser!),
          ],
        ],
      ),
    );
  }
}

class _FlowCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool active;

  const _FlowCard({
    required this.title,
    required this.subtitle,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: active ? AppColors.surfaceDark2 : AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: active ? AppColors.accent.withOpacity(0.5) : AppColors.borderDark,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: active ? AppColors.accent : AppColors.primary.withOpacity(0.25),
              shape: BoxShape.circle,
            ),
            child: Icon(
              active ? Icons.check_rounded : Icons.radio_button_unchecked_rounded,
              color: active ? AppColors.textOnDark : AppColors.primaryLight,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DeliveryPreview extends StatelessWidget {
  final String email;
  final DateTime expiresAt;

  const _DeliveryPreview({required this.email, required this.expiresAt});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Token enviado por correo', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text('Enviado a: $email', style: const TextStyle(color: AppColors.accent, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Expira: ${expiresAt.toLocal()}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }
}

class _SuccessBox extends StatelessWidget {
  final ConfirmedUserData user;

  const _SuccessBox({required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.success.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.success.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Cuenta activa', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text('${user.username} <${user.email}>', style: const TextStyle(color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}

class _FormPanel extends StatelessWidget {
  final RegisterState authState;
  final GlobalKey<FormState> registrationFormKey;
  final GlobalKey<FormState> confirmationFormKey;
  final TextEditingController emailController;
  final TextEditingController usernameController;
  final TextEditingController passwordController;
  final TextEditingController tokenController;
  final String? selectedCountry;
  final String? selectedLanguage;
  final bool acceptedDisclosure;
  final ValueChanged<String?> onCountryChanged;
  final ValueChanged<String?> onLanguageChanged;
  final ValueChanged<bool?> onDisclosureChanged;
  final Future<void> Function() onRegister;
  final Future<void> Function() onConfirm;
  final VoidCallback onReset;

  const _FormPanel({
    required this.authState,
    required this.registrationFormKey,
    required this.confirmationFormKey,
    required this.emailController,
    required this.usernameController,
    required this.passwordController,
    required this.tokenController,
    required this.selectedCountry,
    required this.selectedLanguage,
    required this.acceptedDisclosure,
    required this.onCountryChanged,
    required this.onLanguageChanged,
    required this.onDisclosureChanged,
    required this.onRegister,
    required this.onConfirm,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final isBusy = authState.stage == RegisterStage.submitting || authState.stage == RegisterStage.confirming;
    final pending = authState.pendingRegistration;

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            pending == null ? 'Datos de registro' : 'Confirmar token',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: 12),
          Text(
            pending == null
                ? 'Completa el formulario para recibir el token por correo.'
                : 'Usa el token mostrado en el panel lateral para terminar el registro.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          if (authState.message != null) ...[
            _MessageBanner(message: authState.message!, success: authState.stage == RegisterStage.success),
            const SizedBox(height: 18),
          ],
          if (pending == null) ...[
            Form(
              key: registrationFormKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      hintText: 'usuario@correo.com',
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      final text = (value ?? '').trim();
                      if (text.isEmpty) return 'El email es obligatorio';
                      if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text)) return 'Ingresa un email válido';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: usernameController,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      hintText: 'ash_ketchum',
                    ),
                    validator: (value) {
                      final text = (value ?? '').trim();
                      if (text.isEmpty) return 'El username es obligatorio';
                      if (text.length < 3) return 'Debe tener al menos 3 caracteres';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      hintText: 'Mínimo 8 caracteres',
                    ),
                    validator: (value) {
                      final text = value ?? '';
                      if (text.isEmpty) return 'La contraseña es obligatoria';
                      if (text.length < 8) return 'Debe tener al menos 8 caracteres';
                      if (!RegExp(r'[A-Z]').hasMatch(text)) return "Debe contener una mayúscula";
                      if (!RegExp(r'\d').hasMatch(text)) return "Debe contener un dígito";
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    value: selectedCountry,
                    decoration: const InputDecoration(
                      labelText: 'País de residencia',
                    ),
                    items: supportedCountries.entries
                        .map(
                          (entry) => DropdownMenuItem<String>(
                            value: entry.key,
                            child: Text(entry.value),
                          ),
                        )
                        .toList(),
                    onChanged: onCountryChanged,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Selecciona un país';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 14),

                  DropdownButtonFormField<String>(
                    value: selectedLanguage,
                    decoration: const InputDecoration(
                      labelText: 'Idioma',
                    ),
                    items: supportedLanguages.entries
                        .map(
                          (entry) => DropdownMenuItem(
                            value: entry.key,
                            child: Text(entry.value),
                          ),
                        )
                        .toList(),
                    onChanged: onLanguageChanged,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Selecciona un idioma';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 18),
                  CheckboxListTile(
                    value: acceptedDisclosure,
                    onChanged: onDisclosureChanged,
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Acepto que PokéGrading es únicamente informativo y no sustituye evaluaciones oficiales de PSA, BGS ni CGC.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: isBusy ? null : () async {
                if (!acceptedDisclosure) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Debes aceptar el disclosure para continuar")
                    )
                  );
                  return;
                }
                
                await onRegister();
              },
              icon: isBusy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send_rounded),
              label: const Text('Enviar registro'),
            ),
          ] else ...[
            Form(
              key: confirmationFormKey,
              child: TextFormField(
                controller: tokenController,
                decoration: const InputDecoration(
                  labelText: 'Token de confirmación',
                  hintText: '000000',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) {
                    return 'El token es obligatorio';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: isBusy ? null : () async => onConfirm(),
              icon: isBusy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.verified_rounded),
              label: const Text('Confirmar cuenta'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: isBusy ? null : onReset,
              child: const Text('Empezar de nuevo'),
            ),
          ],
          if (authState.stage == RegisterStage.error) ...[
            const SizedBox(height: 14),
            const Text(
              'Revisa el mensaje anterior y corrige los datos antes de continuar.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

class _MessageBanner extends StatelessWidget {
  final String message;
  final bool success;

  const _MessageBanner({required this.message, required this.success});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: success ? AppColors.success.withOpacity(0.15) : AppColors.error.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: success ? AppColors.success.withOpacity(0.35) : AppColors.error.withOpacity(0.35),
        ),
      ),
      child: Row(
        children: [
          Icon(success ? Icons.check_circle_rounded : Icons.error_outline_rounded,
              color: success ? AppColors.success : AppColors.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}