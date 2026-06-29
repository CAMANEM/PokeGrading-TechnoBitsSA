/// @file
/// @brief Monthly card-count rate limiting for B2B consult.
///
/// Rate limiting by card count per monthly window.
abstract class RateLimitRepository {
  /// Attempts to consume [cardCount] units. Returns null on success or retry seconds on limit.
  Future<int> obtainConsumed({
    required int apiKeyId,
  });

  Future<void> recordConsume(
      {required int apiKeyId, required int cardsConsumed});

  Future<void> updateConsume(
      {required int apiKeyId, required int cardsConsumed});
}
