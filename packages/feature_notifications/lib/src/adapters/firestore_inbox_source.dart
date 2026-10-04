import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:feature_notifications/src/data/ports.dart';
import 'package:feature_notifications/src/domain/inbox_item.dart';

/// Field names of an inbox document, as the server writes them.
abstract final class InboxFields {
  static const String title = 'title';
  static const String body = 'body';
  static const String kind = 'kind';
  static const String destination = 'destination';
  static const String createdAt = 'createdAt';
  static const String read = 'read';
}

/// Reads an inbox document. Null when it lacks what a notification cannot
/// be shown without: such a document is left out, not guessed at.
InboxItem? decodeInboxItem(String id, Map<String, Object?> data) {
  final title = data[InboxFields.title];
  final body = data[InboxFields.body];
  final createdAt = data[InboxFields.createdAt];
  final destination = data[InboxFields.destination];
  if (title is! String || title.isEmpty) return null;
  if (body is! String) return null;
  if (createdAt is! Timestamp) return null;

  return InboxItem(
    id: id,
    title: title,
    body: body,
    kind: NotificationKind.parse(data[InboxFields.kind]),
    destination: destination is String ? destination : '',
    createdAt: createdAt.toDate(),
    isRead: data[InboxFields.read] == true,
  );
}

/// The inbox of one customer in Firestore: `users/{uid}/inbox`, newest
/// first. Firestore's own saved copy answers when there is no connection.
final class FirestoreInboxSource implements InboxSource {
  FirestoreInboxSource(FirebaseFirestore firestore, {required String uid})
    : _inbox = firestore.collection('users').doc(uid).collection('inbox');

  final CollectionReference<Map<String, Object?>> _inbox;

  Query<Map<String, Object?>> _latest(int limit) =>
      _inbox.orderBy(InboxFields.createdAt, descending: true).limit(limit);

  @override
  Stream<InboxSnapshot> watch({required int limit}) {
    // Metadata changes are followed so a saved copy is replaced by the
    // confirmed one even when the items are the same.
    return _latest(limit).snapshots(includeMetadataChanges: true).map(_decoded);
  }

  @override
  Future<InboxSnapshot> fetch({required int limit}) async {
    // Never from the saved copy: a fetch exists to know what the backend has.
    return _decoded(
      await _latest(limit).get(const GetOptions(source: Source.server)),
    );
  }

  @override
  Future<void> markRead(String id) =>
      _inbox.doc(id).update({InboxFields.read: true});

  InboxSnapshot _decoded(QuerySnapshot<Map<String, Object?>> snapshot) {
    return InboxSnapshot(
      items: [
        for (final document in snapshot.docs)
          ?decodeInboxItem(document.id, document.data()),
      ],
      fromCache: snapshot.metadata.isFromCache,
    );
  }
}
