import 'package:app_platform/app_platform.dart';
import 'package:banca_digital/app_router.dart';
import 'package:feature_accounts/feature_accounts.dart';
import 'package:feature_notifications/feature_notifications.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:module_kit/module_kit.dart';

/// A destination this build of the app has a screen for.
@immutable
final class AppDestination {
  const AppDestination({required this.open, this.isEnabled = _always});

  final DestinationOpener open;

  /// Whether the published feature flags allow it for this customer.
  final bool Function(FeatureFlags features) isEnabled;

  static bool _always(FeatureFlags features) => true;
}

/// The app's one answer to "where does this destination lead?".
///
/// The published configuration names destinations from its allow-list; this
/// maps the ones the app has a screen for to its routes. Anything else,
/// including a destination whose feature is switched off, resolves to
/// nothing, and whoever asked leaves the action out.
final class AppDestinationResolver implements DestinationResolver {
  const AppDestinationResolver({
    required FeatureFlags Function() features,
    Map<String, AppDestination> routes = builtRoutes,
  }) : _features = features,
       _routes = routes;

  /// The destinations the app itself has a screen for. The partners' mini
  /// apps are added by the services wiring, behind their feature flag and
  /// only when the build names a partner origin.
  static const Map<String, AppDestination> builtRoutes = {
    Destinations.transfer: AppDestination(
      open: _openTransfer,
      isEnabled: _transfersOn,
    ),
    Destinations.accounts: AppDestination(open: _openAccounts),
    Destinations.movements: AppDestination(open: _openMovements),
    Destinations.services: AppDestination(open: _openServices),
    Destinations.profile: AppDestination(open: _openProfile),
    Destinations.inbox: AppDestination(open: openInbox),
  };

  final FeatureFlags Function() _features;
  final Map<String, AppDestination> _routes;

  @override
  DestinationOpener? resolve(String destination) {
    final route = _routes[destination];
    if (route == null || !route.isEnabled(_features())) return null;
    return route.open;
  }

  static bool _transfersOn(FeatureFlags features) => features.transfers;

  static void _openTransfer(BuildContext context) =>
      context.push(AccountsPaths.transfer);

  static void _openAccounts(BuildContext context) =>
      context.go(AccountsPaths.accounts);

  static void _openMovements(BuildContext context) =>
      context.push(AccountsPaths.movements);

  static void _openServices(BuildContext context) =>
      context.go(AppPaths.services);

  static void _openProfile(BuildContext context) =>
      context.go(AppPaths.profile);
}
