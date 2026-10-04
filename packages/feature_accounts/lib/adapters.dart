/// Implementations of the feature's ports on Firestore and device storage.
///
/// For the composition root only: nothing else in the app should know that
/// accounts are read from Firestore.
library;

export 'src/adapters/firestore_accounts_source.dart';
export 'src/adapters/firestore_transfer_queue.dart';
export 'src/adapters/http_transfers_api.dart';
export 'src/adapters/shared_preferences_sync_times.dart';
export 'src/data/default_accounts_repository.dart';
export 'src/data/default_transfers_repository.dart';
export 'src/data/ports.dart';
export 'src/data/transfer_ports.dart';
