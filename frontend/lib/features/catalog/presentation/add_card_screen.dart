import 'dart:convert';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
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

  final _setController = TextEditingController();
  final _numberController = TextEditingController();
  final _editionController = TextEditingController();
  final _languageController = TextEditingController();
  final _finishController = TextEditingController();
  // Display / recommended fields
  final _displayNameController = TextEditingController();
  final _hpController = TextEditingController();
  final _illustratorController = TextEditingController();
  final _yearController = TextEditingController();
  final _authorController = TextEditingController();
  String? _selectedLanguage;
  String? _selectedRarity;
  String? _selectedType;
  String? _selectedImageData;
  String? _selectedImageName;
  String? _selectedImageExtension;

  @override
  void dispose() {
    _setController.dispose();
    _numberController.dispose();
    _editionController.dispose();
    _languageController.dispose();
    _finishController.dispose();
    _displayNameController.dispose();
    _hpController.dispose();
    _illustratorController.dispose();
    _yearController.dispose();
    _authorController.dispose();
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
                    _Header(
                      onBack: () {
                        controller.reset();
                        context.go('/');
                      },
                    ),
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
                      onSubmitImage: () async {
                        if (_selectedImageData == null) {
                          setState(() {
                            _selectedImageName = null;
                          });
                          return;
                        }

                        final payload = AddCardPayload(
                          identity: CardIdentityInput(
                            set: _setController.text,
                            number: _numberController.text,
                            edition: _editionController.text,
                            language: _languageController.text,
                            finish: _finishController.text,
                          ),
                          displayName: _displayNameController.text.trim().isEmpty
                              ? null
                              : _displayNameController.text.trim(),
                          rarity: _selectedRarity,
                          pokemonType: _selectedType,
                          hp: int.tryParse(_hpController.text.trim()),
                          illustrator: _illustratorController.text.trim().isEmpty
                              ? null
                              : _illustratorController.text.trim(),
                          year: int.tryParse(_yearController.text.trim()),
                          author: _authorController.text.trim().isEmpty
                              ? null
                              : _authorController.text.trim(),
                          imageData: _selectedImageData!,
                        );

                        await controller.submitImagePayload(payload);
                      },
                      onReset: () {
                        _identityFormKey.currentState?.reset();
                        _setController.clear();
                        _numberController.clear();
                        _editionController.clear();
                        _languageController.clear();
                        _finishController.clear();
                        setState(() {
                          _selectedImageData = null;
                          _selectedImageName = null;
                          _selectedImageExtension = null;
                          _selectedLanguage = null;
                        });
                        controller.reset();
                      },
                      onRetryImage: controller.retryFromImage,
                      onPickImage: _pickImage,
                      selectedImageName: _selectedImageName,
                      selectedImageExtension: _selectedImageExtension,
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
    required Future<void> Function() onSubmitImage,
    required VoidCallback onReset,
    required VoidCallback onRetryImage,
    required Future<void> Function() onPickImage,
    required String? selectedImageName,
    required String? selectedImageExtension,
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
                          selectedLanguage: _selectedLanguage,
                          onLanguageChanged: (value) => setState(() {
                            _selectedLanguage = value;
                            _languageController.text = value ?? '';
                          }),
          displayNameController: _displayNameController,
          hpController: _hpController,
          illustratorController: _illustratorController,
          yearController: _yearController,
          authorController: _authorController,
          selectedRarity: _selectedRarity,
          selectedType: _selectedType,
          onRarityChanged: (v) => setState(() => _selectedRarity = v),
          onTypeChanged: (v) => setState(() => _selectedType = v),
          onSubmit: onSubmitIdentity,
        );
      case CatalogFlowStage.image:
      case CatalogFlowStage.error:
      case CatalogFlowStage.submitting:
        return _ImageForm(
          selectedImageName: selectedImageName,
          selectedImageExtension: selectedImageExtension,
          busy: busy,
          onRetry: onRetryImage,
          onPickImage: onPickImage,
          onSubmit: onSubmitImage,
          isError: state.stage == CatalogFlowStage.error,
        );
      case CatalogFlowStage.success:
        return _SuccessCard(result: state.result!, onReset: onReset);
    }
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      return;
    }

    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      return;
    }

    final extension = (file.extension ?? '').toLowerCase();
    final mimeSubtype = switch (extension) {
      'png' => 'png',
      'jpg' => 'jpeg',
      'jpeg' => 'jpeg',
      _ => '',
    };

    if (mimeSubtype.isEmpty) {
      return;
    }

    // Basic client-side validations: size and dimensions
    const minBytes = 5 * 1024; // 5KB minimal
    const maxBytes = 5 * 1024 * 1024; // 5MB max

    if (bytes.length < minBytes) {
      setState(() {
        _selectedImageName = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Imagen demasiado pequeña (min 5KB)')),
      );
      return;
    }

    if (bytes.length > maxBytes) {
      setState(() {
        _selectedImageName = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Imagen demasiado pesada (max 5MB)')),
      );
      return;
    }

    // Try to decode dimensions (works on Flutter platforms)
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final width = image.width;
      final height = image.height;

      const minWidth = 400;
      const minHeight = 400;
      if (width < minWidth || height < minHeight) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Resolución mínima 400x400 píxeles')),
        );
        return;
      }
    } catch (_) {
      // If decoding fails, fall back to size-only validation
    }

    final encoded = base64Encode(bytes);
    final dataUri = 'data:image/$mimeSubtype;base64,$encoded';

    setState(() {
      _selectedImageData = dataUri;
      _selectedImageName = file.name;
      _selectedImageExtension = extension;
    });
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
              'CBS-2.1.1: identidad e imagen PNG/JPG.',
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
      CatalogFlowStage.image => 2,
      CatalogFlowStage.submitting => 2,
      CatalogFlowStage.error => 2,
      CatalogFlowStage.success => 3,
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
          Expanded(child: _StepBadge(label: '2. Imagen', active: step >= 2)),
          const SizedBox(width: 12),
          Expanded(child: _StepBadge(label: '3. card_id', active: step >= 3)),
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
  final String? selectedLanguage;
  final void Function(String?) onLanguageChanged;
  final TextEditingController displayNameController;
  final TextEditingController hpController;
  final TextEditingController illustratorController;
  final TextEditingController yearController;
  final TextEditingController authorController;
  final String? selectedRarity;
  final String? selectedType;
  final void Function(String?) onRarityChanged;
  final void Function(String?) onTypeChanged;
  final VoidCallback onSubmit;

  const _IdentityForm({
    required this.formKey,
    required this.setController,
    required this.numberController,
    required this.editionController,
    required this.languageController,
    required this.finishController,
    required this.selectedLanguage,
    required this.onLanguageChanged,
    required this.displayNameController,
    required this.hpController,
    required this.illustratorController,
    required this.yearController,
    required this.authorController,
    required this.selectedRarity,
    required this.selectedType,
    required this.onRarityChanged,
    required this.onTypeChanged,
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
            DropdownButtonFormField<String>(
              value: selectedLanguage,
              decoration: const InputDecoration(labelText: 'Idioma'),
              items: const [
                DropdownMenuItem(value: 'Español', child: Text('Español')),
                DropdownMenuItem(value: 'Inglés', child: Text('Inglés')),
              ],
              onChanged: onLanguageChanged,
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
            const SizedBox(height: 12),
            _InputField(
              controller: displayNameController,
              label: 'Nombre (display)',
              validator: (value) {
                return null;
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: selectedRarity,
                    decoration: const InputDecoration(labelText: 'Rareza'),
                    items: [
                      'Common',
                      'Uncommon',
                      'Rare',
                      'Holo Rare',
                      'Ultra Rare',
                      'Secret Rare',
                    ].map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                    onChanged: onRarityChanged,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: selectedType,
                    decoration: const InputDecoration(labelText: 'Tipo'),
                    items: [
                      'Normal',
                      'Fighting',
                      'Fire',
                      'Water',
                      'Grass',
                      'Electric',
                      'Psychic',
                      'Dark',
                      'Metal',
                      'Dragon',
                      'Fairy',
                    ].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                    onChanged: onTypeChanged,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _InputField(
                    controller: hpController,
                    label: 'HP',
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return null;
                      if (int.tryParse(value.trim()) == null) return 'HP debe ser numérico';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _InputField(
                    controller: illustratorController,
                    label: 'Ilustrador',
                    validator: (value) => null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _InputField(
                    controller: yearController,
                    label: 'Año',
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return null;
                      final y = int.tryParse(value.trim());
                      if (y == null) return 'Año inválido';
                      if (y < 1950 || y > DateTime.now().year) return 'Año fuera de rango';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _InputField(
                    controller: authorController,
                    label: 'Autor (tu nombre)',
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'El autor es obligatorio mientras no haya auth';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onSubmit,
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text('Continuar a imagen'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImageForm extends StatelessWidget {
  final String? selectedImageName;
  final String? selectedImageExtension;
  final bool busy;
  final bool isError;
  final VoidCallback onRetry;
  final Future<void> Function() onPickImage;
  final Future<void> Function() onSubmit;

  const _ImageForm({
    required this.selectedImageName,
    required this.selectedImageExtension,
    required this.busy,
    required this.onRetry,
    required this.onPickImage,
    required this.onSubmit,
    required this.isError,
  });

  @override
  Widget build(BuildContext context) {
    return _FormCard(
      title: 'Formulario de Imagen de Carta',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Selecciona un archivo PNG o JPG.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: busy ? null : onPickImage,
              icon: const Icon(Icons.image_rounded),
              label: const Text('Seleccionar imagen PNG/JPG'),
            ),
          ),
          if (selectedImageName != null) ...[
            const SizedBox(height: 10),
            Text(
              'Archivo seleccionado: $selectedImageName (${selectedImageExtension ?? ''})',
              style: const TextStyle(
                color: AppColors.info,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
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
