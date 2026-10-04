import 'package:feature_services/src/domain/partner_origin.dart';
import 'package:flutter_test/flutter_test.dart';

PartnerOrigin? _production(String baseUrl) =>
    PartnerOrigin.parse(baseUrl, isDevelopment: false);

void main() {
  group('parse', () {
    test('accepts an https origin', () {
      expect(
        _production('https://partners.example.com')?.value,
        'https://partners.example.com',
      );
    });

    test('keeps a port that is not the default', () {
      expect(
        _production('https://partners.example.com:8443')?.value,
        'https://partners.example.com:8443',
      );
    });

    test('drops the default port and a trailing slash', () {
      expect(
        _production('https://partners.example.com:443/')?.value,
        'https://partners.example.com',
      );
    });

    test('lowercases the host', () {
      expect(
        _production('https://Partners.Example.COM')?.value,
        'https://partners.example.com',
      );
    });

    test('refuses plain http outside development', () {
      expect(_production('http://partners.example.com'), isNull);
      expect(_production('http://localhost:3000'), isNull);
    });

    test('accepts plain http when the build is marked as development', () {
      final origin = PartnerOrigin.parse(
        'http://localhost:3000',
        isDevelopment: true,
      );

      expect(origin?.value, 'http://localhost:3000');
    });

    test('refuses anything that is not a bare origin', () {
      for (final baseUrl in [
        '',
        '   ',
        'partners.example.com',
        '/partners',
        'https://',
        'https://partners.example.com/path',
        'https://partners.example.com?x=1',
        'https://partners.example.com#top',
        'https://user:secret@partners.example.com',
        'file:///sdcard/page.html',
        'javascript:alert(1)',
        'ftp://partners.example.com',
        'not a url',
      ]) {
        expect(_production(baseUrl), isNull, reason: baseUrl);
        expect(
          PartnerOrigin.parse(baseUrl, isDevelopment: true),
          isNull,
          reason: '$baseUrl in development',
        );
      }
    });
  });

  group('allows', () {
    final origin = _production('https://partners.example.com')!;

    test('any address on the same scheme, host and port', () {
      expect(
        origin.allows(Uri.parse('https://partners.example.com/a?b=1#c')),
        isTrue,
      );
      expect(
        origin.allows(Uri.parse('https://PARTNERS.example.com:443/a')),
        isTrue,
      );
    });

    test('nothing on another scheme, host or port', () {
      for (final target in [
        'http://partners.example.com/a',
        'https://evil.example.com/a',
        'https://partners.example.com.evil.com/a',
        'https://partners.example.com:8443/a',
        'https://sub.partners.example.com/a',
        'https://partners.example.com@evil.com/a',
        'file:///partners.example.com',
        'javascript:void(0)',
        'data:text/html,<p>x</p>',
        'about:blank',
        '/relative',
      ]) {
        expect(origin.allows(Uri.parse(target)), isFalse, reason: target);
      }
    });
  });

  group('resolve', () {
    test('puts a path on the origin', () {
      final origin = _production('https://partners.example.com')!;

      expect(
        origin.resolve('/partners/recharge').toString(),
        'https://partners.example.com/partners/recharge',
      );
    });

    test('keeps the port of a development origin', () {
      final origin = PartnerOrigin.parse(
        'http://localhost:3000',
        isDevelopment: true,
      )!;

      expect(
        origin.resolve('/partners/recharge').toString(),
        'http://localhost:3000/partners/recharge',
      );
    });
  });

  group('originOf', () {
    test('keeps scheme, host and port and nothing else', () {
      expect(
        originOf(Uri.parse('https://shop.example.com:8443/cart?user=42#x')),
        'https://shop.example.com:8443',
      );
      expect(
        originOf(Uri.parse('https://user:pw@shop.example.com/cart')),
        'https://shop.example.com',
      );
    });

    test('is null for an address without a host', () {
      expect(originOf(Uri.parse('javascript:alert(1)')), isNull);
      expect(originOf(Uri.parse('about:blank')), isNull);
    });
  });
}
