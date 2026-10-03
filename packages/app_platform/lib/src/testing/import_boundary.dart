/// What the Dart files of one layer of a package may reference.
///
/// The rule is an allow-list, so a plugin added later is rejected without
/// anyone having to list it. Architecture tests read the files of a layer
/// and ask [forbiddenUris] for each one.
final class ImportBoundary {
  const ImportBoundary({
    required this.package,
    this.allowedPackages = const {},
    this.allowedDartLibraries = pureDartLibraries,
    this.closedDirectories = const {},
    this.closedLibraries = const {},
  });

  /// Dart libraries that need neither a device nor a UI.
  static const Set<String> pureDartLibraries = {
    'dart:async',
    'dart:collection',
    'dart:convert',
    'dart:core',
    'dart:math',
  };

  /// The package the checked files belong to. It may always reference
  /// itself, except through [closedDirectories] and [closedLibraries].
  final String package;

  /// Other packages the layer may depend on.
  final Set<String> allowedPackages;

  final Set<String> allowedDartLibraries;

  /// Directories of [package] the layer may not reach, written from the
  /// package root and ending in a slash: `lib/src/adapters/`.
  final Set<String> closedDirectories;

  /// Whole libraries the layer may not import, as `package:` URIs. Used for
  /// barrels that re-export a closed directory.
  final Set<String> closedLibraries;

  /// A whole `import`, `export` or `part` directive, wherever it starts on
  /// its line and however many lines it spans.
  static final RegExp _directive = RegExp(
    r'^[ \t]*(?:import|export|part)\b[^;]*;',
    multiLine: true,
  );

  /// Every quoted URI inside a directive, conditional imports included.
  static final RegExp _uri = RegExp('''['"]([^'"]+)['"]''');

  /// The URIs that the file at [path], written from the package root, must
  /// not reference. Empty when [source] stays inside the boundary.
  List<String> forbiddenUris(String path, String source) {
    return [
      for (final directive in _directive.allMatches(source))
        for (final uri in _uri.allMatches(directive.group(0)!))
          if (!_isAllowed(path, uri.group(1)!)) uri.group(1)!,
    ];
  }

  bool _isAllowed(String path, String uri) {
    if (uri.startsWith('dart:')) return allowedDartLibraries.contains(uri);

    if (uri.startsWith(_packageScheme)) {
      if (closedLibraries.contains(uri)) return false;

      final name = uri.substring(_packageScheme.length).split('/').first;
      if (name != package) return allowedPackages.contains(name);
      return !_isClosed(uri.replaceFirst('$_packageScheme$package/', 'lib/'));
    }

    return !_isClosed(Uri.file(path).resolve(uri).path);
  }

  bool _isClosed(String path) => closedDirectories.any(path.startsWith);

  static const String _packageScheme = 'package:';
}
