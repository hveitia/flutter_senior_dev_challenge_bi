import 'package:app_platform/app_platform.dart';

/// Which pictogram stands for a service. The domain names it; the screens
/// decide how it is drawn.
enum ServiceSymbol { transfer, insurance, recharge }

/// A partner's mini app: content the partner serves, shown inside the bank's
/// app.
final class MiniApp {
  const MiniApp({
    required this.key,
    required this.partnerName,
    required this.path,
    this.outageServiceId,
  });

  /// The name after `partner:` in the published configuration, which is also
  /// how the `serviceRecommendations` module lists it: `travelInsurance`.
  final String key;

  /// Who serves the content and answers for it: "Aliado Seguros".
  final String partnerName;

  /// Where the mini app lives on the partner's origin. Never a full address:
  /// the origin is fixed when the app is built.
  final String path;

  /// The service the resilience lab can take down to make this mini app
  /// unavailable, when it has one.
  final String? outageServiceId;
}

/// Something the customer can open from Servicios.
final class ServiceEntry {
  const ServiceEntry({
    required this.destination,
    required this.title,
    required this.description,
    required this.symbol,
    this.miniApp,
  });

  /// The destination that opens it, spelled as the published configuration
  /// spells it: `partner:travelInsurance`, `transfer`.
  final String destination;
  final String title;
  final String description;
  final ServiceSymbol symbol;

  /// Set when the service is a partner's mini app; null for a product of the
  /// bank, which opens a screen of the app itself.
  final MiniApp? miniApp;

  bool get isPartner => miniApp != null;
}

/// What a listing shows: the products of the bank and those of its partners.
typedef ListedServices = ({
  List<ServiceEntry> bank,
  List<ServiceEntry> partners,
});

/// Every service this version of the app knows how to open.
///
/// Adding a partner here needs a release; switching one on or off, or
/// recommending it on the home, does not: that is published.
final class ServiceCatalog {
  const ServiceCatalog(this.entries);

  /// The prefix of a partner's destination in the published configuration.
  static const String partnerPrefix = 'partner:';

  static const String travelInsuranceKey = 'travelInsurance';
  static const String rechargeKey = 'recharge';

  /// The services of this release.
  static const ServiceCatalog standard = ServiceCatalog([
    ServiceEntry(
      destination: 'transfer',
      title: 'Transferencias',
      description: 'Mueve dinero entre tus cuentas',
      symbol: ServiceSymbol.transfer,
    ),
    ServiceEntry(
      destination: '$partnerPrefix$travelInsuranceKey',
      title: 'Seguro de viaje',
      description: 'Protección para tus planes',
      symbol: ServiceSymbol.insurance,
      miniApp: MiniApp(
        key: travelInsuranceKey,
        partnerName: 'Aliado Seguros',
        path: '/partners/travel-insurance',
        outageServiceId: ServiceIds.partnerInsurance,
      ),
    ),
    ServiceEntry(
      destination: '$partnerPrefix$rechargeKey',
      title: 'Recargas',
      description: 'Saldo para seguir conectado',
      symbol: ServiceSymbol.recharge,
      miniApp: MiniApp(
        key: rechargeKey,
        partnerName: 'Aliado Recargas',
        path: '/partners/recharge',
      ),
    ),
  ]);

  final List<ServiceEntry> entries;

  /// The partner service whose mini app has [key], or null when this
  /// version knows none.
  ServiceEntry? partner(String key) {
    for (final entry in entries) {
      if (entry.miniApp?.key == key) return entry;
    }
    return null;
  }

  /// The entries the customer can open right now, in catalog order.
  ///
  /// [canOpen] answers for a destination: the app has a screen for it and
  /// what is published allows it. An entry that cannot be opened is left
  /// out, so no row of the listing leads nowhere.
  ListedServices listed(bool Function(String destination) canOpen) {
    final open = [
      for (final entry in entries)
        if (canOpen(entry.destination)) entry,
    ];
    return (
      bank: [
        for (final entry in open)
          if (!entry.isPartner) entry,
      ],
      partners: [
        for (final entry in open)
          if (entry.isPartner) entry,
      ],
    );
  }
}
