import 'package:feature_services/src/ports.dart';
import 'package:url_launcher/url_launcher.dart';

/// Hands an address to another app of the device.
typedef UrlLauncher = Future<bool> Function(Uri url, {LaunchMode mode});

/// [ExternalLinks] on the system browser.
final class UrlLauncherExternalLinks implements ExternalLinks {
  const UrlLauncherExternalLinks({UrlLauncher launch = launchUrl})
    : _launch = launch;

  static const String _secureScheme = 'https';

  final UrlLauncher _launch;

  @override
  Future<bool> open(Uri address) async {
    // The container only offers secure web pages. Checked again here, so
    // nothing that reaches this class can start another kind of app.
    if (address.scheme != _secureScheme || address.host.isEmpty) return false;

    try {
      // Outside the app on purpose: a page of somebody else must not look
      // as if the bank showed it.
      return await _launch(address, mode: LaunchMode.externalApplication);
    } on Object {
      // No browser to hand it to. The caller tells the customer.
      return false;
    }
  }
}
