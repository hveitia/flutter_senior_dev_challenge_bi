import 'package:app_platform/app_platform.dart';
import 'package:feature_services/src/domain/service_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const catalog = ServiceCatalog.standard;

  group('partner', () {
    test('finds a mini app by the key the configuration publishes', () {
      final entry = catalog.partner(ServiceCatalog.travelInsuranceKey);

      expect(entry?.destination, 'partner:travelInsurance');
      expect(entry?.miniApp?.partnerName, 'Aliado Seguros');
    });

    test('knows nothing of a key this version does not have', () {
      expect(catalog.partner('pets'), isNull);
    });

    test('never answers with a product of the bank', () {
      expect(catalog.partner('transfer'), isNull);
    });
  });

  group('listed', () {
    test('separates the products of the bank from those of partners', () {
      final listed = catalog.listed((destination) => true);

      expect(listed.bank.map((entry) => entry.destination), ['transfer']);
      expect(listed.partners.map((entry) => entry.destination), [
        'partner:travelInsurance',
        'partner:recharge',
      ]);
    });

    test('leaves out what cannot be opened', () {
      final listed = catalog.listed(
        (destination) => destination == 'partner:recharge',
      );

      expect(listed.bank, isEmpty);
      expect(listed.partners.map((entry) => entry.title), ['Recargas']);
    });

    test('lists nothing when nothing can be opened', () {
      final listed = catalog.listed((destination) => false);

      expect(listed.bank, isEmpty);
      expect(listed.partners, isEmpty);
    });
  });

  group('the catalog of this release', () {
    test('ties travel insurance to the service the lab can take down', () {
      final insurance = catalog.partner(ServiceCatalog.travelInsuranceKey);

      expect(insurance?.miniApp?.outageServiceId, ServiceIds.partnerInsurance);
    });

    test('names every partner destination with the partner prefix', () {
      for (final entry in catalog.entries.where((entry) => entry.isPartner)) {
        expect(
          entry.destination,
          '${ServiceCatalog.partnerPrefix}${entry.miniApp!.key}',
        );
      }
    });

    test('gives mini apps a path, never a full address', () {
      for (final entry in catalog.entries.where((entry) => entry.isPartner)) {
        final path = entry.miniApp!.path;

        expect(path, startsWith('/'));
        expect(Uri.parse(path).hasScheme, isFalse);
        expect(Uri.parse(path).hasAuthority, isFalse);
      }
    });
  });
}
