import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../application/catalog_provider.dart';
import '../domain/catalog_models.dart';

class AddCardScreen extends ConsumerStatefulWidget {
  const AddCardScreen({super.key});

  @override
  ConsumerState<AddCardScreen> createState() => _AddCardScreenState();
}

class _AddCardScreenState extends ConsumerState<AddCardScreen> {
  final _identityFormKey = GlobalKey<FormState>();
  final _displayFormKey = GlobalKey<FormState>();
  final _imageFormKey = GlobalKey<FormState>();

  final _setController = TextEditingController();
  final _numberController = TextEditingController();
  final _editionController = TextEditingController();
  final _languageController = TextEditingController();
  final _finishController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _imageDataController = TextEditingController();

  @override
  void dispose() {
    _setController.dispose();
    _numberController.dispose();
    _editionController.dispose();
    _languageController.dispose();
    _finishController.dispose();
    _displayNameController.dispose();
    _imageDataController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(catalogSubmissionControllerProvider);
    final controller = ref.read(catalogSubmissionControllerProvider.notifier);
    final busy = state.stage == CatalogFlowStage.submitting;

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
                    _FlowProgress(stage: state.stage),
                    const SizedBox(height: 16),
                    if (state.message != null) _MessageBanner(message: state.message!),
                    const SizedBox(height: 16),
                    _buildStepCard(
                      state: state,
                      busy: busy,
                      onSubmitIdentity: () {
                        if (_identityFormKey.currentState?.validate() != true) {
                          return;
                        }

                        controller.submitIdentity(
                          CardIdentityInput(
                            set: _setController.text,
                            number: _numberController.text,
                            edition: _editionController.text,
                            language: _languageController.text,
                            finish: _finishController.text,
                          ),
                        );
                      },
                      onSkipDisplay: controller.skipDisplay,
                      onSubmitDisplay: () {
                        if (_displayFormKey.currentState?.validate() != true) {
                          return;
                        }
                        controller.submitDisplay(_displayNameController.text);
                      },
                      onSubmitImage: () async {
                        if (_imageFormKey.currentState?.validate() != true) {
                          return;
                        }
                        await controller.submitImage(_imageDataController.text);
                      },
                      onReset: () {
                        _identityFormKey.currentState?.reset();
                        _displayFormKey.currentState?.reset();
                        _imageFormKey.currentState?.reset();
                        _setController.clear();
                        _numberController.clear();
                        _editionController.clear();
                        _languageController.clear();
                        _finishController.clear();
                        _displayNameController.clear();
                        _imageDataController.clear();
                        controller.reset();
                      },
                      onRetryImage: controller.retryFromImage,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepCard({
    required CatalogSubmissionState state,
    required bool busy,
    required VoidCallback onSubmitIdentity,
    required VoidCallback onSkipDisplay,
    required VoidCallback onSubmitDisplay,
    required Future<void> Function() onSubmitImage,
    required VoidCallback onReset,
    required VoidCallback onRetryImage,
  }) {
    switch (state.stage) {
      case CatalogFlowStage.identity:
        return _IdentityForm(
          formKey: _identityFormKey,
          setController: _setController,
          numberController: _numberController,
          editionController: _editionController,
          languageController: _languageController,
          finishController: _finishController,
          onSubmit: onSubmitIdentity,
        );
      case CatalogFlowStage.display:
        return _DisplayForm(
          formKey: _displayFormKey,
          displayNameController: _displayNameController,
          onSkip: onSkipDisplay,
          onSubmit: onSubmitDisplay,
        );
      case CatalogFlowStage.image:
      case CatalogFlowStage.error:
      case CatalogFlowStage.submitting:
        return _ImageForm(
          formKey: _imageFormKey,
          imageDataController: _imageDataController,
          busy: busy,
          onRetry: onRetryImage,
          onSubmit: onSubmitImage,
          isError: state.stage == CatalogFlowStage.error,
        );
      case CatalogFlowStage.success:
        return _SuccessCard(result: state.result!, onReset: onReset);
    }
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
              'Agregar carta al catalogo',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'CBS-2.1.1: identidad, display opcional e imagen.',
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

class _FlowProgress extends StatelessWidget {
  final CatalogFlowStage stage;

  const _FlowProgress({required this.stage});

  @override
  Widget build(BuildContext context) {
    final step = switch (stage) {
      CatalogFlowStage.identity => 1,
      CatalogFlowStage.display => 2,
      CatalogFlowStage.image => 3,
      CatalogFlowStage.submitting => 3,
      CatalogFlowStage.error => 3,
      CatalogFlowStage.success => 4,
    };

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Row(
        children: [
          Expanded(child: _StepBadge(label: '1. Identidad', active: step >= 1)),
          const SizedBox(width: 12),
          Expanded(child: _StepBadge(label: '2. Display', active: step >= 2)),
          const SizedBox(width: 12),
          Expanded(child: _StepBadge(label: '3. Imagen', active: step >= 3)),
          const SizedBox(width: 12),
          Expanded(child: _StepBadge(label: '4. card_id', active: step >= 4)),
        ],
      ),
    );
  }
}

class _StepBadge extends StatelessWidget {
  final String label;
  final bool active;

  const _StepBadge({required this.label, required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: active ? AppColors.accent.withOpacity(0.2) : AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: active ? AppColors.accent : AppColors.borderDark,
        ),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: active ? AppColors.textPrimary : AppColors.textSecondary,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _MessageBanner extends StatelessWidget {
  final String message;

  const _MessageBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    final isError = message.contains('rechazada') || message.contains('obligatorio');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: (isError ? AppColors.error : AppColors.success).withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (isError ? AppColors.error : AppColors.success).withOpacity(0.35),
        ),
      ),
      child: Text(
        message,
        style: TextStyle(
          color: isError ? AppColors.error : AppColors.success,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _IdentityForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController setController;
  final TextEditingController numberController;
  final TextEditingController editionController;
  final TextEditingController languageController;
  final TextEditingController finishController;
  final VoidCallback onSubmit;

  const _IdentityForm({
    required this.formKey,
    required this.setController,
    required this.numberController,
    required this.editionController,
    required this.languageController,
    required this.finishController,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return _FormCard(
      title: 'Formulario de Identidad de Carta',
      child: Form(
        key: formKey,
        child: Column(
          children: [
            _InputField(
              controller: setController,
              label: 'Set',
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'El set es obligatorio';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            _InputField(
              controller: numberController,
              label: 'Numero',
              keyboardType: TextInputType.number,
              validator: (value) {
                final text = value?.trim() ?? '';
                if (text.isEmpty) {
                  return 'El numero es obligatorio';
                }
                if (!RegExp(r'^[0-9]{1,6}$').hasMatch(text)) {
                  return 'Solo numeros, hasta 6 digitos';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            _InputField(
              controller: editionController,
              label: 'Edicion',
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'La edicion es obligatoria';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            _InputField(
              controller: languageController,
              label: 'Idioma',
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'El idioma es obligatorio';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            _InputField(
              controller: finishController,
              label: 'Acabado',
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'El acabado es obligatorio';
                }
                return null;
              },
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onSubmit,
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text('Continuar a display'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DisplayForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController displayNameController;
  final VoidCallback onSkip;
  final VoidCallback onSubmit;

  const _DisplayForm({
    required this.formKey,
    required this.displayNameController,
    required this.onSkip,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return _FormCard(
      title: 'Formulario de Display de Carta (opcional)',
      child: Form(
        key: formKey,
        child: Column(
          children: [
            _InputField(
              controller: displayNameController,
              label: 'Display name',
              validator: (value) {
                if ((value ?? '').trim().length > 60) {
                  return 'Maximo 60 caracteres';
                }
                return null;
              },
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onSkip,
                    icon: const Icon(Icons.skip_next_rounded),
                    label: const Text('No agregar display'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onSubmit,
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Agregar display'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ImageForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController imageDataController;
  final bool busy;
  final bool isError;
  final VoidCallback onRetry;
  final Future<void> Function() onSubmit;

  const _ImageForm({
    required this.formKey,
    required this.imageDataController,
    required this.busy,
    required this.onRetry,
    required this.onSubmit,
    required this.isError,
  });

  @override
  Widget build(BuildContext context) {
    return _FormCard(
      title: 'Formulario de Imagen de Carta',
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Simulacion: pega un string largo (base64/mock). Si contiene REJECT o es muy corto, la imagen se rechaza.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            _InputField(
              controller: imageDataController,
              label: 'image_data',
              minLines: 4,
              maxLines: 6,
              validator: (value) {
                final text = value?.trim() ?? '';
                if (text.isEmpty) {
                  return 'La imagen es obligatoria';
                }
                return null;
              },
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                if (isError)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: busy ? null : onRetry,
                      icon: const Icon(Icons.restart_alt_rounded),
                      label: const Text('Reintentar imagen'),
                    ),
                  ),
                if (isError) const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: busy ? null : onSubmit,
                    icon: busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.upload_rounded),
                    label: Text(busy ? 'Validando...' : 'Subir imagen y agregar carta'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SuccessCard extends StatelessWidget {
  final AddCardResult result;
  final VoidCallback onReset;

  const _SuccessCard({required this.result, required this.onReset});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.success.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: AppColors.success, size: 28),
              SizedBox(width: 10),
              Text(
                'Carta registrada',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _ResultRow(label: 'card_id', value: result.cardId),
          const SizedBox(height: 8),
          _ResultRow(label: 'estado', value: result.cardStatus),
          const SizedBox(height: 8),
          _ResultRow(label: 'creada', value: result.createdAt.toLocal().toString()),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onReset,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Agregar otra carta'),
          ),
        ],
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  final String label;
  final String value;

  const _ResultRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(
            '$label:',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _FormCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _FormCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.textPrimary,
                ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? Function(String?) validator;
  final TextInputType? keyboardType;
  final int minLines;
  final int maxLines;

  const _InputField({
    required this.controller,
    required this.label,
    required this.validator,
    this.keyboardType,
    this.minLines = 1,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      minLines: minLines,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: AppColors.surfaceDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
