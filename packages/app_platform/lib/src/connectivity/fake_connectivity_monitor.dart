import 'dart:async';

import 'package:app_platform/src/connectivity/connectivity_cubit.dart';

/// A [ConnectivityMonitor] the test drives by hand.
final class FakeConnectivityMonitor implements ConnectivityMonitor {
  FakeConnectivityMonitor({this.online = true});

  /// What [isOnline] answers.
  bool online;

  final StreamController<bool> _changes = StreamController<bool>.broadcast();

  bool get hasListener => _changes.hasListener;

  void emit({required bool online}) {
    this.online = online;
    _changes.add(online);
  }

  @override
  Future<bool> isOnline() async => online;

  @override
  Stream<bool> get onlineChanges => _changes.stream;
}
