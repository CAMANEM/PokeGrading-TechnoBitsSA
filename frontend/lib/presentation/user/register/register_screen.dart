/*
 Register screen and UI widgets for the user registration flow.

 This file contains the registration UI used by the frontend.
*/
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../navigation_history.dart';
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

_RegisterDraft? _registerDraft;

/// @brief _RegisterDraft
class _RegisterDraft {
  final String email;
  final String username;
  final String password;
  final String? selectedCountry;
  final String? selectedLanguage;
  final bool acceptedDisclosure;

  const _RegisterDraft({
    required this.email,
    required this.username,
    required this.password,
    required this.selectedCountry,
    required this.selectedLanguage,
    required this.acceptedDisclosure,
  });
}

/// @brief RegisterScreen
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

/// @brief _RegisterScreenState
class _RegisterScreenState extends State<RegisterScreen> {
  late final RegisterProvider _provider;

  final _registrationFormKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  String? _selectedCountry;
  String? _selectedLanguage = 'es';
  bool _acceptedDisclosure = false;

  @override
  void initState() {
    super.initState();
    _provider = RegisterProvider(RegisterApi());
    _restoreDraft();
  }

  @override
  void dispose() {
    _provider.dispose();
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _restoreDraft() {
    final draft = _registerDraft;
    if (draft == null) {
      return;
    }

    _emailController.text = draft.email;
    _usernameController.text = draft.username;
    _passwordController.text = draft.password;
    _selectedCountry = draft.selectedCountry;
    _selectedLanguage = draft.selectedLanguage;
    _acceptedDisclosure = draft.acceptedDisclosure;
  }

  void _saveDraft() {
    _registerDraft = _RegisterDraft(
      email: _emailController.text,
      username: _usernameController.text,
      password: _passwordController.text,
      selectedCountry: _selectedCountry,
      selectedLanguage: _selectedLanguage,
      acceptedDisclosure: _acceptedDisclosure,
    );
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
                        _Header(
                          onBack: () {
                            _saveDraft();
                            goBackOrHome(context);
                          },
                        ),
                        const SizedBox(height: 24),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isWide = constraints.maxWidth >= 860;
                            final introPanel = _IntroPanel(
                              confirmedUser: authState.confirmedUser,
                            );
                            final formPanel = _FormPanel(
                              authState: authState,
                              registrationFormKey: _registrationFormKey,
                              emailController: _emailController,
                              usernameController: _usernameController,
                              passwordController: _passwordController,
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
                                if (_registrationFormKey.currentState
                                        ?.validate() !=
                                    true) {
                                  return;
                                }

                                await _provider.register(
                                  email: _emailController.text,
                                  username: _usernameController.text,
                                  password: _passwordController.text,
                                  country: _selectedCountry ?? '',
                                  language: _selectedLanguage ?? 'es',
                                  acceptedDisclosure: _acceptedDisclosure,
                                );
                              },
                              onReset: () {
                                _registerDraft = null;
                                _registrationFormKey.currentState?.reset();
                                _emailController.clear();
                                _usernameController.clear();
                                _passwordController.clear();
                                setState(() {
                                  _selectedCountry = null;
                                  _selectedLanguage = 'es';
                                  _acceptedDisclosure = false;
                                });
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

/// @brief _Header
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
              'Registro directo sin confirmación por correo.',
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

/// @brief _IntroPanel
class _IntroPanel extends StatelessWidget {
  final ConfirmedUserData? confirmedUser;

  const _IntroPanel({required this.confirmedUser});

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
          const Icon(Icons.verified_user_rounded,
              color: AppColors.accent, size: 34),
          const SizedBox(height: 18),
          Text(
            'Registro directo',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppColors.textPrimary,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            'El usuario se crea directamente sin enviar un correo de confirmación.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.6,
                ),
          ),
          const SizedBox(height: 24),
          _FlowCard(
            title: '1. Captura',
            subtitle: 'Email, username y password',
            active: confirmedUser == null,
          ),
          const SizedBox(height: 12),
          _FlowCard(
            title: '2. Alta final',
            subtitle: confirmedUser != null
                ? 'Usuario ${confirmedUser!.username} registrado'
                : 'Creación directa de cuenta',
            active: confirmedUser != null,
          ),
          const SizedBox(height: 24),
          if (confirmedUser != null) ...[
            const SizedBox(height: 16),
            _SuccessBox(user: confirmedUser!),
          ],
        ],
      ),
    );
  }
}

