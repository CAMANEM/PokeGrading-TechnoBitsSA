import 'package:pokegrading_exceptions/pokegrading_exceptions.dart';

import '../image_services/preprocessing/preprocessing_service.dart';
import 'scoring_models.dart';
import 'grading/pregrading.dart';

class PreGradingCommand {
  final int cardSubmitterId;
  final int cardReferenceId;
  final String correlationId;

  const PreGradingCommand({
    required this.cardSubmitterId,
    required this.cardReferenceId,
    required this.correlationId,
  });
}

class PreGradingResult {
  final int preGradeId;
  final GradingResult grading;
  final DateTime gradedAt;

  const PreGradingResult({
    required this.preGradeId,
    required this.grading,
    required this.gradedAt,
  });
}

class PreGradingLogic {
  final PreGradingRepository repository;

  PreGradingLogic({required this.repository});

  Future<PreGradingResult> execute(PreGradingCommand command) async {
    _validate(command);

    final existing = await repository.findExistingPreGrade(
      command.cardSubmitterId,
      command.cardReferenceId,
    );
    if (existing != null) {
      return existing;
    }

    final submitterImages = await repository.loadSubmitterImages(
      command.cardSubmitterId,
    );
    if (submitterImages == null) {
      throw LogicException(
        feature: 'pre_grading',
        code: 'submitter_not_found',
        message:
            'No images found for card_submitter_id ${command.cardSubmitterId}',
      );
    }

    final referenceImages = await repository.loadReferenceImages(
      command.cardReferenceId,
    );
    if (referenceImages == null) {
      throw LogicException(
        feature: 'pre_grading',
        code: 'reference_not_found',
        message:
            'No images found for card_reference_id ${command.cardReferenceId}',
      );
    }

    final submitterFront = _ensureDataPrefix(submitterImages.front);
    final referenceFront = _ensureDataPrefix(referenceImages.front);

    final submitterPreprocess = PreprocessingService.preprocess(submitterFront);
    final referencePreprocess =
        PreprocessingService.preprocess(referenceFront);

    if (!submitterPreprocess.success || submitterPreprocess.rois == null) {
      throw LogicException(
        feature: 'pre_grading',
        code: 'submitter_preprocess_failed',
        message:
            'Could not preprocess submitter image: ${submitterPreprocess.errorMessage}',
      );
    }
    if (!referencePreprocess.success || referencePreprocess.rois == null) {
      throw LogicException(
        feature: 'pre_grading',
        code: 'reference_preprocess_failed',
        message:
            'Could not preprocess reference image: ${referencePreprocess.errorMessage}',
      );
    }

    final gradingResult = Grading.grade(
      submitterPreprocess.rois!,
      referencePreprocess.rois!,
    );

    final now = DateTime.now().toUtc();
    final preGradeId = await repository.savePreGrade(
      cardSubmitterId: command.cardSubmitterId,
      cardReferenceId: command.cardReferenceId,
      grading: gradingResult,
      gradedAt: now,
      correlationId: command.correlationId,
    );

    return PreGradingResult(
      preGradeId: preGradeId,
      grading: gradingResult,
      gradedAt: now,
    );
  }

  void _validate(PreGradingCommand command) {
    if (command.cardSubmitterId <= 0) {
      throw LogicException(
        feature: 'pre_grading',
        code: 'invalid_submitter_id',
        message: 'card_submitter_id must be a positive integer',
      );
    }
    if (command.cardReferenceId <= 0) {
      throw LogicException(
        feature: 'pre_grading',
        code: 'invalid_reference_id',
        message: 'card_reference_id must be a positive integer',
      );
    }
  }

  String _ensureDataPrefix(String raw) {
    if (raw.startsWith('data:image/')) {
      return raw;
    }
    return 'data:image/jpeg;base64,$raw';
  }
}

abstract class PreGradingRepository {
  Future<PreGradingResult?> findExistingPreGrade(
    int cardSubmitterId,
    int cardReferenceId,
  );

  Future<({String front, String back})?> loadSubmitterImages(
    int cardSubmitterId,
  );

  Future<({String front, String back})?> loadReferenceImages(
    int cardReferenceId,
  );

  Future<int> savePreGrade({
    required int cardSubmitterId,
    required int cardReferenceId,
    required GradingResult grading,
    required DateTime gradedAt,
    required String correlationId,
  });
}
