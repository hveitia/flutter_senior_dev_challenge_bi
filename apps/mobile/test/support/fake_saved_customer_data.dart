import 'package:banca_digital/saved_customer_data.dart';

/// A [SavedCustomerData] that counts how often it was asked to clear and
/// lets a test look at the app at that very moment.
final class FakeSavedCustomerData implements SavedCustomerData {
  int clears = 0;

  /// How often a new session asked for a pending removal to be finished.
  int finishes = 0;

  /// Called at the start of every [clear].
  void Function()? onClear;

  /// When set, [clear] ends with this error.
  Error? failsWith;

  @override
  Future<void> clear() async {
    clears++;
    onClear?.call();
    if (failsWith case final Error error) throw error;
  }

  @override
  Future<void> finishPending() async {
    finishes++;
  }
}

/// A [PendingWipe] kept in memory.
final class InMemoryPendingWipe implements PendingWipe {
  bool pending = false;

  /// Every value written, in order.
  final List<bool> writes = [];

  @override
  Future<bool> isPending() async => pending;

  @override
  Future<void> setPending({required bool pending}) async {
    this.pending = pending;
    writes.add(pending);
  }
}
