import 'package:app_platform/app_platform.dart';
import 'package:feature_services/src/domain/partner_origin.dart';
import 'package:feature_services/src/domain/service_catalog.dart';
import 'package:feature_services/src/ports.dart';

/// What the services screens need from outside the package. The app builds
/// it once, on the device plugins; tests build it from fakes.
final class ServicesDependencies {
  const ServicesDependencies({
    required this.origin,
    required this.policy,
    required this.telemetry,
    required this.surfaceFactory,
    required this.externalLinks,
    this.catalog = ServiceCatalog.standard,
    this.locale = defaultLocale,
  });

  /// The language the app speaks, as partners' pages are told.
  static const String defaultLocale = 'es-EC';

  /// Where partner content lives, or null when the build was not told. A
  /// build without it offers no mini app at all.
  final PartnerOrigin? origin;

  final ResiliencePolicy policy;
  final Telemetry telemetry;
  final MiniAppSurfaceFactory surfaceFactory;
  final ExternalLinks externalLinks;
  final ServiceCatalog catalog;
  final String locale;

  /// The mini apps this build can open: every one of the catalog when it
  /// knows the partner origin, none otherwise.
  List<ServiceEntry> get miniApps => origin == null
      ? const []
      : [
          for (final entry in catalog.entries)
            if (entry.isPartner) entry,
        ];
}
