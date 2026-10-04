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
  ResilienceSettings get current => _current;
  ResilienceSettings _current = ResilienceSettings.none;

  /// Called when [current] changes, so whatever is live can look again at
  /// once instead of at its next attempt.
  void Function()? onChanged;

  StreamSubscription<RemoteConfigState>? _following;

  /// Keeps [current] equal to what [config] publishes, starting with the
  /// configuration it already has. Returns how to stop.
  ///
  /// Stopping lifts every fault, since outside a signed-in session nothing
  /// is published to this device; but only while this is still the
  /// configuration being followed. A follower that was already replaced by
  /// the next customer's stops without touching what that one set.
  Future<void> Function() follow(RemoteConfigCubit config) {
    unawaited(_following?.cancel());
    final following = config.stream.listen(_take);
    _following = following;
    _take(config.state);

    return () async {
      if (identical(_following, following)) {
        _following = null;
        // Lifted before waiting, so nothing run meanwhile sees a stale
        // fault.
        _set(ResilienceSettings.none);
      }
      await following.cancel();
    };
  }

  void _take(RemoteConfigState state) =>
      _set(state.config?.resilience ?? ResilienceSettings.none);

  void _set(ResilienceSettings next) {
    final previous = _current;
    final unchanged =
        next.latency == previous.latency &&
        next.unavailableServices.length ==
            previous.unavailableServices.length &&
        next.unavailableServices.containsAll(previous.unavailableServices);
    _current = next;
    if (!unchanged) onChanged?.call();
  }
}
