import 'package:app_platform/src/config/config_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Reads the published configuration from Firestore in real time.
final class FirestoreConfigSource implements ConfigSource {
  const FirestoreConfigSource(this._firestore);

  /// The single document the backoffice publishes to.
  static const String documentPath = 'config/home';

  final FirebaseFirestore _firestore;

  @override
  Stream<Object?> watch() {
    return _firestore
        .doc(documentPath)
        .snapshots()
        .map((snapshot) => snapshot.data());
  }
}
