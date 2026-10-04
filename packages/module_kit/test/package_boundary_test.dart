import 'dart:io';

import 'package:app_platform/testing.dart';
import 'package:flutter_test/flutter_test.dart';

const _sourceRoot = 'lib/';

/// Every domain package depends on this one, so it holds the contract and
/// nothing else: no domain, no backend, no plugin, and not even the design
/// system or the platform package.
const _contract = ImportBoundary(
  package: 'module_kit',
  allowedPackages: {'flutter'},
);

void main() {
  test('the contract depends on nothing but the framework', () {
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
