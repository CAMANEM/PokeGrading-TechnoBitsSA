/// @file
/// @brief Browse submitter and reference catalog cards.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../navigation_history.dart';
import 'catalog_browse_api.dart';
import 'catalog_browse_provider.dart';
import 'catalog_browse_state.dart';

class CatalogBrowseScreen extends StatefulWidget {
  const CatalogBrowseScreen({super.key});

  @override
  State<CatalogBrowseScreen> createState() => _CatalogBrowseScreenState();
}

class _CatalogBrowseScreenState extends State<CatalogBrowseScreen> {
  late final CatalogBrowseProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = CatalogBrowseProvider(CatalogBrowseApi());
    _provider.loadCurrentTab();
  }

  @override
  void dispose() {
    _provider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _provider,
      builder: (context, _) {
        final state = _provider.state;

        return Scaffold(
          backgroundColor: AppColors.backgroundDark,
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _BrowseHeader(
                  onBack: () => goBackOrHome(context),
                  onRefresh: _provider.loadCurrentTab,
                ),
                _TabSelector(
                  tab: state.tab,
                  onTabSelected: _provider.switchTab,
                ),
                if (state.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: _ErrorBanner(message: state.errorMessage!),
                  ),
                Expanded(child: _buildBody(state)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody(CatalogBrowseState state) {
    if (state.stage == CatalogBrowseStage.loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (state.stage == CatalogBrowseStage.error && state.cards.isEmpty) {
      return Center(
        child: Text(
          state.errorMessage ?? 'Could not load cards',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    if (state.cards.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.style_outlined,
              size: 48,
              color: AppColors.textSecondary.withOpacity(0.6),
            ),
            const SizedBox(height: 12),
            Text(
              state.tab == CatalogBrowseTab.submitter
                  ? 'No submitter cards yet'
                  : 'No reference cards in catalog',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _provider.loadCurrentTab,
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 220,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 0.72,
            ),
            itemCount: state.cards.length,
            itemBuilder: (context, index) {
              final card = state.cards[index];
              return _CatalogCardTile(
                card: card,
                onTap: () async {
                  await _provider.openCardDetail(card.id);
                  if (!mounted) return;
                  final detail = _provider.state.selectedDetail;
                  if (detail != null) {
                    await showDialog<void>(
                      context: context,
                      builder: (context) => _CardDetailDialog(
                        detail: detail,
                        onClose: _provider.closeDetail,
                      ),
                    );
                    _provider.closeDetail();
                  }
                },
              );
            },
          ),
        ),
        if (state.loadingDetail)
          const ColoredBox(
            color: Colors.black26,
            child: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          ),
      ],
    );
  }
}

class _BrowseHeader extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback onRefresh;

  const _BrowseHeader({
    required this.onBack,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded),
            color: AppColors.textPrimary,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Catalog Browse',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                Text(
                  'Submitter cards and reference catalog',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded),
            color: AppColors.textSecondary,
            tooltip: 'Refresh',
          ),
        ],
      ),
    );
  }
}

class _TabSelector extends StatelessWidget {
  final CatalogBrowseTab tab;
  final ValueChanged<CatalogBrowseTab> onTabSelected;

