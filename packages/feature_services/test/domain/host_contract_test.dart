import 'dart:convert';

import 'package:feature_services/src/domain/host_contract.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HostContext', () {
    test('carries the contract version, the locale and the segment only', () {
      const context = HostContext(locale: 'es-EC', segment: 'family');

      expect(context.toJson(), {
        'type': 'context',
        'version': 1,
        'locale': 'es-EC',
        'segment': 'family',
      });
    });

    test('sends an unknown segment instead of text that is not an id', () {
      for (final segment in [
        '',
        'my segment',
        '<script>',
        '4you',
        'a' * 33,
        "family'); alert(1); ('",
      ]) {
        final context = HostContext(locale: 'es-EC', segment: segment);

        expect(context.toJson()['segment'], 'unknown', reason: segment);
      }
    });
  });

  group('parsePartnerMessage', () {
    test('reads a request to close', () {
      expect(parsePartnerMessage('{"type":"close"}'), isA<PartnerClosed>());
    });

    test('reads a completed operation with its reference', () {
      final message = parsePartnerMessage(
        '{"type":"completed","reference":"SV-2026-00042"}',
      );

      expect(message, isA<PartnerCompleted>());
      expect((message! as PartnerCompleted).reference, 'SV-2026-00042');
    });

    test('reads a completed operation without a reference', () {
      final message = parsePartnerMessage('{"type":"completed"}');

      expect(message, isA<PartnerCompleted>());
      expect((message! as PartnerCompleted).reference, isNull);
    });

    test('ignores keys the contract does not name', () {
      final message = parsePartnerMessage(
        '{"type":"completed","reference":"R1","amount":120,"html":"<b>x</b>"}',
      );

      expect((message! as PartnerCompleted).reference, 'R1');
    });

    test('accepts a reference of exactly the longest length', () {
      final reference = 'A' * HostContract.maxReferenceLength;
      final message = parsePartnerMessage(
        jsonEncode({'type': 'completed', 'reference': reference}),
      );

      expect((message! as PartnerCompleted).reference, reference);
    });

    test('drops what is not a message of the contract', () {
      for (final raw in [
        '',
        'close',
        'null',
        '42',
        '"close"',
        '[]',
        '["close"]',
        '{}',
        '{"type":null}',
        '{"type":7}',
        '{"type":"open"}',
        '{"type":"context"}',
        '{"type":"CLOSE"}',
        '{"type":"close"',
        '{"type":"completed","reference":""}',
        '{"type":"completed","reference":7}',
        '{"type":"completed","reference":null}',
        '{"type":"completed","reference":["R1"]}',
        '{"type":"completed","reference":"has space"}',
        '{"type":"completed","reference":"<img src=x>"}',
        '{"type":"completed","reference":"línea"}',
        jsonEncode({
          'type': 'completed',
          'reference': 'A' * (HostContract.maxReferenceLength + 1),
        }),
      ]) {
        expect(parsePartnerMessage(raw), isNull, reason: raw);
      }
    });

    test('drops a message longer than the limit without reading it', () {
      final padding = 'x' * HostContract.maxMessageLength;

      expect(
        parsePartnerMessage('{"type":"close","padding":"$padding"}'),
        isNull,
      );
    });

    test('never throws, whatever it is given', () {
      for (final raw in [
        '{"type":{"a":{"b":{}}}}',
        '\u0000',
        '{"type":"\ud83d"}',
      ]) {
        expect(() => parsePartnerMessage(raw), returnsNormally, reason: raw);
      }
    });
  });
}
