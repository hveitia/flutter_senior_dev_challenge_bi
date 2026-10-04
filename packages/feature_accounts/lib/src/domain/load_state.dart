import 'package:app_platform/app_platform.dart';
import 'package:equatable/equatable.dart';
import 'package:feature_accounts/src/domain/data_snapshot.dart';

/// Why a data set could not be brought up to date, as the screens need it.
enum LoadFailure {
  offline,
  timeout,
  unavailable,
  unexpected
  ;

  /// The kind of [failure].
  static LoadFailure of(AppFailure failure) => switch (failure) {
    OfflineFailure() => offline,
    TimeoutFailure() => timeout,
    ServiceUnavailableFailure() => unavailable,
    UnexpectedFailure() => unexpected,
  };

  /// Whether every allowed attempt was made before giving up. Only these
  /// two kinds are retried by the resilience policy.
  bool get attemptsExhausted => this == timeout || this == unavailable;
}

/// What is known about one data set: the last value it can show, where
/// that value came from, and whether bringing it up to date is in progress
/// or failed.
///
/// Showing saved data and failing to refresh it are independent facts, so
/// they are kept apart instead of being squeezed into one status.
final class LoadState<T> extends Equatable {
  const LoadState({
    this.data,
    this.origin,
    this.syncedAt,
    this.failure,
    this.isLoading = false,
  });

  final T? data;
  final DataOrigin? origin;
  final DateTime? syncedAt;
  final LoadFailure? failure;
  final bool isLoading;

  bool get hasData => data != null;

  /// Nothing to show yet and nothing has failed: draw the skeleton.
  bool get isWaiting => !hasData && failure == null;

  /// Nothing to show because loading failed: draw the error.
  bool get hasFailed => !hasData && failure != null;

  /// There is something to show, but it could not be brought up to date.
  bool get isOutdated => hasData && failure != null;

  /// Whether the outdated data needs a notice of its own. Without a
  /// connection it does not: the app already says it is offline, and a
  /// retry could not work anyway.
  bool get needsOutdatedNotice => isOutdated && failure != LoadFailure.offline;

  /// A refresh is in flight. An earlier failure stays visible until the
  /// answer arrives, so a retry shows progress on the error itself instead
  /// of flashing back to the skeleton.
  LoadState<T> startLoading() => LoadState(
    data: data,
    origin: origin,
    syncedAt: syncedAt,
    failure: failure,
    isLoading: true,
  );

  /// What the listener delivered. Fresh data proves the backend is
  /// reachable again, so it clears a failure; saved data does not.
  LoadState<T> withSnapshot(DataSnapshot<T> snapshot) => LoadState(
    data: snapshot.value,
    origin: snapshot.origin,
    syncedAt: snapshot.syncedAt ?? syncedAt,
    failure: snapshot.origin == DataOrigin.server ? null : failure,
    isLoading: isLoading,
  );

  /// How the refresh ended.
  LoadState<T> withRefresh(Result<DataSnapshot<T>> result) => switch (result) {
    Success(value: final snapshot) => LoadState(
      data: snapshot.value,
      origin: snapshot.origin,
      syncedAt: snapshot.syncedAt ?? syncedAt,
    ),
    Failed(failure: final cause) => LoadState(
      data: data,
      origin: origin,
      syncedAt: syncedAt,
      failure: LoadFailure.of(cause),
    ),
  };

  /// How a refresh ended when its answer no longer matches what is being
  /// followed, as when the page grew while it was in flight. Its data is
  /// discarded; whether the backend answered still counts.
  LoadState<T> withOutdatedRefresh(Result<DataSnapshot<T>> result) =>
      switch (result) {
        Success() => LoadState(data: data, origin: origin, syncedAt: syncedAt),
        Failed() => withRefresh(result),
      };

  @override
  List<Object?> get props => [data, origin, syncedAt, failure, isLoading];
}
