import 'dart:async';

import 'package:app_platform/app_platform.dart';
import 'package:feature_notifications/src/data/ports.dart';
import 'package:feature_notifications/src/domain/inbox_item.dart';
import 'package:feature_notifications/src/domain/notifications_repository.dart';
import 'package:feature_notifications/src/notifications_telemetry.dart';

/// [NotificationsRepository] over a source that listens in real time.
///
/// The source's own saved copy is the cache. Reads and marking as read go
/// through the resilience policy as the service `notifications`, so the
/// inbox fails and recovers on its own, apart from accounts and movements.
final class DefaultNotificationsRepository implements NotificationsRepository {
  DefaultNotificationsRepository({
    required InboxSource source,
    required ResiliencePolicy policy,
    Telemetry telemetry = const NoopTelemetry(),
    this.limit = defaultLimit,
  }) : _source = source,
       _policy = policy,
       _telemetry = telemetry;

  /// How many notifications the inbox shows, newest first. An inbox is read
  /// from the top; older ones stay on the server.
  static const int defaultLimit = 50;

  static const String _service = NotificationsTelemetry.service;

  final InboxSource _source;
  final ResiliencePolicy _policy;
  final Telemetry _telemetry;
  final int limit;

  @override
  Stream<InboxSnapshot> watchInbox() {
    // A service the resilience lab took down does not deliver through its
    // listener either, and comes back when the fault is lifted.
    late final StreamController<InboxSnapshot> controller;
    StreamSubscription<InboxSnapshot>? source;
    StreamSubscription<void>? faults;
    InboxSnapshot? latest;
    var isDown = false;

    void onDelivery(InboxSnapshot delivery) {
      latest = delivery;
      isDown = _policy.isTakenDown(_service);
      if (isDown) {
        controller.addError(const ServiceUnavailableFailure(_service));
      } else {
        controller.add(delivery);
      }
    }

    void onFaultsChanged() {
      final wasDown = isDown;
      isDown = _policy.isTakenDown(_service);
      if (isDown == wasDown) return;

      if (isDown) {
        controller.addError(const ServiceUnavailableFailure(_service));
      } else if (latest case final delivery?) {
        controller.add(delivery);
      }
    }

    controller = StreamController<InboxSnapshot>(
      onListen: () {
        faults = _policy.faultChanges.listen((_) => onFaultsChanged());
        source = _source
            .watch(limit: limit)
            .listen(
              onDelivery,
              onError: controller.addError,
              onDone: controller.close,
            );
      },
      onCancel: () async {
        await Future.wait([?source?.cancel(), ?faults?.cancel()]);
      },
    );
    return controller.stream;
  }

  @override
  Future<Result<InboxSnapshot>> refreshInbox() async {
    // Reading is safe to repeat, so the policy may retry it.
    final result = await _policy.run(
      () => _source.fetch(limit: limit),
      idempotent: true,
      serviceId: _service,
    );
    if (result case Failed(:final failure)) _report(failure);
    return result;
  }

  @override
  Future<Result<void>> markRead(String id) async {
    // Marking as read twice leaves it read, so it may be retried.
    final result = await _policy.run(
      () => _source.markRead(id),
      idempotent: true,
      serviceId: _service,
    );
    if (result case Failed(:final failure)) _report(failure);
    return result;
  }

  void _report(AppFailure failure) {
    _telemetry.event(
      NotificationsTelemetry.loadFailed,
      parameters: {NotificationsTelemetry.reasonKey: reasonOf(failure)},
    );
    if (failure is UnexpectedFailure) {
      // The message may quote a notification, so only its type is reported.
      _telemetry.recordError(
        RedactedError(failure.cause.runtimeType),
        failure.stackTrace,
        reason: NotificationsTelemetry.unexpectedError,
      );
    }
  }

  /// The failure as a word for reports.
  static String reasonOf(AppFailure failure) => switch (failure) {
    OfflineFailure() => 'offline',
    TimeoutFailure() => 'timeout',
    ServiceUnavailableFailure() => 'unavailable',
    UnexpectedFailure() => 'unexpected',
  };
}
