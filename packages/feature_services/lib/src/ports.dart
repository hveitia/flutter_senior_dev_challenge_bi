import 'package:feature_services/src/domain/navigation.dart';
import 'package:flutter/widgets.dart';

/// What the container hears from the surface that shows a partner's page.
abstract interface class MiniAppEvents {
  /// The page wants to go to [target], by a link, a redirect or a script:
  /// the page itself or, when [isMainFrame] is false, a frame inside it.
  /// The surface only goes there when the answer is
  /// [NavigationVerdict.stay].
  NavigationVerdict onNavigation(Uri target, {bool isMainFrame = true});

  /// The page finished loading.
  void onPageFinished();

  /// The page itself, not one of its resources, could not be loaded.
  void onLoadFailed();

  /// The server answered the request for the page with [statusCode].
  void onHttpError(int statusCode);

  /// The page posted [raw] to the host. It is text of unknown shape and
  /// size: whoever receives it validates it before using it.
  ///
  /// [page] is the address the surface is showing at that moment, or null
  /// when it cannot tell. The channel is reachable by every frame of the
  /// page, so whoever receives the message checks where it came from.
  void onMessage(String raw, {required Uri? page});
}

/// Shows a partner's page and reports what happens in it.
///
/// It is the only thing that touches the web view. An implementation gives
/// the page no access to the device's files and no way to reach the app
/// other than the one message channel of the contract.
abstract interface class MiniAppSurface {
  /// The page, as a widget.
  Widget build(BuildContext context);

  Future<void> load(Uri address);

  /// Delivers [json], an object of the contract, to the page as a message
  /// only a document on [targetOrigin] receives.
  Future<void> postToPage(String json, {required String targetOrigin});
}

/// Creates the surface of one mini app, reporting to [events].
typedef MiniAppSurfaceFactory = MiniAppSurface Function(MiniAppEvents events);

/// Opens an address outside the app, in the system browser.
// Kept as an interface so the app and the tests provide named classes.
// ignore: one_member_abstracts
abstract interface class ExternalLinks {
  /// Whether the address was handed to the browser.
  Future<bool> open(Uri address);
}

/// What a partner's pages left on the device: cookies and stored data.
abstract interface class MiniAppData {
  /// Removes it all, so the next customer on the device starts clean. It
  /// fails when something could not be removed, after trying everything.
  Future<void> clear();

  /// Removes it all again when an earlier [clear] did not finish. Does
  /// nothing otherwise.
  Future<void> clearIfPending();
}
