/// The access feature's ports implemented on Firebase and device plugins,
/// plus the repository they plug into. Imported by the composition root
/// only.
library;

export 'src/adapters/device_unlock.dart';
export 'src/adapters/firebase_auth_gateway.dart';
export 'src/adapters/firestore_profile_store.dart';
export 'src/data/default_auth_repository.dart';
// The composition root wraps the profile store, which takes its port.
export 'src/data/ports.dart' show ProfileStore;
