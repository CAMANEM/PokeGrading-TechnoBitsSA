import 'package:flutter_test/flutter_test.dart';
import 'package:pokegrading_frontend/presentation/submitter_catalog/submit_evaluation/submit_evaluation_api.dart';
import 'package:pokegrading_frontend/presentation/submitter_catalog/submit_evaluation/submit_evaluation_provider.dart';
import 'package:pokegrading_frontend/presentation/submitter_catalog/submit_evaluation/submit_evaluation_state.dart';

class _RetryEvaluationApi extends SubmitEvaluationApi {
  final submittedPayloads = <SubmitEvaluationPayload>[];

  @override
  Future<SubmitEvaluationResult> submit(SubmitEvaluationPayload payload) async {
    submittedPayloads.add(payload);

    if (submittedPayloads.length == 1) {
      throw const SubmitEvaluationApiException(
        'No se pudo completar el envio por un fallo de red.',
      );
    }

    return SubmitEvaluationResult(
      evaluationId: 'eval-123',
      status: 'pending',
      createdAt: DateTime.utc(2026, 6, 2),
      estimatedTime: '24h',
    );
  }
}

void main() {
  test('retry resubmits the last payload after a network failure', () async {
    final api = _RetryEvaluationApi();
    final provider = SubmitEvaluationProvider(api);
    const payload = SubmitEvaluationPayload(
      frontImageData: 'data:image/png;base64,front',
      backImageData: 'data:image/png;base64,back',
    );

    await provider.submit(payload);

    expect(provider.state.stage, SubmitEvaluationStage.error);
    expect(api.submittedPayloads, [payload]);

    await provider.retry();

    expect(provider.state.stage, SubmitEvaluationStage.success);
    expect(provider.state.result?.evaluationId, 'eval-123');
    expect(api.submittedPayloads, [payload, payload]);
  });
}
