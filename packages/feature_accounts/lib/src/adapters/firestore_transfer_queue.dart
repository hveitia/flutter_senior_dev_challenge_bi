import 'dart:async';

import 'package:app_platform/app_platform.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:feature_accounts/src/data/transfer_ports.dart';
import 'package:feature_accounts/src/domain/transfer.dart';

/// Field names of a transfer order, as the server and the rules read them.
abstract final class TransferFields {
  static const String fromAccountId = 'fromAccountId';
  static const String toAccountId = 'toAccountId';
  static const String amountCents = 'amountCents';
  static const String concept = 'concept';
  static const String status = 'status';
  static const String createdAt = 'createdAt';

  static const String pending = 'pending';
}

/// The queue of orders, kept as pending documents under the customer:
/// `users/{uid}/transfers/{transferId}`.
///
/// Firestore's own offline write queue is the transport: a document written
/// without a connection is stored on the device and delivered when the
/// connection returns. The rules let the app create exactly this document
/// and nothing else; only the server settles it.
final class FirestoreTransferQueue implements TransferQueue {
  FirestoreTransferQueue(
    FirebaseFirestore firestore, {
    required String uid,
    required Telemetry telemetry,
  }) : _transfers = firestore
           .collection(usersCollection)
           .doc(uid)
           .collection(transfersCollection),
       _telemetry = telemetry;

  static const String usersCollection = 'users';
  static const String transfersCollection = 'transfers';
  static const String _writeRefused = 'transfer_queue_write_refused';

  final CollectionReference<Map<String, dynamic>> _transfers;
  final Telemetry _telemetry;

  /// The pending document exactly as the rules require it: these six
  /// fields, a pending status and the server's time.
  static Map<String, Object?> encode(TransferOrder order) => {
    TransferFields.fromAccountId: order.fromAccountId,
    TransferFields.toAccountId: order.toAccountId,
    TransferFields.amountCents: order.amountCents,
    TransferFields.concept: order.concept,
    TransferFields.status: TransferFields.pending,
    TransferFields.createdAt: FieldValue.serverTimestamp(),
  };

  final StreamController<String> _refused = StreamController.broadcast();

  @override
  Stream<String> get refused => _refused.stream;

  @override
  void enqueue(TransferOrder order) {
    // Not awaited: without a connection the write only completes once the
    // server has it, which is exactly what is being waited out.
    unawaited(
      _transfers.doc(order.id).set(encode(order)).catchError((
        Object error,
        StackTrace stackTrace,
      ) {
        // The server turned the write away (the rules, or an order with
        // that id already settled). Firestore then drops it from the
        // device, so without this the order would vanish unexplained.
        _telemetry.recordError(
          RedactedError(error.runtimeType),
          stackTrace,
          reason: _writeRefused,
        );
        if (!_refused.isClosed) _refused.add(order.id);
      }),
    );
  }

  @override
  Stream<List<QueuedTransfer>> watchQueued() => _transfers
      .where(TransferFields.status, isEqualTo: TransferFields.pending)
      // Metadata changes included, so an order written offline shows at
      // once and one the server settled leaves as soon as it is known.
      .snapshots(includeMetadataChanges: true)
      .map(
        (snapshot) => [
          for (final document in snapshot.docs)
            if (document.data()[TransferFields.amountCents]
                case final int cents)
              QueuedTransfer(
                id: document.id,
                amountCents: cents,
                // No pending write means the bank has the document.
                isDelivered: !document.metadata.hasPendingWrites,
              ),
        ],
      );
}
