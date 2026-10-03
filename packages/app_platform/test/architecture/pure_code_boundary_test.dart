import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Packages that only adapters may import. Everything else in `lib/src` has to
/// stay testable without a device, a plugin or a Firebase project.
const _adapterOnlyPackages = <String>[
  'package:flutter/',
  'package:cloud_firestore/',
  'package:connectivity_plus/',
  'package:firebase_analytics/',
  'package:firebase_core/',
  'package:firebase_crashlytics/',
  'package:firebase_performance/',
  'package:shared_preferences/',
];

const _adaptersDirectory = 'lib/src/adapters/';

void main() {
  test('only adapters import Flutter, Firebase or plugins', () {
    final offenders = <String>[];

    final sourceRoot = Directory('lib/src');
    final sources =
        (sourceRoot.existsSync()
                ? sourceRoot.listSync(recursive: true)
                : <FileSystemEntity>[])
            .whereType<File>()
            .where((file) => file.path.endsWith('.dart'))
            .where((file) => !file.path.startsWith(_adaptersDirectory));

    for (final file in sources) {
      for (final line in file.readAsLinesSync()) {
        final isImport =
            line.startsWith('import ') || line.startsWith('export ');
        if (!isImport) continue;
        if (_adapterOnlyPackages.any(line.contains)) {
          offenders.add('${file.path}: $line');
        }
      }
    }

    expect(offenders, isEmpty);
  });

  test('the public barrel does not export adapters', () {
    final barrel = File('lib/app_platform.dart').readAsStringSync();

    expect(barrel, isNot(contains('src/adapters/')));
  });
}
