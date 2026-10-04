/// Implementations of the feature's ports on Firebase Messaging, Firestore
/// and device storage.
///
/// For the composition root only: nothing else in the app should know where
/// notifications come from.
library;

export 'src/adapters/device_adapters.dart';
export 'src/adapters/firebase_push_messaging.dart';
export 'src/adapters/firestore_inbox_source.dart';
export 'src/data/default_notifications_repository.dart';
export 'src/data/ports.dart';
