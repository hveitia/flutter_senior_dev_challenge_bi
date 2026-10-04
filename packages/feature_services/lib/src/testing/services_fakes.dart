import 'package:feature_services/src/data/stepwise_mini_app_data.dart';
import 'package:feature_services/src/ports.dart';
import 'package:flutter/widgets.dart';

/// A [MiniAppSurface] that loads nothing and records what it was asked. The
/// test plays the page through [events].
final class FakeMiniAppSurface implements MiniAppSurface {
  FakeMiniAppSurface(this.events, {this.loadError});

  /// Identifies the widget that stands for the page.
  static const Key pageKey = ValueKey('mini-app-page');

  /// A page on the origin the tests use for partners. Tests give it as the
  /// place a message was posted from.
  static final Uri partnerPage = Uri.parse(
    'https://partners.example.com/partners/travel-insurance',
  );

  /// What the container listens with. A test calls it as the page would.
  final MiniAppEvents events;

  /// Every address loaded, in order.
  final List<Uri> loaded = [];

  /// Every message delivered to the page, with the origin it was meant for.
  final List<({String json, String targetOrigin})> posted = [];

  /// Thrown by the next [load], once.
  Object? loadError;

  @override
  Widget build(BuildContext context) => const SizedBox.expand(key: pageKey);

  @override
  Future<void> load(Uri address) async {
    loaded.add(address);
    final error = loadError;
    if (error != null) {
      loadError = null;
      // Whatever the plugin throws reaches the container as an object.
      // ignore: only_throw_errors
      throw error;
    }
  }

  @override
  Future<void> postToPage(String json, {required String targetOrigin}) async {
    posted.add((json: json, targetOrigin: targetOrigin));
  }
}

/// An [ExternalLinks] that opens nothing and records what it was asked.
final class FakeExternalLinks implements ExternalLinks {
  FakeExternalLinks({this.opens = true});

  /// What [open] answers.
  bool opens;

  final List<Uri> opened = [];

  @override
  Future<bool> open(Uri address) async {
    opened.add(address);
    return opens;
  }
}

/// A [MiniAppData] that counts how many times it was asked to clear.
final class FakeMiniAppData implements MiniAppData {
  int clears = 0;
  int pendingChecks = 0;

  /// When set, [clearIfPending] ends with this error.
  Object? pendingFailsWith;

  @override
  Future<void> clear() async => clears++;

  @override
  Future<void> clearIfPending() async {
    pendingChecks++;
    final error = pendingFailsWith;
    // Whatever a clean-up throws reaches the container as an object.
    // ignore: only_throw_errors
    if (error != null) throw error;
  }
}

/// A [PendingCleanUp] kept in memory, recording every value it was given.
final class InMemoryPendingCleanUp implements PendingCleanUp {
  InMemoryPendingCleanUp({bool pending = false}) : _pending = pending;

  bool _pending;

  /// Every value written, in order.
  final List<bool> writes = [];

  @override
  Future<bool> isPending() async => _pending;

  @override
  Future<void> setPending({required bool pending}) async {
    _pending = pending;
    writes.add(pending);
  }
}
