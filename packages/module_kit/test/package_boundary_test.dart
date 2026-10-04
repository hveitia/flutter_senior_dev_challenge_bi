import 'dart:io';

import 'package:app_platform/testing.dart';
import 'package:flutter_test/flutter_test.dart';

const _sourceRoot = 'lib/';

/// Every domain package depends on this one, so it must depend on none of
/// them, nor on a backend or a device plugin.
const _contract = ImportBoundary(
  package: 'module_kit',
  allowedPackages: {'app_platform', 'design_system', 'flutter', 'flutter_bloc'},
  closedLibraries: {'package:app_platform/adapters.dart'},
);

void main() {
  test('the contract depends on no domain, backend or plugin', () {
    final files = Directory(_sourceRoot)
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .toList();
    expect(files, isNotEmpty);

    final offenders = {
      for (final file in files)
        if (_contract.forbiddenUris(file.path, file.readAsStringSync())
            case final forbidden when forbidden.isNotEmpty)
          file.path: forbidden,
    };

    expect(offenders, isEmpty);
  });
}
