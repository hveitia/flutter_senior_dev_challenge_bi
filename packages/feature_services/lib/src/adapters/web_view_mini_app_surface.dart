import 'dart:convert';

import 'package:feature_services/src/data/page_events.dart';
import 'package:feature_services/src/domain/host_contract.dart';
import 'package:feature_services/src/ports.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

/// [MiniAppSurface] on the platform's web view.
///
/// What the page gets from the device is spelled out here, and it is very
/// little: it runs its own scripts, it cannot read files or content of the
/// device, it is refused camera, microphone and any other permission, and
/// its only way to the app is the one message channel of the contract. Where
/// it may navigate is decided by the container, through [PageEvents].
final class WebViewMiniAppSurface implements MiniAppSurface {
  WebViewMiniAppSurface(MiniAppEvents events) : _page = PageEvents(events) {
    _controller = WebViewController(
      onPermissionRequest: (request) => request.deny(),
    );
  }

  final PageEvents _page;
  late final WebViewController _controller;
  bool _isConfigured = false;

  @override
  Widget build(BuildContext context) => WebViewWidget(controller: _controller);

  @override
  Future<void> load(Uri address) async {
    await _configure();
    _page.page = address;
    await _controller.loadRequest(address);
  }

  @override
  Future<void> postToPage(String json, {required String targetOrigin}) {
    // Both arguments are JSON, which is valid script: an object and a
    // quoted text. Naming the origin makes the browser deliver the message
    // only to a document that is still on it.
    return _controller.runJavaScript(
      'window.postMessage($json, ${jsonEncode(targetOrigin)});',
    );
  }

  /// Done once, before the first page: everything here must be in place
  /// before any partner content runs.
  Future<void> _configure() async {
    if (_isConfigured) return;
    _isConfigured = true;

    // The pages are forms that validate and submit with their own scripts.
    await _controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    await _controller.setBackgroundColor(Colors.white);
    await _controller.enableZoom(false);
    await _controller.setNavigationDelegate(
      NavigationDelegate(
        onNavigationRequest: (request) =>
            _page.mayNavigate(request.url, isMainFrame: request.isMainFrame)
            ? NavigationDecision.navigate
            : NavigationDecision.prevent,
        onPageFinished: (_) => _page.pageFinished(),
        onWebResourceError: (error) =>
            _page.resourceFailed(isForMainFrame: error.isForMainFrame),
        onHttpError: (error) => _page.httpError(
          statusCode: error.response?.statusCode,
          requested: error.request?.uri,
        ),
      ),
    );
    await _controller.addJavaScriptChannel(
      HostContract.channel,
      onMessageReceived: (message) async => _page.message(
        message.message,
        // Asked of the web view itself, not remembered: it is the address
        // the page is on when the message arrives.
        currentUrl: await _controller.currentUrl(),
      ),
    );

    if (_controller.platform case final AndroidWebViewController android) {
      // Already the default of the Android versions the app targets. Stated
      // anyway: a page of a third party must never read the app's files.
      await android.setAllowFileAccess(false);
      await android.setAllowContentAccess(false);
      await android.setGeolocationEnabled(false);
    }
  }
}
