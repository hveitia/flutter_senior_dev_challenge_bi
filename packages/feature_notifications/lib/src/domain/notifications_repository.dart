import 'package:app_platform/app_platform.dart';
import 'package:feature_notifications/src/domain/inbox_item.dart';

/// The inbox of the signed-in customer.
///
/// The server writes it; the customer only reads it and marks items as
/// read. A notification the device never received as a push is still here.
abstract interface class NotificationsRepository {
  /// Follows the inbox. It may answer first from the device's saved copy.
  Stream<InboxSnapshot> watchInbox();

  /// Asks the backend for the inbox as it is now.
  Future<Result<InboxSnapshot>> refreshInbox();

  /// Marks the notification as read. Safe to repeat.
  Future<Result<void>> markRead(String id);
}
