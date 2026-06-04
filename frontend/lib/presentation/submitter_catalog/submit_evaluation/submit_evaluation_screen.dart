import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'submit_evaluation_api.dart';
import 'submit_evaluation_provider.dart';
import 'submit_evaluation_state.dart';

import '../../../core/theme/app_theme.dart';
import '../../navigation_history.dart';

_SubmitEvaluationDraft? _submitEvaluationDraft;

class _SubmitEvaluationDraft {
  final String? frontImageData;
  final String? frontImageName;
  final String? frontImageExtension;
  final String? backImageData;
  final String? backImageName;
  final String? backImageExtension;

  const _SubmitEvaluationDraft({
    this.frontImageData,
    this.frontImageName,
    this.frontImageExtension,
    this.backImageData,
    this.backImageName,
    this.backImageExtension,
  });
}

class SubmitEvaluationScreen extends StatefulWidget {
  const SubmitEvaluationScreen({super.key});

  @override
  State<SubmitEvaluationScreen> createState() => _SubmitEvaluationScreenState();
}

class _SubmitEvaluationScreenState extends State<SubmitEvaluationScreen> {
  late final SubmitEvaluationProvider _provider;

  // Front image
  String? _selectedFrontImageData;
  String? _selectedFrontImageName;
  String? _selectedFrontImageExtension;
  // Back image
  String? _selectedBackImageData;
  String? _selectedBackImageName;
  String? _selectedBackImageExtension;

  String? _cardId;

  @override
  void initState() {
    super.initState();
    _provider = SubmitEvaluationProvider(SubmitEvaluationApi());
    _restoreDraft();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _cardId ??= GoRouterState.of(context).uri.queryParameters['card_id'];
  }

  @override
  void dispose() {
    _provider.dispose();
    super.dispose();
  }

  void _restoreDraft() {
    final draft = _submitEvaluationDraft;
    if (draft == null) {
      return;
    }

    _selectedFrontImageData = draft.frontImageData;
    _selectedFrontImageName = draft.frontImageName;
    _selectedFrontImageExtension = draft.frontImageExtension;
    _selectedBackImageData = draft.backImageData;
    _selectedBackImageName = draft.backImageName;
    _selectedBackImageExtension = draft.backImageExtension;
  }

  void _saveDraft() {
    _submitEvaluationDraft = _SubmitEvaluationDraft(
      frontImageData: _selectedFrontImageData,
      frontImageName: _selectedFrontImageName,
      frontImageExtension: _selectedFrontImageExtension,
      backImageData: _selectedBackImageData,
      backImageName: _selectedBackImageName,
      backImageExtension: _selectedBackImageExtension,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _provider,
      builder: (context, _) {
        final state = _provider.state;
        final busy = state.stage == SubmitEvaluationStage.submitting;

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
                        _FlowProgress(stage: state.stage),
                        const SizedBox(height: 16),
                        if (state.message != null)
                          _MessageBanner(
                            message: state.message!,
                            isError: state.stage == SubmitEvaluationStage.error,
                          ),
                        const SizedBox(height: 16),
                        _buildStepCard(
                          state: state,
                          busy: busy,
                          onSubmit: () async {
                            if (_selectedFrontImageData == null ||
                                _selectedBackImageData == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'Debes cargar tanto la imagen frontal como la trasera')),
                              );
                              return;
                            }

                            final payload = SubmitEvaluationPayload(
                              frontImageData: _selectedFrontImageData!,
                              backImageData: _selectedBackImageData!,
                              cardId: _cardId,
                            );

                            await _provider.submit(payload);
                          },
                          onReset: () {
                            _submitEvaluationDraft = null;
                            setState(() {
                              _selectedFrontImageData = null;
                              _selectedFrontImageName = null;
                              _selectedFrontImageExtension = null;
                              _selectedBackImageData = null;
                              _selectedBackImageName = null;
                              _selectedBackImageExtension = null;
                            });
                            _provider.reset();
                          },
                          onRetry: _provider.retry,
                          onPickFrontImage: () => _pickImage(isBack: false),
                          onPickBackImage: () => _pickImage(isBack: true),
                          selectedFrontImageName: _selectedFrontImageName,
                          selectedFrontImageExtension:
                              _selectedFrontImageExtension,
                          selectedBackImageName: _selectedBackImageName,
                          selectedBackImageExtension:
                              _selectedBackImageExtension,
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

  Widget _buildStepCard({
    required SubmitEvaluationState state,
    required bool busy,
    required Future<void> Function() onSubmit,
    required VoidCallback onReset,
    required Future<void> Function() onRetry,
    required Future<void> Function() onPickFrontImage,
    required Future<void> Function() onPickBackImage,
    required String? selectedFrontImageName,
    required String? selectedFrontImageExtension,
    required String? selectedBackImageName,
    required String? selectedBackImageExtension,
  }) {
    switch (state.stage) {
      case SubmitEvaluationStage.capture:
      case SubmitEvaluationStage.error:
      case SubmitEvaluationStage.submitting:
      case SubmitEvaluationStage.validating:
        return _CaptureForm(
          selectedFrontImageName: selectedFrontImageName,
          selectedFrontImageExtension: selectedFrontImageExtension,
          selectedBackImageName: selectedBackImageName,
          selectedBackImageExtension: selectedBackImageExtension,
          busy: busy,
          onRetry: onRetry,
          onPickFrontImage: onPickFrontImage,
          onPickBackImage: onPickBackImage,
          onSubmit: onSubmit,
          isError: state.stage == SubmitEvaluationStage.error,
        );
      case SubmitEvaluationStage.success:
        return _SuccessCard(result: state.result!, onReset: onReset);
    }
  }

  Future<void> _pickImage({required bool isBack}) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg', 'heic'],
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
      'heic' => 'heic',
      _ => '',
    };

