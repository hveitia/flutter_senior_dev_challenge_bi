import 'dart:convert';
import 'dart:io';

import 'package:app_platform/app_platform.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:json_schema/json_schema.dart';

const _schemaPath = '../../contracts/home-config.schema.json';
const _examplePath = '../../contracts/home-config.example.json';

Map<String, Object?> _decode(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>;

/// A minimal document that satisfies the schema, with the given overrides
/// applied on top of it.
Map<String, Object?> _published({
  Map<String, Object?> root = const {},
  Map<String, Object?> segment = const {},
  Map<String, Object?> module = const {},
}) => {
  'schemaVersion': 1,
  'configVersion': 1,
  'destinations': ['transfer'],
  'segments': {
    'starting': {
      'label': 'Estoy empezando',
      'modules': [
        {'id': 'balance', 'type': 'totalBalance', ...module},
      ],
      'features': {'transfers': true, 'partnerServices': false},
      ...segment,
    },
  },
  ...root,
};

void main() {
  late JsonSchema schema;

  bool isPublishable(Object? document) => schema.validate(document).isValid;

  bool isReadable(Object? document) =>
      const HomeConfigParser().parse(document) is ConfigAccepted;

  setUpAll(() => schema = JsonSchema.create(_decode(_schemaPath)));

  group('the contract example', () {
    test('satisfies the schema', () {
      final result = schema.validate(_decode(_examplePath));

      expect(result.errors, isEmpty);
      expect(result.isValid, isTrue);
    });

    test('is also accepted by the reader', () {
      expect(isReadable(_decode(_examplePath)), isTrue);
    });
  });

  group('the schema', () {
    test('accepts the minimal document these tests start from', () {
      expect(isPublishable(_published()), isTrue);
    });

    test('accepts fields it does not know, so the contract can grow', () {
      expect(
        isPublishable(_published(root: {'experiments': <Object?>[]})),
        isTrue,
      );
    });
  });

  // The reader is deliberately more lenient than the schema: these documents
  // must never be published, yet an installed app that receives one keeps
  // working. Each case is one difference recorded in ADR 0008.
  group('a document the schema rejects and the reader still accepts', () {
    final cases = <String, Map<String, Object?>>{
      'without a config version': _published()..remove('configVersion'),
      'with a negative config version': _published(
        root: {'configVersion': -1},
      ),
      'without the destination allow-list': _published()
        ..remove('destinations'),
      'with latency above the cap': _published(
        root: {
          'resilience': {'latencyMs': 60000},
        },
      ),
      'with fractional latency': _published(
        root: {
          'resilience': {'latencyMs': 250.5},
        },
      ),
      'with a segment that has no modules list': {
        ..._published(),
        'segments': {
          'starting': {
            'label': 'Estoy empezando',
            'features': {'transfers': true, 'partnerServices': false},
          },
        },
      },
      'with a segment that has no label': {
        ..._published(),
        'segments': {
          'starting': {
            'modules': <Object?>[],
            'features': {'transfers': true, 'partnerServices': false},
          },
        },
      },
      'with a segment that does not state its features': {
        ..._published(),
        'segments': {
          'starting': {'label': 'Estoy empezando', 'modules': <Object?>[]},
        },
      },
      'with a feature flag sent as text': _published(
        segment: {
          'features': {'transfers': 'true', 'partnerServices': false},
        },
      ),
      'with a module that has no type': {
        ..._published(),
        'segments': {
          'starting': {
            'label': 'Estoy empezando',
            'modules': [
              {'id': 'balance'},
              {'id': 'accounts', 'type': 'accountCarousel'},
            ],
            'features': {'transfers': true, 'partnerServices': false},
          },
        },
      },
      'with props that are not an object': _published(
        module: {'props': 'none'},
      ),
      'with visibility sent as text': _published(module: {'visible': 'yes'}),
      // Past the bounds the reader keeps what fits and ignores the rest.
      'with more destinations than the bound': _published(
        root: {
          'destinations': [
            for (var i = 0; i <= ConfigLimits.destinations; i++) 'd$i',
          ],
        },
      ),
      'with more modules than the bound': _published(
        segment: {
          'modules': [
            for (var i = 0; i <= ConfigLimits.modulesPerSegment; i++)
              {'id': 'm$i', 'type': 'totalBalance'},
          ],
        },
      ),
      'with more segments than the bound': {
        ..._published(),
        'segments': {
          for (var i = 0; i <= ConfigLimits.segments; i++)
            's$i': {
              'label': 'Segmento',
              'modules': <Object?>[],
              'features': {'transfers': true, 'partnerServices': false},
            },
        },
      },
      'with a segment id that is not an identifier': {
        ..._published(),
        'segments': {
          'Mi segmento': {
            'label': 'Mi segmento',
            'modules': <Object?>[],
            'features': {'transfers': true, 'partnerServices': false},
          },
        },
      },
      'with a label longer than the bound': _published(
        segment: {'label': 'x' * 41},
      ),
      'with more props than the bound': _published(
        module: {
          'props': {for (var i = 0; i <= 24; i++) 'p$i': i},
        },
      ),
    };

    for (final MapEntry(key: description, value: document) in cases.entries) {
      test(description, () {
        expect(isPublishable(document), isFalse);
        expect(isReadable(document), isTrue);
      });
    }
  });

  group('a document both the schema and the reader reject', () {
    final cases = <String, Map<String, Object?>>{
      'without a schema version': _published()..remove('schemaVersion'),
      'with a schema version below the first': _published(
        root: {'schemaVersion': 0},
      ),
      'without segments': _published(root: {'segments': <String, Object?>{}}),
    };

    for (final MapEntry(key: description, value: document) in cases.entries) {
      test(description, () {
        expect(isPublishable(document), isFalse);
        expect(isReadable(document), isFalse);
      });
    }
  });

  group('a rule the schema cannot express', () {
    test('a newer schema version is publishable, and the reader rejects it '
        'on purpose', () {
      final newer = _published(
        root: {'schemaVersion': HomeConfigParser.supportedSchemaVersion + 1},
      );

      expect(isPublishable(newer), isTrue);
      expect(isReadable(newer), isFalse);
    });

    test('a repeated module id is publishable, and the reader keeps the '
        'first', () {
      final repeated = {
        ..._published(),
        'segments': {
          'starting': {
            'label': 'Estoy empezando',
            'modules': [
              {'id': 'balance', 'type': 'totalBalance'},
              {'id': 'balance', 'type': 'accountCarousel'},
            ],
            'features': {'transfers': true, 'partnerServices': false},
          },
        },
      };

      expect(isPublishable(repeated), isTrue);
      expect(isReadable(repeated), isTrue);
    });

    test('an action outside the allow-list is publishable, and the reader '
        'drops it', () {
      final stray = _published(
        module: {
          'props': {
            'action': {'label': 'Cripto', 'destination': 'crypto'},
          },
        },
      );

      expect(isPublishable(stray), isTrue);
      expect(isReadable(stray), isTrue);
    });
  });
}
