/// @file
/// @brief State holder for catalog browse screen.

import 'package:flutter/foundation.dart';

import 'catalog_browse_api.dart';
import 'catalog_browse_state.dart';

class CatalogBrowseProvider extends ChangeNotifier {
  final CatalogBrowseApi _api;
  CatalogBrowseState _state = const CatalogBrowseState();

  CatalogBrowseProvider(CatalogBrowseApi api) : _api = api;

  CatalogBrowseState get state => _state;

  Future<void> loadCurrentTab() async {
    _state = _state.copyWith(
      stage: CatalogBrowseStage.loading,
      errorMessage: null,
      clearSelectedDetail: true,
    );
    notifyListeners();

    try {
      final cards = _state.tab == CatalogBrowseTab.submitter
          ? await _api.listSubmitterCards()
          : await _api.listReferenceCards();

      _state = _state.copyWith(
        stage: CatalogBrowseStage.loaded,
        cards: cards,
        errorMessage: null,
      );
    } on CatalogBrowseApiException catch (e) {
      _state = _state.copyWith(
        stage: CatalogBrowseStage.error,
        errorMessage: e.message,
        cards: [],
      );
    } catch (e) {
      _state = _state.copyWith(
        stage: CatalogBrowseStage.error,
        errorMessage: 'Unexpected error: $e',
        cards: [],
      );
    }
    notifyListeners();
  }

  Future<void> switchTab(CatalogBrowseTab tab) async {
    if (_state.tab == tab && _state.stage == CatalogBrowseStage.loaded) {
      return;
    }
    _state = _state.copyWith(tab: tab);
    await loadCurrentTab();
  }

  Future<void> openCardDetail(String id) async {
    _state = _state.copyWith(
      loadingDetail: true,
      clearSelectedDetail: true,
      errorMessage: null,
    );
    notifyListeners();

    try {
      final detail = _state.tab == CatalogBrowseTab.submitter
          ? await _api.getSubmitterCardDetail(id)
          : await _api.getReferenceCardDetail(id);

      _state = _state.copyWith(
        selectedDetail: detail,
        loadingDetail: false,
      );
    } on CatalogBrowseApiException catch (e) {
      _state = _state.copyWith(
        loadingDetail: false,
        errorMessage: e.message,
      );
    } catch (e) {
      _state = _state.copyWith(
        loadingDetail: false,
        errorMessage: 'Unexpected error: $e',
      );
    }
    notifyListeners();
  }

  void closeDetail() {
    _state = _state.copyWith(clearSelectedDetail: true);
    notifyListeners();
  }
}
