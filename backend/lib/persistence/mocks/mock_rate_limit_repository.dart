import '../b2b_data_provider/rate_limit_repository.dart';

class MockRateLimitRepository implements RateLimitRepository {
  int _consumed = 0;

  @override
  Future<int> obtainConsumed({required int apiKeyId}) async {
    //if (_consumed + cardCount > monthlyLimit) {
    //return 3600;
    //}
    //_consumed += cardCount;
    return 0;
  }

  @override
  Future<void> recordConsume(
      {required int apiKeyId, required int cardsConsumed}) {
    // TODO: implement recordConsume
    throw UnimplementedError();
  }

  @override
  Future<void> updateConsume(
      {required int apiKeyId, required int cardsConsumed}) {
    // TODO: implement updateConsume
    throw UnimplementedError();
  }
}
