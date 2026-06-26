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
  final String? imageData;
  final String? imageName;
  final String? imageExtension;

  const _PreProcessCardDraft({
    this.imageData,
    this.imageName,
    this.imageExtension,
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

  String? _selectedImageData;
  String? _selectedImageName;
  String? _selectedImageExtension;

  String? _cardId;
  String? _cardName;
  bool _initialImageProcessed = false;

  @override
  void initState() {
    super.initState();
    _provider = PreProcessCardProvider(PreProcessCardApi());
    _restoreDraft();

    if (widget.initialImageData != null && _selectedImageData == null) {
      _selectedImageData = widget.initialImageData;
      _selectedImageName = 'imagen_busqueda.png';
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
        _selectedImageData != null &&
        _provider.state.stage == PreProcessCardStage.initial) {
      _initialImageProcessed = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _submitPreprocess();
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

    _selectedImageData = draft.imageData;
    _selectedImageName = draft.imageName;
    _selectedImageExtension = draft.imageExtension;
  }

  void _saveDraft() {
    _preProcessCardDraft = _PreProcessCardDraft(
      imageData: _selectedImageData,
      imageName: _selectedImageName,
      imageExtension: _selectedImageExtension,
    );
  }

  Future<void> _submitPreprocess() async {
    if (_selectedImageData == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes cargar una imagen')),
      );
      return;
    }
    _saveDraft();
    await _provider.preprocessImage(
      PreProcessCardPayload(imageData: _selectedImageData!),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _provider,
      builder: (context, _) {
        final state = _provider.state;
        final busy = state.stage == PreProcessCardStage.preprocessing;

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
                        _buildContent(
                          state: state,
                          busy: busy,
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

  Widget _buildContent({
    required PreProcessCardState state,
    required bool busy,
  }) {
    switch (state.stage) {
      case PreProcessCardStage.initial:
      case PreProcessCardStage.error:
        return _CaptureForm(
          selectedImageName: _selectedImageName,
          selectedImageExtension: _selectedImageExtension,
          busy: busy,
          isError: state.stage == PreProcessCardStage.error,
          onPickImage: () => _pickImage(),
          onSubmit: _submitPreprocess,
          onRetry: _provider.retry,
        );
      case PreProcessCardStage.preprocessing:
        return const _ProcessingIndicator();
      case PreProcessCardStage.success:
        return _PreProcessResult(
          result: state.result!,
          cardId: _cardId,
          onContinue: () {
            _preProcessCardDraft = null;
            final encodedCardName = Uri.encodeComponent(_cardName ?? '');
            context.go(
              '/evaluations?card_id=$_cardId&card_name=$encodedCardName',
            );
          },
          onBackToSearch: () {
            _provider.reset();
            _preProcessCardDraft = null;
            context.go('/catalog/search');
          },
        );
    }
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg', 'heic'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) return;

    final extension = (file.extension ?? '').toLowerCase();
    final mimeSubtype = switch (extension) {
      'png' => 'png',
      'jpg' => 'jpeg',
      'jpeg' => 'jpeg',
      'heic' => 'heic',
      _ => '',
    };

    if (mimeSubtype.isEmpty) return;

    const maxBytes = 10 * 1024 * 1024;
    if (bytes.length > maxBytes) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Imagen excede 10MB')),
      );
      return;
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
  final String? selectedImageName;
  final String? selectedImageExtension;
  final bool busy;
  final bool isError;
  final Future<void> Function() onPickImage;
  final Future<void> Function() onSubmit;
  final VoidCallback onRetry;

  const _CaptureForm({
    required this.selectedImageName,
    required this.selectedImageExtension,
    required this.busy,
    required this.isError,
    required this.onPickImage,
    required this.onSubmit,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return _FormCard(
      title: 'Subir imagen de carta',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Selecciona una imagen PNG, JPG o HEIC de tu carta.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 8),
          const Text(
            'La imagen sera normalizada: correccion de perspectiva, '
            'balance de color y extraccion de regiones.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 16),
          const Text(
            'Imagen de la carta',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: busy ? null : onPickImage,
              icon: const Icon(Icons.image_rounded),
              label: const Text('Seleccionar imagen'),
            ),
          ),
          if (selectedImageName != null) ...[
            const SizedBox(height: 10),
            Text(
              'Archivo: $selectedImageName (${selectedImageExtension ?? ''})',
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
                  onPressed: busy ? null : onSubmit,
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
  const _ProcessingIndicator();

  @override
  Widget build(BuildContext context) {
    return _FormCard(
      title: 'Pre-procesando carta',
      child: const Column(
        children: [
          SizedBox(height: 24),
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(
            'Detectando contorno y corrigiendo perspectiva...',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          SizedBox(height: 8),
          Text(
            'Normalizando color y extrayendo regiones...',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// @brief _PreProcessResult
class _PreProcessResult extends StatelessWidget {
  final PreProcessCardResult result;
  final String? cardId;
  final VoidCallback onContinue;
  final VoidCallback onBackToSearch;

  const _PreProcessResult({
    required this.result,
    required this.cardId,
    required this.onContinue,
    required this.onBackToSearch,
  });

  @override
  Widget build(BuildContext context) {
    return _FormCard(
      title: 'Carta normalizada',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(
              base64Decode(result.correctedImage.split(',').last),
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Container(
                height: 300,
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
          const SizedBox(height: 16),
          if (result.metadata != null) ...[
            Text(
              'Deteccion: ${result.metadata!['detection_ms'] ?? 0}ms | '
              'Correccion: ${result.metadata!['correction_ms'] ?? 0}ms | '
              'Total: ${result.metadata!['total_ms'] ?? 0}ms',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
          ],
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
