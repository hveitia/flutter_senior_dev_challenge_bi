import 'package:banca_digital/saved_customer_data.dart';

/// A [SavedCustomerData] that counts how often it was asked to clear and
/// lets a test look at the app at that very moment.
final class FakeSavedCustomerData implements SavedCustomerData {
  int clears = 0;

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
}
