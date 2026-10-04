import 'package:feature_services/src/ports.dart';
import 'package:flutter/widgets.dart';

/// A [MiniAppSurface] that loads nothing and records what it was asked. The
/// test plays the page through [events].
final class FakeMiniAppSurface implements MiniAppSurface {
  FakeMiniAppSurface(this.events);

  /// Identifies the widget that stands for the page.
  static const Key pageKey = ValueKey('mini-app-page');

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

/// A [MiniAppData] that counts how many times it was cleared.
final class FakeMiniAppData implements MiniAppData {
  int clears = 0;

  @override
  Future<void> clear() async => clears++;
}
