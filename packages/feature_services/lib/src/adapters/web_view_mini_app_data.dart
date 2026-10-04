import 'package:feature_services/src/data/stepwise_mini_app_data.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Names of the steps, as they appear in a failure report.
abstract final class WebViewDataSteps {
  static const String cookies = 'cookies';
  static const String cache = 'cache';
  static const String storage = 'storage';
}

/// What the platform's web view keeps of the pages it showed, and how each
/// kind is removed.
///
/// The web view keeps this for the whole app, not per page, but it can only
/// be reached through a controller.
///
/// What `storage` covers depends on the platform. On Android it asks the
/// web view to delete all the data of its JavaScript storage APIs. On iOS
/// the plugin only removes local storage: session storage, IndexedDB and
/// service workers of a partner page would stay, and removing them needs
/// the platform's own data store, which this app does not call yet.
List<MiniAppDataStep> webViewDataSteps() {
  return [
    (
      name: WebViewDataSteps.cookies,
      run: () => WebViewCookieManager().clearCookies(),
    ),
    (name: WebViewDataSteps.cache, run: () => WebViewController().clearCache()),
    (
      name: WebViewDataSteps.storage,
      run: () => WebViewController().clearLocalStorage(),
    ),
  ];
}
