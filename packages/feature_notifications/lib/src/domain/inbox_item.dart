import 'package:equatable/equatable.dart';

/// What a notification is about. It decides its icon, nothing else.
enum NotificationKind {
  movement,
  security,
  benefit
  ;

  /// The kind named [value]. A kind this version does not know is shown as
  /// a benefit, the most general of the three, rather than hidden.
  static NotificationKind parse(Object? value) {
    for (final kind in values) {
      if (kind.name == value) return kind;
    }
    return benefit;
  }
}

/// One notification in the customer's inbox, as the server wrote it.
final class InboxItem extends Equatable {
  const InboxItem({
    required this.id,
    required this.title,
    required this.body,
    required this.kind,
    required this.destination,
    required this.createdAt,
    required this.isRead,
  });

  final String id;
  final String title;
  final String body;
  final NotificationKind kind;

  /// Where tapping it leads, by the name the published configuration uses.
  final String destination;
  final DateTime createdAt;
  final bool isRead;

  InboxItem withRead({required bool isRead}) => InboxItem(
    id: id,
    title: title,
    body: body,
    kind: kind,
    destination: destination,
    createdAt: createdAt,
    isRead: isRead,
  );

  @override
  List<Object?> get props => [
    id,
    title,
    body,
    kind,
    destination,
    createdAt,
    isRead,
  ];
}

/// The inbox as it can be shown, and whether the backend confirmed it or it
/// is what the device had saved.
final class InboxSnapshot extends Equatable {
  const InboxSnapshot({required this.items, required this.fromCache});

  /// Newest first.
  final List<InboxItem> items;
  final bool fromCache;

  @override
  List<Object?> get props => [items, fromCache];
}
