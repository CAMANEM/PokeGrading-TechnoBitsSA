/// @file
/// @brief

import 'package:flutter/foundation.dart';

import '../../../core/logging/client_log_reporter.dart';
import 'search_card_api.dart';
import 'search_card_state.dart';

/// @brief SearchCardProvider
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
          message: result.reason);
    } on SearchCardApiException catch (error) {
      ClientLogReporter.reportError(
        logger: 'PokéGrading.Client.SearchCardProvider',
        correlationId: '',
        message: 'Image search failed',
        context: {'api_error': error.message},
      );
      _state = _state.copyWith(
        stage: SearchCardStage.error,
        message: error.message,
      );
    } catch (error) {
      ClientLogReporter.reportError(
        logger: 'PokéGrading.Client.SearchCardProvider',
        correlationId: '',
        message: 'Image search unexpected error',
        context: {'error': error.toString()},
      );
      _state = _state.copyWith(
        stage: SearchCardStage.error,
        message: 'Error: ${error.toString()}',
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
      ClientLogReporter.reportError(
        logger: 'PokéGrading.Client.SearchCardProvider',
        correlationId: '',
        message: 'Manual search failed',
        context: {'api_error': error.message},
      );
      _state = _state.copyWith(
        stage: SearchCardStage.error,
        message: error.message,
      );
    } catch (error) {
      ClientLogReporter.reportError(
        logger: 'PokéGrading.Client.SearchCardProvider',
        correlationId: '',
        message: 'Manual search unexpected error',
        context: {'error': error.toString()},
      );
      _state = _state.copyWith(
        stage: SearchCardStage.error,
        message: 'Error: ${error.toString()}',
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
