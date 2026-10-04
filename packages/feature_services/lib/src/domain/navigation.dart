import 'package:feature_services/src/domain/partner_origin.dart';

/// What the container does with an address the page wants to go to.
enum NavigationVerdict {
  /// It is partner content: load it inside the container.
  stay,

  /// It is a web page of somebody else: keep it out of the container and
  /// offer the customer to open it in the system browser.
  offerOutside,

  /// It is neither: drop it without offering anything.
  refuse,
}

/// Decides where [target] may be shown, given the one [origin] the container
/// loads content from.
///
/// Only a secure web page is offered outside. Everything else is refused:
/// plain `http`, and every scheme that reaches into the device or runs code,
/// such as `file:`, `content:`, `intent:`, `javascript:` or `data:`.
NavigationVerdict judgeNavigation(Uri target, PartnerOrigin origin) {
  if (origin.allows(target)) return NavigationVerdict.stay;
  if (target.scheme == _secureScheme && target.host.isNotEmpty) {
    return NavigationVerdict.offerOutside;
  }
  return NavigationVerdict.refuse;
}

const String _secureScheme = 'https';