  const _TabSelector({
    required this.tab,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderDark),
        ),
        child: Row(
          children: [
            Expanded(
              child: _TabButton(
                label: 'Submitter',
                icon: Icons.person_outline_rounded,
                selected: tab == CatalogBrowseTab.submitter,
                onTap: () => onTabSelected(CatalogBrowseTab.submitter),
              ),
            ),
            Expanded(
              child: _TabButton(
                label: 'Reference',
                icon: Icons.library_books_outlined,
                selected: tab == CatalogBrowseTab.reference,
                onTap: () => onTabSelected(CatalogBrowseTab.reference),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary.withOpacity(0.15) : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? AppColors.primaryLight : AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: selected ? AppColors.primaryLight : AppColors.textSecondary,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CatalogCardTile extends StatelessWidget {
  final CatalogCardSummary card;
  final VoidCallback onTap;

  const _CatalogCardTile({
    required this.card,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.cardDark,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.borderDark),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _CardThumbnailPlaceholder(
                  source: card.source,
                  hasImages: card.hasImages,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${card.set} #${card.number}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        _ChipLabel(text: card.finish),
                        _ChipLabel(text: card.edition),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardThumbnailPlaceholder extends StatelessWidget {
  final String source;
  final bool hasImages;

  const _CardThumbnailPlaceholder({
    required this.source,
    required this.hasImages,
  });

  @override
  Widget build(BuildContext context) {
    final isSubmitter = source == 'submitter';
    final icon = isSubmitter
        ? (hasImages ? Icons.photo_rounded : Icons.image_not_supported_outlined)
        : Icons.menu_book_rounded;

    return Container(
      color: AppColors.surfaceDark2,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 36, color: AppColors.primary.withOpacity(0.7)),
            const SizedBox(height: 6),
            Text(
              isSubmitter ? 'Submitter' : 'Reference',
              style: TextStyle(
                color: AppColors.textSecondary.withOpacity(0.8),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChipLabel extends StatelessWidget {
  final String text;

  const _ChipLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 10,
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.error.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.error, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _CardDetailDialog extends StatelessWidget {
  final CatalogCardDetail detail;
  final VoidCallback onClose;

  const _CardDetailDialog({
    required this.detail,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final card = detail.summary;

    return Dialog(
      backgroundColor: AppColors.cardDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.borderDark),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 720),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      card.title,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      onClose();
                      context.pop();
                    },
                    icon: const Icon(Icons.close_rounded),
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (detail.frontImageData != null ||
                        detail.backImageData != null)
                      _ImageRow(
                        frontData: detail.frontImageData,
                        backData: detail.backImageData,
                      )
                    else
                      _NoImagesPlaceholder(source: card.source),
                    const SizedBox(height: 16),
                    _MetadataGrid(card: card),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImageRow extends StatelessWidget {
  final String? frontData;
  final String? backData;

  const _ImageRow({
    this.frontData,
    this.backData,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (frontData != null)
          Expanded(
            child: _CardImagePanel(label: 'Front', imageData: frontData!),
          ),
        if (frontData != null && backData != null) const SizedBox(width: 12),
        if (backData != null)
          Expanded(
            child: _CardImagePanel(label: 'Back', imageData: backData!),
          ),
      ],
    );
  }
}

class _CardImagePanel extends StatelessWidget {
  final String label;
  final String imageData;

  const _CardImagePanel({
    required this.label,
    required this.imageData,
  });

  @override
  Widget build(BuildContext context) {
    final bytes = _decodeDataUri(imageData);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: AspectRatio(
            aspectRatio: 0.72,
            child: bytes != null
                ? Image.memory(bytes, fit: BoxFit.cover)
                : ColoredBox(
                    color: AppColors.surfaceDark2,
                    child: const Center(
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _NoImagesPlaceholder extends StatelessWidget {
  final String source;

  const _NoImagesPlaceholder({required this.source});

  @override
  Widget build(BuildContext context) {
    final message = source == 'reference'
        ? 'Reference cards store metadata only (no images in catalog).'
        : 'No images available for this card.';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Column(
        children: [
          Icon(
            Icons.image_not_supported_outlined,
            size: 40,
            color: AppColors.textSecondary.withOpacity(0.7),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _MetadataGrid extends StatelessWidget {
  final CatalogCardSummary card;

  const _MetadataGrid({required this.card});

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[
      ('ID', card.id),
      ('Source', card.source),
      ('Set', card.set),
      ('Number', card.number),
      ('Edition', card.edition),
      ('Language', card.language),
      ('Finish', card.finish),
      if (card.rarity != null) ('Rarity', card.rarity!),
      if (card.pokemonType != null) ('Type', card.pokemonType!),
      if (card.hp != null) ('HP', card.hp!.toString()),
      ('Active', card.active ? 'Yes' : 'No'),
      if (card.createdAt != null)
        ('Created', card.createdAt!.toLocal().toString()),
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Column(
        children: rows
            .map(
              (row) => Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 100,
                      child: Text(
                        row.$1,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        row.$2,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

Uint8List? _decodeDataUri(String dataUri) {
  try {
    final commaIndex = dataUri.indexOf(',');
    if (commaIndex == -1) return null;
    final base64Part = dataUri.substring(commaIndex + 1);
    return base64Decode(base64Part);
  } catch (_) {
    return null;
  }
}
