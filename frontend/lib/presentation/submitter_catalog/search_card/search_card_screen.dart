/// @file
/// @brief

import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'search_card_api.dart';
import 'search_card_provider.dart';
import 'search_card_state.dart';

import '../../../core/theme/app_theme.dart';

/// @brief SearchCardScreen
class SearchCardScreen extends StatefulWidget {
  const SearchCardScreen({super.key});

  @override
  State<SearchCardScreen> createState() => _SearchCardScreenState();
}

/// @brief _SearchCardScreenState
class _SearchCardScreenState extends State<SearchCardScreen> {
  late final SearchCardProvider _provider;

  // Image
  String? _selectedImageData;
  String? _selectedImageName;
  String? _selectedImageExtension;

  // Controllers for Manual Search
  final _setController = TextEditingController();
  final _numberController = TextEditingController();
  final _editionController = TextEditingController();
  final _languageController = TextEditingController();
  final _finishController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _provider = SearchCardProvider(SearchCardApi());
  }

  @override
  void dispose() {
    _provider.dispose();
    _setController.dispose();
    _numberController.dispose();
    _editionController.dispose();
    _languageController.dispose();
    _finishController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _provider,
      builder: (context, _) {
        final state = _provider.state;
        final busy = state.stage == SearchCardStage.searching;

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
                              context.go('/');
                            },
                            state: state),
                        const SizedBox(height: 24),
                        if (state.message != null)
                          _MessageBanner(
                            message: state.message!,
                            state: state,
                          ),
                        const SizedBox(height: 16),
                        _buildStepCard(
                          state: state,
                          busy: busy,
                          onSubmit: () async {
                            if (_selectedImageData == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Debes cargar una imagen')),
                              );
                              return;
                            }

                            final payload = SearchCardPayload(
                              imageData: _selectedImageData!,
                              mode: ConfidenceType.fast,
                            );

                            await _provider.searchByImage(payload);
                          },
                          onSubmitManual: () async {
                            if (_setController.text.isEmpty ||
                                _finishController.text.isEmpty ||
                                _numberController.text.isEmpty ||
                                _editionController.text.isEmpty ||
                                _languageController.text.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Debes rellenar los campos')),
                              );
                              return;
                            }

                            final payload = ManualSearchPayload(
                                set: _setController.text.trim(),
                                number: _numberController.text.trim(),
                                edition: _editionController.text.trim(),
                                language: _languageController.text.trim(),
                                finish: _finishController.text.trim());

                            await _provider.searchManual(payload);
                          },
                          onRetry: _provider.retry,
                          onPickImage: () => _pickImage(),
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
      },
    );
  }

  Widget _buildStepCard({
    required SearchCardState state,
    required bool busy,
    required Future<void> Function() onSubmit,
    required Future<void> Function() onSubmitManual,
    required VoidCallback onRetry,
    required Future<void> Function() onPickImage,
    required String? selectedImageName,
    required String? selectedImageExtension,
  }) {
    switch (state.stage) {
      case SearchCardStage.capture:
      case SearchCardStage.searching:
      case SearchCardStage.error:
        return _CaptureForm(
          selectedImageName: selectedImageName,
          selectedImageExtension: selectedImageExtension,
          busy: busy,
          onRetry: onRetry,
          onPickImage: onPickImage,
          onSubmit: onSubmit,
          isError: state.stage == SearchCardStage.error,
        );
      case SearchCardStage.showingCandidates:
      case SearchCardStage.success:
        return _CandidateResults(
          candidates: state.candidates,
          isSingle: state.stage == SearchCardStage.success,
          onEvaluate: (candidate) {
            final encodedName = Uri.encodeComponent(candidate.name);
            context.go(
              '/catalog/pre-process?card_id=${candidate.id}&card_name=$encodedName',
              extra: _selectedImageData,
            );
          },
          onManualSearch: () {
            _provider.goToManualSearch();
          },
          onSpecializedSearch: () async {
            if (_selectedImageData == null) {
              return;
            }

            final payload = SearchCardPayload(
                imageData: _selectedImageData!,
                mode: ConfidenceType.specialized);

            await _provider.searchByImage(payload);
          },
        );
      case SearchCardStage.manualSearch:
        return _ManualSearchForm(
            setController: _setController,
            numberController: _numberController,
            editionController: _editionController,
            languageController: _languageController,
            finishController: _finishController,
            onSubmitManual: onSubmitManual);
    }
  }

  Future<void> _pickImage() async {
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
      _selectedImageData = dataUri;
      _selectedImageName = file.name;
      _selectedImageExtension = extension;
    });
  }
}

