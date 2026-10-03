/// Why an operation against a backend did not produce a value.
///
/// Repositories return these instead of letting plugin exceptions reach a
/// Bloc, so every screen handles the same four cases.
sealed class AppFailure implements Exception {
  const AppFailure();
}

/// The device has no connection. Not retried: the caller shows cached data.
final class OfflineFailure extends AppFailure {
  const OfflineFailure();
}

/// The operation did not answer in time, after every attempt.
final class TimeoutFailure extends AppFailure {
  const TimeoutFailure();
}

/// The backend answered that it cannot serve the request right now.
final class ServiceUnavailableFailure extends AppFailure {
  const ServiceUnavailableFailure([this.serviceId]);

  final String? serviceId;
}

/// Anything else. It points at a defect, so it is never retried.
final class UnexpectedFailure extends AppFailure {
  const UnexpectedFailure(this.cause, this.stackTrace);

  final Object cause;
  final StackTrace stackTrace;
}

/// Outcome of an operation run through the resilience policy.
sealed class Result<T> {
  const Result();
}

final class Success<T> extends Result<T> {
  const Success(this.value);

  final T value;
}

final class Failed<T> extends Result<T> {
  const Failed(this.failure);

  final AppFailure failure;
}
