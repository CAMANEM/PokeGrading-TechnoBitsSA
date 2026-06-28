/// @file
/// @brief

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

/// @brief _SubmitEvaluationDraft
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

/// @brief SubmitEvaluationScreen
class SubmitEvaluationScreen extends StatefulWidget {
  const SubmitEvaluationScreen({super.key});

  @override
  State<SubmitEvaluationScreen> createState() => _SubmitEvaluationScreenState();
}

/// @brief _SubmitEvaluationScreenState
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
  String? _setName;
  String? _setFinish;
  bool _preprocessedImagesLoaded = false;

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
    _setName ??= GoRouterState.of(context).uri.queryParameters['set_name'];
    _setFinish ??= GoRouterState.of(context).uri.queryParameters['set_finish'];

    if (!_preprocessedImagesLoaded) {
      final extra = GoRouterState.of(context).extra;
      if (extra is Map<String, dynamic>) {
        _preprocessedImagesLoaded = true;
        final front = extra['frontImageData'] as String?;
        final back = extra['backImageData'] as String?;
        if (front != null && _selectedFrontImageData == null) {
          setState(() {
            _selectedFrontImageData = front;
            _selectedFrontImageName = 'frontal_preprocesada.png';
            _selectedFrontImageExtension = 'png';
          });
        }
        if (back != null && _selectedBackImageData == null) {
          setState(() {
            _selectedBackImageData = back;
            _selectedBackImageName = 'reverso_preprocesada.png';
            _selectedBackImageExtension = 'png';
          });
        }
      }
    }
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
                              setName: _setName,
                              setFinish: _setFinish,
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

/// @brief _FormCard
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

/// @brief _CaptureForm
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

/// @brief _MessageBanner
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

/// @brief _StepBadge
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

/// @brief _FlowProgress
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

/// @brief _SuccessCard
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
        border: Border.all(
          color: result.unableToGrade
              ? AppColors.warning.withOpacity(0.5)
              : result.needsReview
                  ? AppColors.info.withOpacity(0.5)
                  : AppColors.success.withOpacity(0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status header
          Row(
            children: [
              Icon(
                result.unableToGrade
                    ? Icons.warning_amber_rounded
                    : result.needsReview
                        ? Icons.info_outline
                        : Icons.check_circle_outline,
                color: result.unableToGrade
                    ? AppColors.warning
                    : result.needsReview
                        ? AppColors.info
                        : AppColors.success,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  result.unableToGrade
                      ? 'No se pudo evaluar'
                      : result.needsReview
                          ? 'En revisión humana'
                          : 'Evaluación completada',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Evaluation ID
          _InfoRow(label: 'ID de evaluación', value: result.evaluationId),
          _InfoRow(label: 'Estado', value: result.status),
          if (result.algorithmVersion != null)
            _InfoRow(
                label: 'Versión del algoritmo',
                value: result.algorithmVersion!),

          // Rejection reason (if unableToGrade)
          if (result.rejectionReason != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      color: AppColors.warning, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      result.rejectionReason!,
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Grading details (if available)
          if (result.hasGrading) ...[
            const SizedBox(height: 20),
            const Divider(color: AppColors.borderDark),
            const SizedBox(height: 12),

            // Final grade with uncertainty band
            Center(
              child: Column(
                children: [
                  Text(
                    'Grado Final',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    result.finalGrade?.toStringAsFixed(2) ?? '-',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 48,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (result.gradeLowerBound != null &&
                      result.gradeUpperBound != null)
                    Text(
                      'Rango: ${result.gradeLowerBound!.toStringAsFixed(1)} - ${result.gradeUpperBound!.toStringAsFixed(1)}',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Subgrades grid
            Row(
              children: [
                Expanded(
                    child: _SubgradeCard(
                        label: 'Centering',
                        grade: result.centeringGrade,
                        weight: '40%')),
                const SizedBox(width: 8),
                Expanded(
                    child: _SubgradeCard(
                        label: 'Esquinas',
                        grade: result.cornersGrade,
                        weight: '20%')),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                    child: _SubgradeCard(
                        label: 'Bordes',
                        grade: result.edgesGrade,
                        weight: '20%')),
                const SizedBox(width: 8),
                Expanded(
                    child: _SubgradeCard(
                        label: 'Superficie',
                        grade: result.surfaceGrade,
                        weight: '20%')),
              ],
            ),
            const SizedBox(height: 16),

            // Confidence + coherence
            _InfoRow(
              label: 'Confianza',
              value: result.confidence != null
                  ? '${(result.confidence! * 100).toStringAsFixed(0)}%'
                  : '-',
            ),
            if (result.coherenceApplied)
              _InfoRow(label: 'Regla de coherencia', value: 'Aplicada'),
            if (result.isCalibrated)
              _InfoRow(
                  label: 'Baseline',
                  value: 'Calibrado (${result.baselineVersion ?? ""})')
            else
              _InfoRow(
                  label: 'Baseline', value: result.baselineVersion ?? 'Global'),

            // Explanation
            if (result.explanation != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceDark2.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  result.explanation!,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ],

          const SizedBox(height: 24),
          Center(
            child: FilledButton(
              onPressed: onReset,
              child: const Text('Nueva evaluación'),
            ),
          ),
        ],
      ),
    );
  }
}

/// @brief _InfoRow
class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          Text(value,
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// @brief _SubgradeCard
class _SubgradeCard extends StatelessWidget {
  final String label;
  final double? grade;
  final String weight;

  const _SubgradeCard(
      {required this.label, required this.grade, required this.weight});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark2.withOpacity(0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Column(
        children: [
          Text(label,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            grade?.toStringAsFixed(2) ?? '-',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text('($weight)',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
        ],
      ),
    );
  }
}
