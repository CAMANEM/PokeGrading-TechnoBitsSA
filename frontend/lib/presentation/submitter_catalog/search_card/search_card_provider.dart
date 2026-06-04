import 'package:flutter/foundation.dart';

import 'search_card_api.dart';
import 'search_card_state.dart';

class SearchCardProvider extends ChangeNotifier {
  SearchCardProvider(this._api);

  final SearchCardApi _api;

  SearchCardState _state = const SearchCardState.initial();

  SearchCardState get state => _state;

  Future<void> searchByImage(
    SearchCardPayload payload,
  ) async {
    _state = _state.copyWith(
      stage: SearchCardStage.searching,
      message: null,
    );

    notifyListeners();

    try {
      final result = await _api.searchByImage(payload);

      _state = _state.copyWith(
        stage: result.nextStage,
        candidates: result.candidates,
      );
    } on SearchCardApiException catch (error) {
      _state = _state.copyWith(
        stage: SearchCardStage.error,
        message: error.message,
      );
    }

    notifyListeners();
  }

  Future<void> searchManual(
    ManualSearchPayload payload,
  ) async {
    _state = _state.copyWith(
      stage: SearchCardStage.searching,
      message: null,
    );

    notifyListeners();

    try {
      final result = await _api.searchManual(payload);

      _state = _state.copyWith(
        stage: result.nextStage,
        candidates: result.candidates,
      );
    } on SearchCardApiException catch (error) {
      _state = _state.copyWith(
        stage: SearchCardStage.error,
        message: error.message,
      );
    }

    notifyListeners();
  }

  void reset() {
    _state = const SearchCardState.initial();
    notifyListeners();
  }

  void goToManualSearch() {
    _state = _state.copyWith(
      stage: SearchCardStage.manualSearch,
      message: null,
    );

    notifyListeners();
  }

  void retry() {
    _state = _state.copyWith(
      stage: SearchCardStage.capture,
      message: null,
    );

    notifyListeners();
  }
}