/// @brief _Header
class _Header extends StatelessWidget {
  final VoidCallback onBack;
  final SearchCardState state;

  const _Header({required this.onBack, required this.state});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Buscar carta',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              switch (state.stage) {
                SearchCardStage.capture ||
                SearchCardStage.searching ||
                SearchCardStage.error =>
                  'Suba una imagen PNG, JPEG o HEIC',
                SearchCardStage.success => 'Carta encontrada',
                SearchCardStage.showingCandidates => 'Candidatos encontrados',
                SearchCardStage.manualSearch =>
                  '${state.message}. Ingrese datos de identidad',
              },
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

/// @brief _CandidateResults
class _CandidateResults extends StatelessWidget {
  final List<CandidateCard> candidates;
  final bool isSingle;
  final void Function(CandidateCard) onEvaluate;
  final VoidCallback onManualSearch;
  final VoidCallback onSpecializedSearch;

  const _CandidateResults(
      {required this.candidates,
      required this.isSingle,
      required this.onEvaluate,
      required this.onManualSearch,
      required this.onSpecializedSearch});

  @override
  Widget build(BuildContext context) {
    if (isSingle && candidates.length == 1) {
      final candidate = candidates.first;
      return _FormCard(
        title: 'Carta identificada',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              candidate.name,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.textPrimary,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Confianza: ${candidate.confidence.toStringAsFixed(1)}%',
              style: const TextStyle(color: AppColors.success),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => onEvaluate(candidate),
                icon: const Icon(Icons.auto_fix_high_rounded),
                label: const Text('Pre-procesar carta'),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        ...candidates.map((candidate) {
          return Card(
            child: ListTile(
              title: Text(candidate.name),
              subtitle: Text(
                'Confianza: ${candidate.confidence.toStringAsFixed(1)}%',
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => onEvaluate(candidate),
            ),
          );
        }),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onSpecializedSearch,
          icon: const Icon(Icons.search_rounded),
          label: const Text('Iniciar busqueda especializada'),
        ),
      ],
    );
  }
}

/// @brief _ManualSearchForm
class _ManualSearchForm extends StatelessWidget {
  final TextEditingController setController;
  final TextEditingController numberController;
  final TextEditingController editionController;
  final TextEditingController languageController;
  final TextEditingController finishController;
  final Future<void> Function() onSubmitManual;

  const _ManualSearchForm(
      {required this.setController,
      required this.numberController,
      required this.editionController,
      required this.languageController,
      required this.finishController,
      required this.onSubmitManual});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: setController,
          decoration: const InputDecoration(
            labelText: 'Set',
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: numberController,
          decoration: const InputDecoration(
            labelText: 'Número',
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: editionController,
          decoration: const InputDecoration(
            labelText: 'Edición',
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: languageController,
          decoration: const InputDecoration(
            labelText: 'Idioma',
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: finishController,
          decoration: const InputDecoration(
            labelText: 'Acabado',
          ),
        ),
        const SizedBox(height: 10),
        FilledButton(
          onPressed: onSubmitManual,
          child: const Text('Buscar carta'),
        )
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
  final String? selectedImageName;
  final String? selectedImageExtension;
  final bool busy;
  final bool isError;
  final VoidCallback onRetry;
  final Future<void> Function() onPickImage;
  final Future<void> Function() onSubmit;

  const _CaptureForm({
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
      title: 'Búsqueda rápida de carta',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Selecciona archivos PNG, JPG o HEIC.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 16),
          // Front Image Section
          const Text(
            'Imagen de la carta',
            style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 14),
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
              'Archivo seleccionado: $selectedImageName (${selectedImageExtension ?? ''})',
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
                  label: Text(busy ? 'Validando...' : 'Buscar carta'),
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
  final SearchCardState state;

  const _MessageBanner({required this.message, required this.state});

  @override
  Widget build(BuildContext context) {
    final isError = state.stage == SearchCardStage.error;

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
