import 'package:uuid/uuid.dart';

abstract class IdGenerator {
  String generateCardId();
}

class UuidIdGenerator implements IdGenerator {
  final Uuid _uuid;

  UuidIdGenerator({Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  @override
  String generateCardId() {
    return _uuid.v4();
  }
}
