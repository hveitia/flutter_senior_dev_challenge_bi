import 'package:flutter/widgets.dart';

/// Takes the customer to a destination.
typedef DestinationOpener = void Function(BuildContext context);

/// The destination names this app knows, spelled as the published
/// configuration writes them. They are the single place those names are
/// typed in the app: the resolver's table and every module refer to them.
///
/// This is not the allow-list. Which destinations a document may use is
/// stated by the document itself, and the reader has already dropped the
/// actions that point outside it; the app then decides which of the
/// remaining ones it has a screen for.
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
