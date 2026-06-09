/// @file
/// @brief

import 'package:uuid/uuid.dart';

/*
 ID generation abstraction for card identifiers.

 Implementations may vary (UUID, sequential, or database-assigned). The
+ default `UuidIdGenerator` produces UUID v4 strings suitable for tests and
 rapid prototyping.
*/

/// @brief IdGenerator
abstract class IdGenerator {
  String generateCardId();
}

/// @brief UuidIdGenerator
class UuidIdGenerator implements IdGenerator {
  final Uuid _uuid;

  UuidIdGenerator({Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  @override
  String generateCardId() {
    return _uuid.v4();
  }
}
