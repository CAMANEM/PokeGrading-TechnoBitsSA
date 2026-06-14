import 'package:pokegrading_logging/pokegrading_logging.dart';
import 'package:test/test.dart';

void main() {
  group('RequestLogContext', () {
    test('sanitizes password in request params', () {
      final sanitized = RequestLogContext.sanitize({
        'email': 'user@example.com',
        'username': 'ash',
        'password': 'secret123',
        'country': 'AR',
        'language': 'es',
        'acceptedDisclosure': true,
      });

      expect(sanitized['email'], 'user@example.com');
      expect(sanitized['username'], 'ash');
      expect(sanitized['password'], LogRedaction.redactedValue);
      expect(sanitized['country'], 'AR');
    });

    test('withParams nests sanitized body under params key', () {
      final wrapped = RequestLogContext.withParams({
        'username': 'ash',
        'password': 'secret',
      });

      expect(wrapped['params'], isA<Map>());
      expect((wrapped['params'] as Map)['password'], LogRedaction.redactedValue);
    });
  });

  group('LogRedaction', () {
    test('redacts password and image payloads', () {
      final scrubbed = LogRedaction.scrubMap({
        'username': 'ash',
        'password': 'secret123',
        'front_image_data': 'data:image/png;base64,${'A' * 512}',
      });

      expect(scrubbed!['username'], 'ash');
      expect(scrubbed['password'], LogRedaction.redactedValue);
      expect(scrubbed['front_image_data'], LogRedaction.redactedValue);
    });
  });

  group('CorrelationContext', () {
    test('propagates correlation id through async zone', () async {
      await CorrelationContext.runAsync('abc-123', () async {
        expect(CorrelationContext.current, 'abc-123');
      });
    });
  });

  group('LogEvent', () {
    test('serializes to JSON with correlation_id', () {
      final event = LogEvent(
        timestamp: DateTime.utc(2026, 6, 14, 12),
        level: 'INFO',
        category: LogCategory.grading,
        logger: 'PokéGrading.Evaluation',
        correlationId: '550e8400-e29b-41d4-a716-446655440000',
        message: 'Stage completed',
        context: {'stage': 'iqs_front'},
      );

      final json = event.toJson();
      expect(json['category'], 'grading');
      expect(json['correlation_id'], isNotNull);
      expect(json['context'], {'stage': 'iqs_front'});
    });
  });
}
