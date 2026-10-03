import 'dart:async';

import 'package:app_platform/src/config/config_repository.dart';

/// A [ConfigSource] the test drives. Every [watch] opens a new stream, as a
/// real source does when the repository subscribes again after a failure.
final class FakeConfigSource implements ConfigSource {
  StreamController<Object?>? _current;

  /// How many times the repository has subscribed.
  int subscriptions = 0;

  /// Whether the stream opened last still has its listener.
  bool get hasListener => _current?.hasListener ?? false;

  @override
  Stream<Object?> watch() {
    subscriptions++;
    final controller = StreamController<Object?>();
    _current = controller;
    return controller.stream;
  }

  /// Emits [document] on the stream opened last.
  void publish(Object? document) => _current!.add(document);

  /// Makes the stream opened last fail, like a denied or dropped listener.
  void fail(Object error) => _current!.addError(error, StackTrace.current);

  /// Ends the stream opened last without an error.
  void complete() => unawaited(_current!.close());
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
