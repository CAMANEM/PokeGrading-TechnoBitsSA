/// @file
/// @brief Pre-process card screen.

import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'pre_process_card_api.dart';
import 'pre_process_card_provider.dart';
import 'pre_process_card_state.dart';

import '../../../core/theme/app_theme.dart';
import '../../navigation_history.dart';

_PreProcessCardDraft? _preProcessCardDraft;

/// @brief _PreProcessCardDraft
class _PreProcessCardDraft {
  final String? frontImageData;
  final String? frontImageName;
  final String? backImageData;
  final String? backImageName;

  const _PreProcessCardDraft({
    this.frontImageData,
    this.frontImageName,
    this.backImageData,
    this.backImageName,
  });
}

/// @brief PreProcessCardScreen
class PreProcessCardScreen extends StatefulWidget {
  final String? initialImageData;

  const PreProcessCardScreen({super.key, this.initialImageData});

  @override
  State<PreProcessCardScreen> createState() => _PreProcessCardScreenState();
}

/// @brief _PreProcessCardScreenState
class _PreProcessCardScreenState extends State<PreProcessCardScreen> {
  late final PreProcessCardProvider _provider;

  String? _frontImageData;
  String? _frontImageName;
  String? _backImageData;
  String? _backImageName;

  String? _cardId;
  String? _cardName;
  bool _initialImageProcessed = false;

