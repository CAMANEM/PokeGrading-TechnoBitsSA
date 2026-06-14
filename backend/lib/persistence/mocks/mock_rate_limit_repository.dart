import '../b2b_data_provider/rate_limit_repository.dart';

class MockRateLimitRepository implements RateLimitRepository {
  int _consumed = 0;

  @override
  Future<int?> tryConsume({
    required int apiKeyId,
    required int cardCount,
    required int monthlyLimit,
  }) async {
    if (_consumed + cardCount > monthlyLimit) {
      return 3600;
    }
    _consumed += cardCount;
    return null;
  }
}
