import 'dart:io';

import 'package:app_platform/testing.dart';
import 'package:flutter_test/flutter_test.dart';

const _sourceRoot = 'lib/src/';
const _domainDirectory = 'lib/src/domain/';
const _adaptersDirectory = 'lib/src/adapters/';

/// Entities, the repository contract and the rules about movements. Plain
/// Dart: they know nothing of how the data is stored or shown.
const _domain = ImportBoundary(
  package: 'feature_accounts',
  allowedPackages: {'app_platform', 'equatable'},
  closedDirectories: {
    _adaptersDirectory,
    'lib/src/data/',
    'lib/src/presentation/',
    'lib/src/testing/',
  },
  closedLibraries: {'package:app_platform/adapters.dart'},
);

/// Everything except the adapters: it may use Flutter and the workspace
/// packages, and reaches Firestore and device storage only through the
/// ports the adapters implement.
const _outsideAdapters = ImportBoundary(
  package: 'feature_accounts',
  allowedPackages: {
    'app_platform',
    'bloc',
    'design_system',
    'equatable',
    'flutter',
    'flutter_bloc',
    'go_router',
    'module_kit',
  },
  closedDirectories: {_adaptersDirectory},
  closedLibraries: {
    'package:feature_accounts/adapters.dart',
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
  test('the domain depends on Dart, equatable and the platform only', () {
    expect(Directory(_domainDirectory).listSync(recursive: true), isNotEmpty);
    expect(offenders(_domain, _domainDirectory), isEmpty);
  });

  test('nothing outside the adapters reaches Firestore or a plugin', () {
    expect(
      offenders(_outsideAdapters, _sourceRoot, except: _adaptersDirectory),
      isEmpty,
    );
  });

  test('the public barrel does not export the adapters', () {
    final barrel = File('lib/feature_accounts.dart').readAsStringSync();
    final exportsOfAdapters = RegExp(
      r'^\s*export\b[^;]*adapters[^;]*;',
      multiLine: true,
    ).allMatches(barrel);

    expect(exportsOfAdapters, isEmpty);
  });

  test('no feature depends on another feature', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final otherFeatures = RegExp(
      r'^\s+feature_\w+:',
      multiLine: true,
    ).allMatches(pubspec);

    expect(otherFeatures, isEmpty);
  });
}
