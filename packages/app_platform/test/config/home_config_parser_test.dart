import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:app_platform/app_platform.dart';
import 'package:flutter_test/flutter_test.dart';

const _contractExample = '../../contracts/home-config.example.json';

Map<String, Object?> _module({
  Object? id = 'balance',
  Object? type = 'totalBalance',
  Map<String, Object?> extra = const {},
}) => {'id': id, 'type': type, ...extra};

Map<String, Object?> _document({
  Object? schemaVersion = 1,
  List<Object?>? modules,
  Map<String, Object?> root = const {},
  Map<String, Object?> segment = const {},
}) => {
  'schemaVersion': schemaVersion,
  'destinations': ['transfer', 'services'],
  'segments': {
    'starting': {
      'modules': modules ?? [_module()],
      ...segment,
    },
  },
  ...root,
};

HomeConfig _accepted(Object? raw) {
  final result = const HomeConfigParser().parse(raw);
  expect(result, isA<ConfigAccepted>());
  return (result as ConfigAccepted).config;
}

ConfigRejectionReason _rejection(Object? raw) {
  final result = const HomeConfigParser().parse(raw);
  expect(result, isA<ConfigRejected>());
  return (result as ConfigRejected).reason;
}

void main() {
  group('contract example', () {
    late HomeConfig config;

    setUp(() {
      final source = File(_contractExample).readAsStringSync();
      final result = const HomeConfigParser().parseJson(source);
      config = (result as ConfigAccepted).config;
    });

    test('reads versions, destinations and every segment', () {
      expect(config.schemaVersion, 1);
      expect(config.configVersion, 14);
      expect(config.destinations, contains('partner:travelInsurance'));
      expect(config.destinations, hasLength(7));
      expect(
        config.segments.keys,
        containsAll(['starting', 'family', 'wealth']),
      );
    });

    test('keeps the module order of each segment', () {
      final starting = config.segments['starting']!;
      final wealth = config.segments['wealth']!;

      expect(starting.label, 'Estoy empezando');
      expect(starting.modules.map((module) => module.id), [
        'balance',
        'accounts',
        'actions',
        'promo',
        'movements',
        'services',
      ]);
      expect(wealth.modules.map((module) => module.type), [
        'totalBalance',
        'quickActions',
        'investmentSummary',
        'promoBanner',
        'accountCarousel',
        'recentMovements',
      ]);
    });

    test('hands module props through untouched when they are allowed', () {
      final wealth = config.segments['wealth']!;
      final balance = wealth.modules.first;
      final actions = wealth.modules[1].props['actions']! as List<Object?>;

      expect(balance.props, {'trendDays': 30, 'includesInvestments': true});
      expect(actions, hasLength(4));
    });

    test('reads feature flags and an idle resilience block', () {
      final starting = config.segments['starting']!;

      expect(starting.features.transfers, isTrue);
      expect(starting.features.partnerServices, isTrue);
      expect(config.resilience.latency, Duration.zero);
      expect(config.resilience.unavailableServices, isEmpty);
    });
  });

  group('unknown fields', () {
    test('are ignored at every level', () {
      final config = _accepted(
        _document(
          root: {'theme': 'dark', 'experiments': <Object?>[]},
          segment: {'audience': 12},
          modules: [
            _module(extra: {'badge': 'new'}),
          ],
        ),
      );

      expect(config.segments['starting']!.modules.single.id, 'balance');
    });
  });

  group('missing fields use their documented default', () {
    late HomeConfig config;

    setUp(() {
      config = _accepted({
        'schemaVersion': 1,
        'segments': {
          'starting': {
            'modules': [_module()],
          },
        },
      });
    });

    test('config version', () {
      expect(config.configVersion, ConfigDefaults.configVersion);
    });

    test('destinations', () {
      expect(config.destinations, isEmpty);
    });

    test('resilience', () {
      expect(config.resilience.latency, Duration.zero);
      expect(config.resilience.unavailableServices, isEmpty);
    });

    test('segment label falls back to the segment id', () {
      expect(config.segments['starting']!.label, 'starting');
    });

    test('feature flags are off', () {
      final features = config.segments['starting']!.features;

      expect(features.transfers, ConfigDefaults.featureEnabled);
      expect(features.partnerServices, ConfigDefaults.featureEnabled);
      expect(ConfigDefaults.featureEnabled, isFalse);
    });

    test('module visibility and props', () {
      final module = config.segments['starting']!.modules.single;

      expect(module.visible, ConfigDefaults.moduleVisible);
      expect(module.props, isEmpty);
    });

    test('a segment without modules is kept with an empty list', () {
      final sparse = _accepted({
        'schemaVersion': 1,
        'segments': {'starting': <String, Object?>{}},
      });

      expect(sparse.segments['starting']!.modules, isEmpty);
    });
  });

  group('wrong types use the default instead of failing', () {
    test('in root fields', () {
      final config = _accepted(
        _document(
          root: {
            'configVersion': 'fourteen',
            'destinations': 'transfer',
            'resilience': ['slow'],
          },
        ),
      );

      expect(config.configVersion, ConfigDefaults.configVersion);
      expect(config.destinations, isEmpty);
      expect(config.resilience.latency, Duration.zero);
    });

    test('in segment and module fields', () {
      final config = _accepted(
        _document(
          segment: {'label': 7, 'features': 'all'},
          modules: [
            _module(extra: {'visible': 'yes', 'props': <Object?>[]}),
          ],
        ),
      );
      final segment = config.segments['starting']!;

      expect(segment.label, 'starting');
      expect(segment.features.transfers, isFalse);
      expect(segment.modules.single.visible, isTrue);
      expect(segment.modules.single.props, isEmpty);
    });

    test('in feature flags', () {
      final config = _accepted(
        _document(
          segment: {
            'features': {'transfers': 1, 'partnerServices': true},
          },
        ),
      );
      final features = config.segments['starting']!.features;

      expect(features.transfers, isFalse);
      expect(features.partnerServices, isTrue);
    });

    test('a boolean sent as text or as a number is not taken as true', () {
      final config = _accepted(
        _document(
          segment: {
            'features': {'transfers': 'true', 'partnerServices': 1},
          },
          modules: [
            _module(extra: {'visible': 0}),
          ],
        ),
      );
      final segment = config.segments['starting']!;

      expect(segment.features.transfers, isFalse);
      expect(segment.features.partnerServices, isFalse);
      expect(segment.modules.single.visible, ConfigDefaults.moduleVisible);
    });

    test('a negative config version falls back to the default', () {
      final config = _accepted(_document(root: {'configVersion': -3}));

      expect(config.configVersion, ConfigDefaults.configVersion);
    });

    test('non-string destinations are left out of the allow-list', () {
      final config = _accepted(
        _document(
          root: {
            'destinations': ['transfer', 3, null, ''],
          },
        ),
      );

      expect(config.destinations, {'transfer'});
    });
  });

  group('malformed modules', () {
    test('are skipped without discarding the rest', () {
      final config = _accepted(
        _document(
          modules: [
            'balance',
            _module(id: null),
            _module(id: ''),
            _module(id: 'ghost', type: 9),
            _module(id: 'empty-type', type: ''),
            _module(id: 'accounts', type: 'accountCarousel'),
            null,
            _module(id: 'movements', type: 'recentMovements'),
          ],
        ),
      );

      expect(
        config.segments['starting']!.modules.map((module) => module.id),
        ['accounts', 'movements'],
      );
    });

    test('a repeated id keeps the first module only', () {
      final config = _accepted(
        _document(
          modules: [
            _module(),
            _module(type: 'accountCarousel'),
          ],
        ),
      );

      expect(
        config.segments['starting']!.modules.single.type,
        'totalBalance',
      );
    });

    test('an unknown module type is kept for the registry to decide', () {
      final config = _accepted(
        _document(
          modules: [_module(id: 'future', type: 'hologram')],
        ),
      );

      expect(config.segments['starting']!.modules.single.type, 'hologram');
    });
  });

  group('destinations outside the allow-list', () {
    test('drop the action from a list of actions', () {
      final config = _accepted(
        _document(
          modules: [
            _module(
              extra: {
                'props': {
                  'actions': [
                    {'label': 'Transferir', 'destination': 'transfer'},
                    {'label': 'Cripto', 'destination': 'crypto'},
                    {'label': 'Sin destino', 'destination': 42},
                    {'label': 'Más', 'destination': 'services'},
                  ],
                },
              },
            ),
          ],
        ),
      );
      final actions =
          config.segments['starting']!.modules.single.props['actions']!
              as List<Object?>;

      expect(actions.map((action) => (action! as Map)['label']), [
        'Transferir',
        'Más',
      ]);
    });

    test('remove a single action and keep the rest of the props', () {
      final config = _accepted(
        _document(
          modules: [
            _module(
              extra: {
                'props': {
                  'title': 'Invierte en cripto',
                  'action': {'label': 'Ver', 'destination': 'crypto'},
                },
              },
            ),
          ],
        ),
      );

      expect(config.segments['starting']!.modules.single.props, {
        'title': 'Invierte en cripto',
      });
    });

    test('are also dropped when nested deeper in the props', () {
      final config = _accepted(
        _document(
          modules: [
            _module(
              extra: {
                'props': {
                  'tabs': [
                    {
                      'title': 'Hoy',
                      'cta': {'destination': 'crypto'},
                    },
                  ],
                },
              },
            ),
          ],
        ),
      );
      final tabs =
          config.segments['starting']!.modules.single.props['tabs']!
              as List<Object?>;

      expect(tabs.single, {'title': 'Hoy'});
    });

    test('every action is dropped when the allow-list is missing', () {
      final config = _accepted({
        'schemaVersion': 1,
        'segments': {
          'starting': {
            'modules': [
              _module(
                extra: {
                  'props': {
                    'action': {'destination': 'transfer'},
                  },
                },
              ),
            ],
          },
        },
      });

      expect(config.segments['starting']!.modules.single.props, isEmpty);
    });
  });

  group('resilience block', () {
    HomeConfig withResilience(Map<String, Object?> resilience) =>
        _accepted(_document(root: {'resilience': resilience}));

    test('reads latency in milliseconds, whole or fractional', () {
      expect(
        withResilience({'latencyMs': 1500}).resilience.latency,
        const Duration(milliseconds: 1500),
      );
      expect(
        withResilience({'latencyMs': 250.0}).resilience.latency,
        const Duration(milliseconds: 250),
      );
    });

    test('never produces a negative latency', () {
      expect(
        withResilience({'latencyMs': -200}).resilience.latency,
        Duration.zero,
      );
    });

    test('caps latency so a bad publish cannot freeze the app', () {
      for (final latencyMs in [600000, 1e300]) {
        expect(
          withResilience({'latencyMs': latencyMs}).resilience.latency,
          ConfigDefaults.maxInjectedLatency,
          reason: 'latencyMs: $latencyMs',
        );
      }
    });

    test('a latency that is not a finite number injects none', () {
      final notFinite = <Object?>[
        double.nan,
        double.infinity,
        double.negativeInfinity,
        '1500',
        null,
      ];

      for (final latencyMs in notFinite) {
        expect(
          withResilience({'latencyMs': latencyMs}).resilience.latency,
          Duration.zero,
          reason: 'latencyMs: $latencyMs',
        );
      }
    });

    test('maps each flag to the service it takes down', () {
      final resilience = withResilience({
        'movementsUnavailable': true,
        'partnerInsuranceUnavailable': true,
      }).resilience;

      expect(resilience.isUnavailable(ServiceIds.movements), isTrue);
      expect(resilience.isUnavailable(ServiceIds.partnerInsurance), isTrue);
    });

    test('a flag that is not a boolean leaves the service up', () {
      final resilience = withResilience({
        'movementsUnavailable': 'true',
      }).resilience;

      expect(resilience.isUnavailable(ServiceIds.movements), isFalse);
    });
  });

  group('rejection', () {
    test('of a schema version newer than the supported one', () {
      expect(
        _rejection(
          _document(schemaVersion: HomeConfigParser.supportedSchemaVersion + 1),
        ),
        ConfigRejectionReason.unsupportedSchemaVersion,
      );
    });

    test('of a missing or unreadable schema version', () {
      for (final version in [null, '1', 1.5, 0, -1]) {
        expect(
          _rejection(_document(schemaVersion: version)),
          ConfigRejectionReason.invalidSchemaVersion,
          reason: 'schemaVersion: $version',
        );
      }
    });

    test('of a document that is not an object', () {
      for (final raw in [null, 3, 'config', <Object?>[], true]) {
        expect(
          _rejection(raw),
          ConfigRejectionReason.notAnObject,
          reason: 'raw: $raw',
        );
      }
    });

    test('of a document without a usable segment', () {
      final withoutSegments = <Object?>[
        {'schemaVersion': 1},
        {'schemaVersion': 1, 'segments': <String, Object?>{}},
        {'schemaVersion': 1, 'segments': 'starting'},
        {
          'schemaVersion': 1,
          'segments': {'starting': 'everything', 'wealth': null},
        },
      ];

      for (final raw in withoutSegments) {
        expect(
          _rejection(raw),
          ConfigRejectionReason.noUsableSegments,
          reason: 'raw: $raw',
        );
      }
    });

    test('of text that is not JSON', () {
      final result = const HomeConfigParser().parseJson('{not json');

      expect(
        (result as ConfigRejected).reason,
        ConfigRejectionReason.invalidJson,
      );
    });
  });

  group('props nested too deep', () {
    /// A props map whose `value` wraps a leaf in [levels] lists, so the leaf
    /// sits [levels] + 1 levels below the props themselves.
    Map<String, Object?> documentNesting(int levels) {
      Object? value = 'leaf';
      for (var level = 0; level < levels; level++) {
        value = [value];
      }
      return _document(
        modules: [
          _module(
            extra: {
              'props': {'value': value},
            },
          ),
        ],
      );
    }

    test('are accepted up to the limit', () {
      final config = _accepted(
        documentNesting(HomeConfigParser.maxPropsDepth - 1),
      );

      expect(
        config.segments['starting']!.modules.single.props,
        contains('value'),
      );
    });

    test('reject the document one level past the limit', () {
      expect(
        _rejection(documentNesting(HomeConfigParser.maxPropsDepth)),
        ConfigRejectionReason.propsTooDeep,
      );
    });

    test('reject a pathological document instead of overflowing the stack', () {
      expect(
        _rejection(documentNesting(20000)),
        ConfigRejectionReason.propsTooDeep,
      );
    });

    test('are rejected the same way when they arrive as JSON text', () {
      final result = const HomeConfigParser().parseJson(
        jsonEncode(documentNesting(HomeConfigParser.maxPropsDepth)),
      );

      expect(
        (result as ConfigRejected).reason,
        ConfigRejectionReason.propsTooDeep,
      );
    });
  });

  // The schema bounds what may be published; the reader applies the same
  // numbers as a ceiling on what it keeps, so an oversized document costs a
  // bounded amount of work and memory.
  group('reading limits', () {
    test('keeps the first destinations up to the limit', () {
      final config = _accepted(
        _document(
          root: {
            'destinations': [
              for (var i = 0; i < ConfigLimits.destinations + 5; i++) 'd$i',
            ],
          },
        ),
      );

      expect(config.destinations, hasLength(ConfigLimits.destinations));
      expect(config.destinations, contains('d0'));
      expect(
        config.destinations,
        isNot(contains('d${ConfigLimits.destinations}')),
      );
    });

    test('keeps the first modules of a segment up to the limit', () {
      final config = _accepted(
        _document(
          modules: [
            for (var i = 0; i < ConfigLimits.modulesPerSegment + 3; i++)
              _module(id: 'm$i'),
          ],
        ),
      );

      final modules = config.segments['starting']!.modules;
      expect(modules, hasLength(ConfigLimits.modulesPerSegment));
      expect(modules.first.id, 'm0');
      expect(modules.last.id, 'm${ConfigLimits.modulesPerSegment - 1}');
    });

    test('keeps the first segments up to the limit', () {
      final config = _accepted({
        'schemaVersion': 1,
        'segments': {
          for (var i = 0; i < ConfigLimits.segments + 2; i++)
            's$i': {
              'modules': [_module()],
            },
        },
      });

      expect(config.segments, hasLength(ConfigLimits.segments));
      expect(config.segments.keys.first, 's0');
      expect(
        config.segments.keys,
        isNot(contains('s${ConfigLimits.segments}')),
      );
    });

    test('skips a module whose id or type is longer than the limit', () {
      final tooLong = 'x' * (ConfigLimits.identifierLength + 1);
      final atLimit = 'y' * ConfigLimits.identifierLength;

      final config = _accepted(
        _document(
          modules: [
            _module(id: tooLong),
            _module(id: 'typed', type: tooLong),
            _module(id: atLimit),
          ],
        ),
      );

      expect(config.segments['starting']!.modules.map((m) => m.id), [atLimit]);
    });

    test('skips a segment whose id is longer than the limit', () {
      final tooLong = 's' * (ConfigLimits.segmentIdLength + 1);

      final config = _accepted({
        'schemaVersion': 1,
        'segments': {
          tooLong: {
            'modules': [_module()],
          },
          'starting': {
            'modules': [_module()],
          },
        },
      });

      expect(config.segments.keys, ['starting']);
    });
  });

  group('an error nobody anticipated', () {
    test('rejects the document instead of escaping the parser', () {
      expect(
        _rejection(_ExplodingMap()),
        ConfigRejectionReason.unreadable,
      );
    });
  });

  group('robustness', () {
    test('a segment that is not an object is skipped, the rest is kept', () {
      final config = _accepted({
        'schemaVersion': 1,
        'segments': {
          'broken': 12,
          'starting': {
            'modules': [_module()],
          },
        },
      });

      expect(config.segments.keys, ['starting']);
    });

    test('keys that are not strings do not break parsing', () {
      final config = _accepted({
        'schemaVersion': 1,
        7: 'seven',
        'segments': {
          3: {'modules': <Object?>[]},
          'starting': {
            'modules': [
              _module(
                extra: {
                  'props': {1: 'one', 'limit': 4},
                },
              ),
            ],
          },
        },
      });

      expect(config.segments.keys, ['starting']);
      expect(config.segments['starting']!.modules.single.props, {'limit': 4});
    });

    test('parsed props cannot be mutated by a caller', () {
      final config = _accepted(
        _document(
          modules: [
            _module(
              extra: {
                'props': {
                  'actions': [
                    {'destination': 'transfer'},
                  ],
                },
              },
            ),
          ],
        ),
      );
      final props = config.segments['starting']!.modules.single.props;
      final actions = props['actions']! as List<Object?>;

      expect(() => props['limit'] = 1, throwsUnsupportedError);
      expect(() => actions.add('x'), throwsUnsupportedError);
      expect(
        () => (actions.single! as Map<String, Object?>)['destination'] = 'x',
        throwsUnsupportedError,
      );
    });

    test('a document decoded from JSON parses like the same map', () {
      final document = _document();
      final fromJson = const HomeConfigParser().parseJson(jsonEncode(document));

      expect(fromJson, isA<ConfigAccepted>());
      expect(
        (fromJson as ConfigAccepted).config.segments.keys,
        _accepted(document).segments.keys,
      );
    });
  });

  group('segment selection', () {
    HomeConfig twoSegments({required List<String> ids}) => _accepted({
      'schemaVersion': 1,
      'segments': {
        for (final id in ids) id: {'modules': <Object?>[]},
      },
    });

    test('returns the requested segment when it exists', () {
      final config = twoSegments(ids: ['starting', 'wealth']);

      expect(config.segmentFor('wealth').id, 'wealth');
    });

    test('falls back to the default segment for an unknown or missing id', () {
      final config = twoSegments(ids: ['wealth', 'starting']);

      expect(config.segmentFor('platinum').id, HomeConfig.defaultSegmentId);
      expect(config.segmentFor(null).id, HomeConfig.defaultSegmentId);
    });

    test('falls back to the first id in order when the default is absent', () {
      final config = twoSegments(ids: ['wealth', 'family']);

      expect(config.segmentFor('platinum').id, 'family');
    });
  });
}

/// A map that fails on every access, standing in for any defect or input the
/// parser did not anticipate.
final class _ExplodingMap extends MapBase<Object?, Object?> {
  @override
  Object? operator [](Object? key) => throw StateError('unreadable');

  @override
  void operator []=(Object? key, Object? value) {}

  @override
  void clear() {}

  @override
  Iterable<Object?> get keys => const [];

  @override
  Object? remove(Object? key) => null;
}
