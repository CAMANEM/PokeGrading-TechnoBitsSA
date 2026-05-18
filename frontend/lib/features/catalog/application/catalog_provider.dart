import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/catalog_models.dart';
import '../infrastructure/catalog_api_client.dart';

final catalogApiClientProvider = Provider<CatalogApiClient>((ref) {
  return CatalogApiClient();
});

final catalogSubmissionControllerProvider = StateNotifierProvider<
    CatalogSubmissionController, CatalogSubmissionState>((ref) {
  return CatalogSubmissionController(ref.read(catalogApiClientProvider));
});

class CatalogSubmissionController extends StateNotifier<CatalogSubmissionState> {
  final CatalogApiClient _apiClient;

  CatalogSubmissionController(this._apiClient)
      : super(const CatalogSubmissionState.initial());

  void submitIdentity(CardIdentityInput identity) {
    state = state.copyWith(
      identity: identity,
      stage: CatalogFlowStage.display,
      message: null,
    );
  }

  void skipDisplay() {
    state = state.copyWith(
      displayName: null,
      stage: CatalogFlowStage.image,
      message: null,
    );
  }

  void submitDisplay(String displayName) {
    state = state.copyWith(
      displayName: displayName.trim().isEmpty ? null : displayName.trim(),
      stage: CatalogFlowStage.image,
      message: null,
    );
  }

  Future<void> submitImage(String imageData) async {
    final identity = state.identity;
    if (identity == null) {
      state = state.copyWith(
        stage: CatalogFlowStage.error,
        message: 'Primero debes completar la identidad de la carta',
      );
      return;
    }

    state = state.copyWith(stage: CatalogFlowStage.submitting, message: null);

    try {
      final result = await _apiClient.addCard(
        AddCardPayload(
          identity: identity,
          displayName: state.displayName,
          imageData: imageData,
        ),
      );

      state = state.copyWith(
        stage: CatalogFlowStage.success,
        result: result,
        message: 'Carta agregada correctamente',
      );
    } on CatalogApiException catch (error) {
      state = state.copyWith(
        stage: CatalogFlowStage.error,
        message: error.message,
      );
    }
  }

  void reset() {
    state = const CatalogSubmissionState.initial();
  }

  void retryFromImage() {
    state = state.copyWith(
      stage: CatalogFlowStage.image,
      message: null,
    );
  }
}
