import 'package:bloc/bloc.dart';

/// Whether the customer wants their balances hidden on the home. `true`
/// means hidden.
///
/// It lives for one signed-in session and is not stored: the next customer
/// on the device, or the next session, starts with balances visible.
final class AmountVisibilityCubit extends Cubit<bool> {
  AmountVisibilityCubit() : super(false);

  void toggle() => emit(!state);
}
