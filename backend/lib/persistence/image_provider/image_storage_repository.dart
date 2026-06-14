/// Contract for storing and loading submitter card images in MongoDB GridFS.
abstract class ImageStorageRepository {
  Future<void> saveSubmitterImages({
    required int cardSubmitterId,
    required String frontBase64,
    required String backBase64,
    String? perceptualHash,
  });

  Future<({String front, String back})?> loadSubmitterImages(
    int cardSubmitterId,
  );

  Future<void> close();
}
