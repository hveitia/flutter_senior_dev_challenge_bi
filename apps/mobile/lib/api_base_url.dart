/// How the app was built, as far as the customer API's address goes.
enum BuildMode { debug, profile, release }

/// The address of the customer API cannot be used in this build.
final class ApiBaseUrlError implements Exception {
  const ApiBaseUrlError(this.message);

  final String message;

  @override
  String toString() => 'ApiBaseUrlError: $message';
}

/// The API running on the developer's machine, which a phone reaches
/// through `adb reverse tcp:3210 tcp:3210`.
const String developmentApiBaseUrl = 'http://localhost:3210/';

/// The only hosts a build may reach without encryption: the developer's
/// machine, as seen from a phone (`adb reverse`) and from an emulator. They
/// are the hosts the debug and profile network security configs allow.
const Set<String> developmentHosts = {'localhost', '127.0.0.1', '10.0.2.2'};

/// The address of the customer API for a build in [mode], from the value
/// given with `--dart-define=API_BASE_URL`.
///
/// Every request to it carries the customer's session token, so the rule is
/// decided here, in code, and not left to what a build happens to be given:
///
/// * a release build takes an `https` address that is not a development
///   host, and refuses to start without one;
/// * a debug or profile build also takes plain `http`, only to a
///   development host, and uses [developmentApiBaseUrl] when given nothing.
///
/// Throws [ApiBaseUrlError] otherwise.
Uri apiBaseUrlFor(String configured, {required BuildMode mode}) {
  final isRelease = mode == BuildMode.release;
  final value = configured.trim();
  if (value.isEmpty) {
    if (isRelease) {
      throw const ApiBaseUrlError(
        'API_BASE_URL is required in a release build.',
      );
    }
    return Uri.parse(developmentApiBaseUrl);
  }

  final address = Uri.tryParse(value);
  if (address == null || !address.hasAuthority || address.host.isEmpty) {
    throw const ApiBaseUrlError('API_BASE_URL is not an absolute address.');
  }
  if (address.userInfo.isNotEmpty) {
    throw const ApiBaseUrlError('API_BASE_URL must not carry credentials.');
  }

  final isDevelopmentHost = developmentHosts.contains(address.host);
  switch (address.scheme) {
    case 'https':
      if (isRelease && isDevelopmentHost) {
        throw const ApiBaseUrlError(
          'A release build cannot use a development host.',
        );
      }
    case 'http':
      if (isRelease || !isDevelopmentHost) {
        throw const ApiBaseUrlError(
          'Plain http is only for a development host in a debug or profile '
          'build.',
        );
      }
    default:
      throw const ApiBaseUrlError('API_BASE_URL must be an https address.');
  }

  // Paths are resolved under the address, which needs its final slash.
  return address.path.endsWith('/')
      ? address
      : address.replace(path: '${address.path}/');
}