/// @brief _FlowCard
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
          color:
              active ? AppColors.accent.withOpacity(0.5) : AppColors.borderDark,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: active
                  ? AppColors.accent
                  : AppColors.primary.withOpacity(0.25),
              shape: BoxShape.circle,
            ),
            child: Icon(
              active
                  ? Icons.check_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: active ? AppColors.textOnDark : AppColors.primaryLight,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// @brief _SuccessBox
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
          const Text('Cuenta activa',
              style: TextStyle(
                  color: AppColors.success, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text('${user.username} <${user.email}>',
              style: const TextStyle(color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}

/// @brief _FormPanel
class _FormPanel extends StatelessWidget {
  final RegisterState authState;
  final GlobalKey<FormState> registrationFormKey;
  final TextEditingController emailController;
  final TextEditingController usernameController;
  final TextEditingController passwordController;
  final String? selectedCountry;
  final String? selectedLanguage;
  final bool acceptedDisclosure;
  final ValueChanged<String?> onCountryChanged;
  final ValueChanged<String?> onLanguageChanged;
  final ValueChanged<bool?> onDisclosureChanged;
  final Future<void> Function() onRegister;
  final VoidCallback onReset;

  const _FormPanel({
    required this.authState,
    required this.registrationFormKey,
    required this.emailController,
    required this.usernameController,
    required this.passwordController,
    required this.selectedCountry,
    required this.selectedLanguage,
    required this.acceptedDisclosure,
    required this.onCountryChanged,
    required this.onLanguageChanged,
    required this.onDisclosureChanged,
    required this.onRegister,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final isBusy = authState.stage == RegisterStage.submitting;

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
            'Datos de registro',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: 12),
          Text(
            'Completa el formulario para crear tu cuenta sin envío de correo de confirmación.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          if (authState.message != null) ...[
            _MessageBanner(
                message: authState.message!,
                success: authState.stage == RegisterStage.success),
            const SizedBox(height: 18),
          ],
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
                    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text)) {
                      return 'Ingresa un email válido';
                    }
                    final lower = text.toLowerCase();
                    if (!(lower.endsWith('.cr') || lower.endsWith('.com'))) {
                      return 'El email debe terminar en .cr o .com';
                    }
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
                    if (text.length < 3)
                      return 'Debe tener al menos 3 caracteres';
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
                    if (text.length < 8)
                      return 'Debe tener al menos 8 caracteres';
                    if (!RegExp(r'[A-Z]').hasMatch(text))
                      return 'Debe contener una mayúscula';
                    if (!RegExp(r'\d').hasMatch(text))
                      return 'Debe contener un dígito';
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
                        (entry) => DropdownMenuItem<String>(
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
            onPressed: isBusy
                ? null
                : () async {
                    if (!acceptedDisclosure) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Debes aceptar el disclosure para continuar'),
                        ),
                      );
                      return;
                    }
                    await onRegister();
                  },
            icon: isBusy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.send_rounded),
            label: const Text('Crear cuenta'),
          ),
          if (authState.stage == RegisterStage.success) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: onReset,
              child: const Text('Registrar otro usuario'),
            ),
          ],
        ],
      ),
    );
  }
}

/// @brief _MessageBanner
class _MessageBanner extends StatelessWidget {
  final String message;
  final bool success;

  const _MessageBanner({required this.message, required this.success});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: success
            ? AppColors.success.withOpacity(0.15)
            : AppColors.error.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: success
              ? AppColors.success.withOpacity(0.35)
              : AppColors.error.withOpacity(0.35),
        ),
      ),
      child: Row(
        children: [
          Icon(
              success
                  ? Icons.check_circle_rounded
                  : Icons.error_outline_rounded,
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
