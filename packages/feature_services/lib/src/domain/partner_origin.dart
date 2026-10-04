/// The one origin partner content may be loaded from.
///
/// It is fixed when the app is built and never read from the published
/// configuration: what is published can change what the customer is offered,
/// not where the app is willing to take them.
final class PartnerOrigin {
  const PartnerOrigin._(this._base);

  static const String _secureScheme = 'https';
  static const String _plainScheme = 'http';

  /// The only hosts plain `http` is ever accepted for: the developer's
  /// machine as a phone reaches it through `adb reverse`, and as an Android
  /// emulator sees it.
  static const Set<String> developmentHosts = {
    'localhost',
    '127.0.0.1',
    '10.0.2.2',
  };

  /// Reads the origin from [baseUrl], the value given to the build.
  ///
  /// Null when there is none or it cannot be trusted: it must be an absolute
  /// `https` address made of scheme, host and port only.
  ///
  /// Plain `http` needs three things at once: [isDevelopment] says the
  /// build points at a developer's own machine, the build is not a release
  /// one ([isReleaseBuild]), and the host is one of [developmentHosts]. A
  /// release build given an `http` origin therefore has no origin, and
  /// offers no mini app.
  static PartnerOrigin? parse(
    String baseUrl, {
    required bool isDevelopment,
    bool isReleaseBuild = false,
  }) {
    final uri = Uri.tryParse(baseUrl.trim());
    if (uri == null || uri.host.isEmpty) return null;

    final isSecure = uri.scheme == _secureScheme;
    final isPlainForDevelopment =
        uri.scheme == _plainScheme &&
        isDevelopment &&
        !isReleaseBuild &&
        developmentHosts.contains(uri.host);
    if (!isSecure && !isPlainForDevelopment) return null;

    final isBare =
        uri.userInfo.isEmpty &&
        (uri.path.isEmpty || uri.path == '/') &&
        !uri.hasQuery &&
        !uri.hasFragment;
    if (!isBare) return null;

    return PartnerOrigin._(
      Uri(scheme: uri.scheme, host: uri.host, port: uri.port),
    );
  }

  /// Scheme, host and port. `Uri` keeps the host in lower case and leaves
  /// the port out when it is the default of the scheme.
  final Uri _base;

  /// `https://partners.example.com`, with the port only when it is not the
  /// default of the scheme. Safe to report: it names a server, not a person.
  String get value => _base.origin;

  /// Whether [target] is on this origin: same scheme, host and port.
  bool allows(Uri target) =>
      target.scheme == _base.scheme &&
      target.host == _base.host &&
      target.port == _base.port;

  /// The address of [path] on this origin.
  Uri resolve(String path) => _base.replace(path: path);
}

/// `scheme://host[:port]` of [uri], which is all that is ever reported about
/// an address the customer was kept from. Null when it has no host.
String? originOf(Uri uri) {
  if (uri.host.isEmpty) return null;
  return Uri(scheme: uri.scheme, host: uri.host, port: uri.port).toString();
}
