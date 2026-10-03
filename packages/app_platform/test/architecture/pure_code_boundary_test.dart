import 'dart:io';

import 'package:app_platform/testing.dart';
import 'package:flutter_test/flutter_test.dart';

const _sourceRoot = 'lib/src/';
const _adaptersDirectory = 'lib/src/adapters/';

/// Everything in `lib/src` outside the adapters has to stay testable without
/// a device, a plugin or a Firebase project.
const _pure = ImportBoundary(
  package: 'app_platform',
  allowedPackages: {'bloc'},
  closedDirectories: {_adaptersDirectory},
  closedLibraries: {'package:app_platform/adapters.dart'},
);

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
          if (_pure
              .forbiddenUris(file.path, file.readAsStringSync())
              .isNotEmpty)
            file.path: _pure.forbiddenUris(file.path, file.readAsStringSync()),
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

      expect(_pure.forbiddenUris(path, source), isEmpty);
    });

    test('rejects Flutter, Firebase and plugins', () {
      const source = '''
import 'package:flutter/widgets.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
''';

      expect(_pure.forbiddenUris(path, source), hasLength(3));
    });

    test('rejects dart:ui and dart:io', () {
      const source = "import 'dart:ui';\nimport 'dart:io';";

      expect(_pure.forbiddenUris(path, source), ['dart:ui', 'dart:io']);
    });

    test('sees a directive that is indented or split across lines', () {
      const source = '''
  import 'package:flutter/foundation.dart';
import
    "package:firebase_core/firebase_core.dart"
    show Firebase;
''';

      expect(_pure.forbiddenUris(path, source), [
        'package:flutter/foundation.dart',
        'package:firebase_core/firebase_core.dart',
      ]);
    });

    test('sees exports and part files', () {
      const source = '''
export 'package:flutter/material.dart';
part '../adapters/firebase_telemetry.dart';
''';

      expect(_pure.forbiddenUris(path, source), hasLength(2));
    });

    test('sees the alternatives of a conditional import', () {
      const source = '''
import 'stub.dart'
    if (dart.library.ui) 'package:flutter/services.dart';
''';

      expect(_pure.forbiddenUris(path, source), [
        'package:flutter/services.dart',
      ]);
    });

    test('rejects any route into the adapters', () {
      const source = '''
import '../adapters/firestore_config_source.dart';
import 'package:app_platform/src/adapters/bundled_config.dart';
import 'package:app_platform/adapters.dart';
''';

      expect(_pure.forbiddenUris(path, source), hasLength(3));
    });

    test('ignores a directive that is commented out', () {
      const source = "// import 'package:flutter/widgets.dart';";

      expect(_pure.forbiddenUris(path, source), isEmpty);
    });
  });
}
