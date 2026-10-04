import 'package:flutter/widgets.dart';
import 'package:module_kit/src/destination_resolver.dart';

/// What a module with data of its own tells the home about itself.
enum HomeModuleStatus {
  /// Nothing to show yet and nothing has failed.
  waiting,

  /// It is showing its content, fresh or saved.
  ready,

  /// It has nothing to show because loading failed.
  failed,
}

/// The home, as a module sees it.
abstract interface class HomeModuleHost {
  /// Tells the home how the module with [moduleId] is doing, so it can tell
  /// "one module failed" from "nothing can be shown".
  void report(String moduleId, HomeModuleStatus status);

  /// Registers how a module brings its data up to date when the customer
  /// asks the whole home to refresh. Returns the function that removes the
  /// registration.
  VoidCallback addRefresher(Future<void> Function() refresh);
}

/// What the home hands to a module when it builds it: its place in the
/// published configuration and the services of the home.
@immutable
final class HomeModuleContext {
  const HomeModuleContext({
    required this.id,
    required this.type,
    required this.props,
    required this.destinations,
    required this.host,
  });

  /// Unique within the customer's home.
  final String id;

  /// The key the module was registered under.
  final String type;

  /// Settings published for this module. The module reads them leniently:
  /// a missing or mistyped value means "use the default", never a failure.
  final Map<String, Object?> props;

  final DestinationResolver destinations;
  final HomeModuleHost host;

  /// The text published under [key], or null when there is none.
  String? text(String key) => textIn(props, key);

  /// The whole number published under [key], or null when there is none.
  int? integer(String key) => switch (props[key]) {
    final int value => value,
    _ => null,
  };

  /// The object published under [key], or null when there is none.
  Map<String, Object?>? object(String key) => _asObject(props[key]);

  /// The objects of the list published under [key]. Entries that are not
  /// objects are left out.
  List<Map<String, Object?>> objects(String key) => switch (props[key]) {
    final List<Object?> entries => [
      for (final entry in entries) ?_asObject(entry),
    ],
    _ => const [],
  };

  /// The text under [key] of an object taken from the props, or null when
  /// it is missing, blank or not a text.
  static String? textIn(Map<String, Object?> object, String key) =>
      switch (object[key]) {
        final String value when value.trim().isNotEmpty => value,
        _ => null,
      };

  static Map<String, Object?>? _asObject(Object? value) => switch (value) {
    final Map<String, Object?> object => object,
    _ => null,
  };
}

/// Builds the widget of one module of the home.
typedef HomeModuleBuilder =
    Widget Function(BuildContext context, HomeModuleContext module);
