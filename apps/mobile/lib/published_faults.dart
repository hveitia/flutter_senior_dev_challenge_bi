import 'dart:async';

import 'package:app_platform/app_platform.dart';

/// The faults of the resilience lab as the configuration in use publishes
/// them. The resilience policy reads [current] on every attempt.
///
/// The policy is built when the app starts, long before a customer signs in
/// and the configuration can be read, so the two meet here. A build that
/// does not allow fault injection never looks at it.
final class PublishedFaults {
  /// What the policy applies right now.
  ResilienceSettings current = ResilienceSettings.none;

  StreamSubscription<RemoteConfigState>? _subscription;

  /// Keeps [current] equal to what [config] publishes, starting with the
  /// configuration it already has.
  void follow(RemoteConfigCubit config) {
    unawaited(_subscription?.cancel());
    _take(config.state);
    _subscription = config.stream.listen(_take);
  }

  void _take(RemoteConfigState state) {
    current = state.config?.resilience ?? ResilienceSettings.none;
  }

  /// Stops following and lifts every fault: outside a signed-in session
  /// nothing is published to this device.
  Future<void> stop() async {
    final subscription = _subscription;
    _subscription = null;
    // Lifted before waiting, so nothing run meanwhile sees a stale fault.
    current = ResilienceSettings.none;
    await subscription?.cancel();
  }
}