    if (mimeSubtype.isEmpty) {
      return;
    }

    // Basic client-side validations: size and dimensions
    const maxBytes = 10 * 1024 * 1024; // 10MB max

    if (bytes.length > maxBytes) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Imagen excede 10MB')),
      );
      return;
    }

    final encoded = base64Encode(bytes);
    final dataUri = 'data:image/$mimeSubtype;base64,$encoded';

    setState(() {
      if (isBack) {
        _selectedBackImageData = dataUri;
        _selectedBackImageName = file.name;
        _selectedBackImageExtension = extension;
      } else {
        _selectedFrontImageData = dataUri;
        _selectedFrontImageName = file.name;
        _selectedFrontImageExtension = extension;
      }
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
              'Enviar carta a evaluacion',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'Imagen PNG/JPG/HEIC.',
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

class _CaptureForm extends StatelessWidget {
  final String? selectedFrontImageName;
  final String? selectedFrontImageExtension;
  final String? selectedBackImageName;
  final String? selectedBackImageExtension;
  final bool busy;
  final bool isError;
  final Future<void> Function() onRetry;
  final Future<void> Function() onPickFrontImage;
  final Future<void> Function() onPickBackImage;
  final Future<void> Function() onSubmit;

  const _CaptureForm({
    required this.selectedFrontImageName,
    required this.selectedFrontImageExtension,
    required this.selectedBackImageName,
    required this.selectedBackImageExtension,
    required this.busy,
    required this.onRetry,
    required this.onPickFrontImage,
    required this.onPickBackImage,
    required this.onSubmit,
    required this.isError,
  });

  @override
  Widget build(BuildContext context) {
    return _FormCard(
      title: 'Subir Imagenes de Carta',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Selecciona archivos PNG, JPG o HEIC para el frente y la parte trasera. Ambas imágenes son obligatorias.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 16),
          // Front Image Section
          const Text(
            'Frente de la carta',
            style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 14),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: busy ? null : onPickFrontImage,
              icon: const Icon(Icons.image_rounded),
              label: const Text('Seleccionar imagen frontal'),
            ),
          ),
          if (selectedFrontImageName != null) ...[
            const SizedBox(height: 10),
            Text(
              'Archivo seleccionado: $selectedFrontImageName (${selectedFrontImageExtension ?? ''})',
              style: const TextStyle(
                color: AppColors.info,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 16),
          // Back Image Section
          const Text(
            'Parte trasera de la carta',
            style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 14),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: busy ? null : onPickBackImage,
              icon: const Icon(Icons.image_rounded),
              label: const Text('Seleccionar imagen trasera'),
            ),
          ),
          if (selectedBackImageName != null) ...[
            const SizedBox(height: 10),
            Text(
              'Archivo seleccionado: $selectedBackImageName (${selectedBackImageExtension ?? ''})',
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
                    onPressed: busy ? null : () => onRetry(),
                    icon: const Icon(Icons.restart_alt_rounded),
                    label: const Text('Reintentar envio'),
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
                  label:
                      Text(busy ? 'Validando...' : 'Enviar carta a evaluacion'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MessageBanner extends StatelessWidget {
  final String message;
  final bool isError;

  const _MessageBanner({
    required this.message,
    required this.isError,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:
            (isError ? AppColors.error : AppColors.success).withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              (isError ? AppColors.error : AppColors.success).withOpacity(0.35),
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

class _StepBadge extends StatelessWidget {
  final String label;
  final bool active;

  const _StepBadge({required this.label, required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color:
            active ? AppColors.accent.withOpacity(0.2) : AppColors.surfaceDark,
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

class _FlowProgress extends StatelessWidget {
  final SubmitEvaluationStage stage;

  const _FlowProgress({required this.stage});

  @override
  Widget build(BuildContext context) {
    final step = switch (stage) {
      SubmitEvaluationStage.capture => 1,
      SubmitEvaluationStage.validating => 2,
      SubmitEvaluationStage.submitting => 2,
      SubmitEvaluationStage.error => 2,
      SubmitEvaluationStage.success => 3,
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
          Expanded(child: _StepBadge(label: '1. Captura', active: step >= 1)),
          const SizedBox(width: 12),
          Expanded(
              child: _StepBadge(label: '2. Validacion', active: step >= 2)),
          const SizedBox(width: 12),
          Expanded(
              child: _StepBadge(label: '3. Confirmacion', active: step >= 3)),
        ],
      ),
    );
  }
}

class _SuccessCard extends StatelessWidget {
  final SubmitEvaluationResult result;
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
          Text(
            'ID de evaluación',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(result.evaluationId),
          SizedBox(height: 16),
          Text(
            'Estado',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(result.status),
        ],
      ),
    );
  }
}
