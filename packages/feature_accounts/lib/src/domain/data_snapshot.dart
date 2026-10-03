import 'package:equatable/equatable.dart';

/// Where the data on screen came from.
enum DataOrigin {
  /// Confirmed by the backend just now.
  server,

  /// What the device saved the last time it was in sync.
  cache,
}

/// A data set as it can be shown: its value, where it came from and when it
/// was last confirmed by the backend.
final class DataSnapshot<T> extends Equatable {
  const DataSnapshot({
    required this.value,
    required this.origin,
    required this.syncedAt,
  });

  final T value;
  final DataOrigin origin;

  /// Null when the device does not know when it last synchronized.
  final DateTime? syncedAt;

  @override
  List<Object?> get props => [value, origin, syncedAt];
}
