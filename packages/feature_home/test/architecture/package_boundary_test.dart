import 'dart:io';

import 'package:app_platform/testing.dart';
import 'package:flutter_test/flutter_test.dart';

const _sourceRoot = 'lib/';

/// The home knows the platform, the design system and the module contract.
/// It knows no other domain package, no backend and no device plugin: what
/// it shows reaches it through the registry.
const _home = ImportBoundary(
  package: 'feature_home',
  allowedPackages: {
    'app_platform',
    'bloc',
    'design_system',
    'equatable',
    'flutter',
    'flutter_bloc',
    'module_kit',
  },
  closedLibraries: {'package:app_platform/adapters.dart'},
);

void main() {
  test('the home depends on no other domain, backend or plugin', () {
    final files = Directory(_sourceRoot)
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .toList();
    expect(files, isNotEmpty);

    final offenders = {
      for (final file in files)
        if (_home.forbiddenUris(file.path, file.readAsStringSync())
            case final forbidden when forbidden.isNotEmpty)
          file.path: forbidden,
    };

    expect(offenders, isEmpty);
  });
}
