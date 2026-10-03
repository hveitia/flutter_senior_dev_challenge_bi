import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Everything in `lib/src` outside the adapters has to stay testable without
/// a device, a plugin or a Firebase project. The rule is an allow-list, so a
/// plugin added later is rejected without anyone having to list it here.
const _allowedPackages = <String>{'app_platform', 'bloc'};
const _allowedDartLibraries = <String>{
  'dart:async',
  'dart:collection',
  'dart:convert',
  'dart:core',
  'dart:math',
};

const _sourceRoot = 'lib/src/';
const _adaptersDirectory = 'lib/src/adapters/';
const _adaptersBarrel = 'package:app_platform/adapters.dart';

/// A whole `import`, `export` or `part` directive, wherever it starts on its
/// line and however many lines it spans.
final _directive = RegExp(
  r'^[ \t]*(?:import|export|part)\b[^;]*;',
  multiLine: true,
);

/// Every quoted URI inside a directive, conditional imports included.
final _uri = RegExp('''['"]([^'"]+)['"]''');

/// The URIs that the pure file at [path] must not reference.
List<String> forbiddenUris(String path, String source) {
  return [
    for (final directive in _directive.allMatches(source))
      for (final uri in _uri.allMatches(directive.group(0)!))
        if (!_isAllowed(path, uri.group(1)!)) uri.group(1)!,
  ];
}

bool _isAllowed(String path, String uri) {
  if (uri.startsWith('dart:')) return _allowedDartLibraries.contains(uri);

  if (uri.startsWith('package:')) {
    if (uri == _adaptersBarrel) return false;
    final package = uri.substring('package:'.length).split('/').first;
    return _allowedPackages.contains(package) &&
        !_pointsIntoAdapters(uri.replaceFirst('package:app_platform/', 'lib/'));
  }

  final resolved = Uri.file(path).resolve(uri).path;
  return !_pointsIntoAdapters(resolved);
}

bool _pointsIntoAdapters(String path) => path.startsWith(_adaptersDirectory);

void main() {
  group('pure code', () {
    test('references nothing outside the allow-list', () {
      final sources = Directory(_sourceRoot)
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .where((file) => !file.path.startsWith(_adaptersDirectory))
          .toList();

      final offenders = {
        for (final file in sources)
          if (forbiddenUris(file.path, file.readAsStringSync()).isNotEmpty)
            file.path: forbiddenUris(file.path, file.readAsStringSync()),
      };

      expect(sources, isNotEmpty);
      expect(offenders, isEmpty);
    });

    test('the public barrel does not export adapters', () {
      final barrel = File('lib/app_platform.dart').readAsStringSync();

      expect(barrel, isNot(contains('src/adapters/')));
    });
  });

  group('the boundary check', () {
    const path = 'lib/src/config/example.dart';

    test('accepts the Dart libraries and packages on the allow-list', () {
      const source = '''
import 'dart:async';
import 'package:app_platform/src/config/home_config.dart';
import 'package:bloc/bloc.dart';
import 'home_config.dart';
export '../resilience/failure.dart';
''';

      expect(forbiddenUris(path, source), isEmpty);
    });

    test('rejects Flutter, Firebase and plugins', () {
      const source = '''
import 'package:flutter/widgets.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
''';

      expect(forbiddenUris(path, source), hasLength(3));
    });

    test('rejects dart:ui and dart:io', () {
      const source = "import 'dart:ui';\nimport 'dart:io';";

      expect(forbiddenUris(path, source), ['dart:ui', 'dart:io']);
    });

    test('sees a directive that is indented or split across lines', () {
      const source = '''
  import 'package:flutter/foundation.dart';
import
    "package:firebase_core/firebase_core.dart"
    show Firebase;
''';

      expect(forbiddenUris(path, source), [
        'package:flutter/foundation.dart',
        'package:firebase_core/firebase_core.dart',
      ]);
    });

    test('sees exports and part files', () {
      const source = '''
export 'package:flutter/material.dart';
part '../adapters/firebase_telemetry.dart';
''';

      expect(forbiddenUris(path, source), hasLength(2));
    });

    test('sees the alternatives of a conditional import', () {
      const source = '''
import 'stub.dart'
    if (dart.library.ui) 'package:flutter/services.dart';
''';

      expect(forbiddenUris(path, source), ['package:flutter/services.dart']);
    });

    test('rejects any route into the adapters', () {
      const source = '''
import '../adapters/firestore_config_source.dart';
import 'package:app_platform/src/adapters/bundled_config.dart';
import 'package:app_platform/adapters.dart';
''';

      expect(forbiddenUris(path, source), hasLength(3));
    });

    test('ignores a directive that is commented out', () {
      const source = "// import 'package:flutter/widgets.dart';";

      expect(forbiddenUris(path, source), isEmpty);
    });
  });
}