  @override
  void initState() {
    super.initState();
    _provider = PreProcessCardProvider(PreProcessCardApi());
    _restoreDraft();

    if (widget.initialImageData != null && _frontImageData == null) {
      _frontImageData = widget.initialImageData;
      _frontImageName = 'imagen_busqueda.png';
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final params = GoRouterState.of(context).uri.queryParameters;
    _cardId ??= params['card_id'];
    _cardName ??= params['card_name'];

    if (!_initialImageProcessed &&
        widget.initialImageData != null &&
        _frontImageData != null &&
        _provider.state.stage == PreProcessCardStage.initial) {
      _initialImageProcessed = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _submitFrontPreprocess();
      });
    }
  }

  @override
  void dispose() {
    _provider.dispose();
    super.dispose();
  }

  void _restoreDraft() {
    final draft = _preProcessCardDraft;
    if (draft == null) return;

    _frontImageData = draft.frontImageData;
    _frontImageName = draft.frontImageName;
    _backImageData = draft.backImageData;
    _backImageName = draft.backImageName;
  }

  void _saveDraft() {
    _preProcessCardDraft = _PreProcessCardDraft(
      frontImageData: _frontImageData,
      frontImageName: _frontImageName,
      backImageData: _backImageData,
      backImageName: _backImageName,
    );
  }

  Future<void> _submitFrontPreprocess() async {
    if (_frontImageData == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes cargar una imagen')),
      );
      return;
    }
    _saveDraft();
    await _provider.preprocessFront(_frontImageData!);
  }

  Future<void> _submitBackPreprocess() async {
    if (_backImageData == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes cargar la imagen del reverso')),
      );
      return;
    }
    _saveDraft();
    await _provider.preprocessBack(_backImageData!);
  }

  void _navigateToEvaluation() {
    _preProcessCardDraft = null;
    final encodedCardName = Uri.encodeComponent(_cardName ?? '');
    final frontBase64 = _provider.state.frontResult!.correctedImage;
    final backBase64 = _provider.state.backResult?.correctedImage;
    context.go(
      '/evaluations/submit?card_id=$_cardId&card_name=$encodedCardName',
      extra: {
        'frontImageData': frontBase64.startsWith('data:')
            ? frontBase64
            : 'data:image/jpeg;base64,$frontBase64',
        'backImageData': backBase64 != null
            ? (backBase64.startsWith('data:')
                ? backBase64
                : 'data:image/jpeg;base64,$backBase64')
            : null,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _provider,
      builder: (context, _) {
        final state = _provider.state;
        final busy = state.stage == PreProcessCardStage.preprocessing ||
            state.stage == PreProcessCardStage.preprocessingBack;

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
                            _provider.reset();
                            _preProcessCardDraft = null;
                            goBackOrHome(context);
                          },
                          cardName: _cardName,
                          state: state,
                        ),
                        const SizedBox(height: 24),
                        if (state.message != null)
                          _MessageBanner(
                            message: state.message!,
                            isError: state.stage == PreProcessCardStage.error,
                          ),
                        const SizedBox(height: 16),
                        _buildContent(state: state, busy: busy),
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

  Widget _buildContent({
    required PreProcessCardState state,
    required bool busy,
  }) {
    switch (state.stage) {
      case PreProcessCardStage.initial:
      case PreProcessCardStage.error:
        return _CaptureForm(
          label: 'Imagen frontal',
          selectedImageName: _frontImageName,
          busy: busy,
          isError: state.stage == PreProcessCardStage.error,
          onPickImage: () => _pickFrontImage(),
          onSubmit: _submitFrontPreprocess,
          onRetry: _submitFrontPreprocess,
        );

      case PreProcessCardStage.preprocessing:
        return const _ProcessingIndicator(
          message: 'Pre-procesando imagen frontal...',
        );

      case PreProcessCardStage.frontSuccess:
        return _FrontSuccessAndBackCapture(
          frontResult: state.frontResult!,
          backImageName: _backImageName,
          busy: busy,
          onPickBackImage: _pickBackImage,
          onSubmitBack: _submitBackPreprocess,
          onBackToSearch: () {
            _provider.reset();
            _preProcessCardDraft = null;
            context.go('/catalog/search');
          },
        );

      case PreProcessCardStage.preprocessingBack:
        return _FrontAndBackProcessing(
          frontResult: state.frontResult!,
        );

      case PreProcessCardStage.backSuccess:
        return _BothResults(
          frontResult: state.frontResult!,
          backResult: state.backResult!,
          cardId: _cardId,
          onContinue: _navigateToEvaluation,
          onBackToSearch: () {
            _provider.reset();
            _preProcessCardDraft = null;
            context.go('/catalog/search');
          },
        );
    }
  }

  Future<void> _pickFrontImage() async {
    final picked = await _pickImageFile();
    if (picked != null) {
      setState(() {
        _frontImageData = picked.$1;
        _frontImageName = picked.$2;
      });
    }
  }

  Future<void> _pickBackImage() async {
    final picked = await _pickImageFile();
    if (picked != null) {
      setState(() {
        _backImageData = picked.$1;
        _backImageName = picked.$2;
      });
    }
  }

  Future<(String, String)?> _pickImageFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg', 'heic'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return null;

    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) return null;

    final extension = (file.extension ?? '').toLowerCase();
    final mimeSubtype = switch (extension) {
      'png' => 'png',
      'jpg' => 'jpeg',
      'jpeg' => 'jpeg',
      'heic' => 'heic',
      _ => '',
    };

    if (mimeSubtype.isEmpty) return null;

    const maxBytes = 10 * 1024 * 1024;
    if (bytes.length > maxBytes) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Imagen excede 10MB')),
      );
      return null;
    }

    final encoded = base64Encode(bytes);
    final dataUri = 'data:image/$mimeSubtype;base64,$encoded';
    return (dataUri, file.name);
  }
}

/// @brief _Header
class _Header extends StatelessWidget {
  final VoidCallback onBack;
  final String? cardName;
  final PreProcessCardState state;

