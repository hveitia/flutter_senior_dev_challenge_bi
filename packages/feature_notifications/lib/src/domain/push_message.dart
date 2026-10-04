import 'package:equatable/equatable.dart';
import 'package:feature_notifications/src/domain/inbox_item.dart';

/// Whether the system lets the app show notifications.
enum NotificationPermission {
  /// The customer has not been asked by the system yet.
  notAsked,
  granted,

  /// Refused, or switched off later in the system settings. The system will
  /// not ask again: only its settings can change it.
  denied,
}

/// A push notification as it reaches the app.
final class PushMessage extends Equatable {
  const PushMessage({
    required this.title,
    required this.destination,
    this.kind = NotificationKind.benefit,
  });

  final String title;

  /// Where it leads, by name. Empty when the sender gave none.
  final String destination;
  final NotificationKind kind;

  @override
  List<Object?> get props => [title, destination, kind];
}

/// The topic every device of a segment listens to. The console sends to the
/// same name.
String segmentTopic(String segmentId) => 'segment-$segmentId';
