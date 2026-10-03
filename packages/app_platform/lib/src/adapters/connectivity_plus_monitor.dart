import 'package:app_platform/src/connectivity/connectivity_cubit.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Reads the device's network state.
///
/// The plugin reports that a network is attached, not that the internet is
/// reachable. A network without internet shows up through the resilience
/// policy instead, as timeouts.
final class ConnectivityPlusMonitor implements ConnectivityMonitor {
  const ConnectivityPlusMonitor(this._connectivity);

  final Connectivity _connectivity;

  @override
  Future<bool> isOnline() async =>
      _hasConnection(await _connectivity.checkConnectivity());

  @override
  Stream<bool> get onlineChanges =>
      _connectivity.onConnectivityChanged.map(_hasConnection).distinct();

  bool _hasConnection(List<ConnectivityResult> results) =>
      results.any((result) => result != ConnectivityResult.none);
}
