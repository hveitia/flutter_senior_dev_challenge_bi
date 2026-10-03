import 'dart:io';

import 'package:app_platform/testing.dart';
import 'package:flutter_test/flutter_test.dart';

const _sourceRoot = 'lib/src/';
const _domainDirectory = 'lib/src/domain/';
const _adaptersDirectory = 'lib/src/adapters/';

/// The rules of the feature: entities, the repository contract and the
/// validators. Plain Dart, so they run and are tested without Flutter, and
/// they know nothing of how they are stored or shown.
const _domain = ImportBoundary(
  package: 'feature_auth',
  allowedPackages: {'equatable'},
  closedDirectories: {
    _adaptersDirectory,
    'lib/src/data/',
    'lib/src/presentation/',
    'lib/src/testing/',
  },
);

/// Everything except the adapters: it may use Flutter and the workspace
/// packages, and reaches Firebase and device plugins only through the ports
/// the adapters implement.
const _outsideAdapters = ImportBoundary(
  package: 'feature_auth',
  allowedPackages: {
    'app_platform',
    'bloc',
    'design_system',
    'equatable',
    'flutter',
    'flutter_bloc',
    'go_router',
  },
  closedDirectories: {_adaptersDirectory},
  closedLibraries: {
    'package:feature_auth/adapters.dart',
    'package:app_platform/adapters.dart',
  },
);

/// The files under [directory] that break [boundary], with what each one
/// references that it should not.
Map<String, List<String>> offenders(
  ImportBoundary boundary,
  String directory, {
  String? except,
}) {
  final files = Directory(directory)
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .where((file) => except == null || !file.path.startsWith(except));

  return {
    for (final file in files)
      if (boundary.forbiddenUris(file.path, file.readAsStringSync())
          case final forbidden when forbidden.isNotEmpty)
        file.path: forbidden,
  };
}

void main() {
  test('the domain depends on Dart and equatable only', () {
    expect(Directory(_domainDirectory).listSync(recursive: true), isNotEmpty);
    expect(offenders(_domain, _domainDirectory), isEmpty);
  });

  test('nothing outside the adapters reaches Firebase or a plugin', () {
    expect(
      offenders(_outsideAdapters, _sourceRoot, except: _adaptersDirectory),
      isEmpty,
    );
  });

  test('the public barrel does not export the adapters', () {
    final barrel = File('lib/feature_auth.dart').readAsStringSync();

    expect(barrel, isNot(contains('src/adapters/')));
    expect(barrel, isNot(contains('src/data/')));
  });

  group('the boundaries see', () {
    test('Flutter or Firebase in the domain', () {
      const source = '''
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:feature_auth/src/data/ports.dart';
''';

      expect(
        _domain.forbiddenUris('${_domainDirectory}session.dart', source),
        hasLength(3),
      );
    });

    test('a plugin or an adapter in the presentation', () {
      const source = '''
import 'package:local_auth/local_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:feature_auth/adapters.dart';
import '../../adapters/device_unlock.dart';
import 'package:flutter/material.dart';
''';

      expect(
        _outsideAdapters.forbiddenUris(
          'lib/src/presentation/login/login_screen.dart',
          source,
        ),
        hasLength(4),
      );
    });
  });
}
