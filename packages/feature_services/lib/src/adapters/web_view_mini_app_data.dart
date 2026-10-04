import 'package:feature_services/src/ports.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// [MiniAppData] on the platform's web view: its cookies, its cache and the
/// storage of the pages it showed.
final class WebViewMiniAppData implements MiniAppData {
  const WebViewMiniAppData();

  @override
  Future<void> clear() async {
    await WebViewCookieManager().clearCookies();
    // Cache and page storage belong to the web view as a whole, but can
    // only be cleared through one of its controllers.
    final controller = WebViewController();
    await controller.clearCache();
    await controller.clearLocalStorage();
  }
}
