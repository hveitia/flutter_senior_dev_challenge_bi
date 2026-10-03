import 'package:app_platform/src/config/config_repository.dart';

/// A [ConfigSource] fed by a stream the test controls.
final class StreamConfigSource implements ConfigSource {
  const StreamConfigSource(this._documents);

  final Stream<Object?> _documents;

  @override
  Stream<Object?> watch() => _documents;
}

/// A [ConfigStore] that keeps the document in memory.
final class InMemoryConfigStore implements ConfigStore {
  InMemoryConfigStore({this.document});

  String? document;

  @override
  Future<String?> read() async => document;

  @override
  Future<void> write(String document) async => this.document = document;
}