  const _Header({
    required this.onBack,
    required this.cardName,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pre-procesar carta',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                cardName != null ? 'Carta: $cardName' : 'Normalizar imagen',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
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

/// @brief _CaptureForm
class _CaptureForm extends StatelessWidget {
  final String label;
  final String? selectedImageName;
  final bool busy;
  final bool isError;
  final Future<void> Function() onPickImage;
  final Future<void> Function() onSubmit;
  final VoidCallback onRetry;

  const _CaptureForm({
    required this.label,
    required this.selectedImageName,
    required this.busy,
    required this.isError,
    required this.onPickImage,
    required this.onSubmit,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return _FormCard(
      title: 'Subir $label',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Selecciona una imagen PNG, JPG o HEIC.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: busy ? null : onPickImage,
              icon: const Icon(Icons.image_rounded),
              label: Text('Seleccionar $label'),
            ),
          ),
          if (selectedImageName != null) ...[
            const SizedBox(height: 10),
            Text(
              'Archivo: $selectedImageName',
              style: const TextStyle(
                color: AppColors.info,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              if (isError)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : onRetry,
                    icon: const Icon(Icons.restart_alt_rounded),
                    label: const Text('Reintentar'),
                  ),
                ),
              if (isError) const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: busy || selectedImageName == null
                      ? null
                      : onSubmit,
                  icon: busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_fix_high_rounded),
                  label: Text(busy ? 'Procesando...' : 'Pre-procesar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// @brief _ProcessingIndicator
class _ProcessingIndicator extends StatelessWidget {
  final String message;

  const _ProcessingIndicator({required this.message});

  @override
  Widget build(BuildContext context) {
    return _FormCard(
      title: 'Pre-procesando',
      child: Column(
        children: [
          const SizedBox(height: 24),
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// @brief _FrontSuccessAndBackCapture
class _FrontSuccessAndBackCapture extends StatelessWidget {
  final PreProcessCardResult frontResult;
  final String? backImageName;
  final bool busy;
  final Future<void> Function() onPickBackImage;
  final Future<void> Function() onSubmitBack;
  final VoidCallback onBackToSearch;

  const _FrontSuccessAndBackCapture({
    required this.frontResult,
    required this.backImageName,
    required this.busy,
    required this.onPickBackImage,
    required this.onSubmitBack,
    required this.onBackToSearch,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ResultCard(
          title: 'Imagen frontal normalizada',
          result: frontResult,
        ),
        const SizedBox(height: 16),
        _FormCard(
          title: 'Imagen del reverso',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Sube la imagen del reverso de la carta.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: busy ? null : onPickBackImage,
                  icon: const Icon(Icons.image_rounded),
                  label: const Text('Seleccionar reverso'),
                ),
              ),
              if (backImageName != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Archivo: $backImageName',
                  style: const TextStyle(
                    color: AppColors.info,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onBackToSearch,
                      icon: const Icon(Icons.search_rounded),
                      label: const Text('Buscar otra carta'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (backImageName != null)
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: busy ? null : onSubmitBack,
                        icon: busy
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.auto_fix_high_rounded),
                        label:
                            Text(busy ? 'Procesando...' : 'Pre-procesar reverso'),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// @brief _FrontAndBackProcessing
class _FrontAndBackProcessing extends StatelessWidget {
  final PreProcessCardResult frontResult;

  const _FrontAndBackProcessing({required this.frontResult});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ResultCard(
          title: 'Imagen frontal normalizada',
          result: frontResult,
        ),
        const SizedBox(height: 16),
        const _ProcessingIndicator(
          message: 'Pre-procesando imagen del reverso...',
        ),
      ],
    );
  }
}

/// @brief _BothResults
class _BothResults extends StatelessWidget {
  final PreProcessCardResult frontResult;
  final PreProcessCardResult backResult;
  final String? cardId;
  final VoidCallback onContinue;
  final VoidCallback onBackToSearch;

  const _BothResults({
    required this.frontResult,
    required this.backResult,
    required this.cardId,
    required this.onContinue,
    required this.onBackToSearch,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ResultCard(
          title: 'Imagen frontal normalizada',
          result: frontResult,
        ),
        const SizedBox(height: 16),
        _ResultCard(
          title: 'Imagen del reverso normalizada',
          result: backResult,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onBackToSearch,
                icon: const Icon(Icons.search_rounded),
                label: const Text('Buscar otra carta'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: cardId != null ? onContinue : null,
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text('Continuar a evaluacion'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// @brief _ResultCard
class _ResultCard extends StatelessWidget {
  final String title;
  final PreProcessCardResult result;

  const _ResultCard({required this.title, required this.result});

  @override
  Widget build(BuildContext context) {
    return _FormCard(
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(
              base64Decode(result.correctedImage.split(',').last),
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Container(
                height: 200,
                color: AppColors.surfaceDark2,
                child: const Center(
                  child: Text(
                    'Error al mostrar imagen',
                    style: TextStyle(color: AppColors.error),
                  ),
                ),
              ),
            ),
          ),
          if (result.metadata != null) ...[
            const SizedBox(height: 8),
            Text(
              'Deteccion: ${result.metadata!['detection_ms'] ?? 0}ms | '
              'Correccion: ${result.metadata!['correction_ms'] ?? 0}ms',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
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

/// @brief _MessageBanner
class _MessageBanner extends StatelessWidget {
  final String message;
  final bool isError;

  const _MessageBanner({required this.message, required this.isError});

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
