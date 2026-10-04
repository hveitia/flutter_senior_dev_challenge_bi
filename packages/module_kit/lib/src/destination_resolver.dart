import 'package:flutter/widgets.dart';

/// Takes the customer to a destination.
typedef DestinationOpener = void Function(BuildContext context);

/// Names of the places an action may lead to, as the published
/// configuration writes them. They are the configuration contract's
/// allow-list; the app decides which of them it can open.
abstract final class Destinations {
  static const String transfer = 'transfer';
  static const String accounts = 'accounts';
  static const String services = 'services';
  static const String inbox = 'inbox';
  static const String profile = 'profile';

  /// Prefix of a partner's mini app: `partner:travelInsurance`.
  static const String partnerPrefix = 'partner:';
}

/// Turns the name of a destination into a way of opening it.
///
/// There is one resolver in the app, used by every action of the home and by
/// anything else that receives a destination by name. A module asks before
/// drawing an action and leaves it out when the answer is null, so the
/// customer never sees a button that leads nowhere.
// Kept as an interface so the app and the tests provide named classes.
// ignore: one_member_abstracts
abstract interface class DestinationResolver {
  /// How to open [destination], or null when this version of the app cannot
  /// open it: it has no screen for it yet, or its feature is switched off.
  DestinationOpener? resolve(String destination);
}
