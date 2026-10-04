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

  group('plain http', () {
    PartnerOrigin? parse(
      String baseUrl, {
      bool isDevelopment = true,
      bool isReleaseBuild = false,
    }) => PartnerOrigin.parse(
      baseUrl,
      isDevelopment: isDevelopment,
      isReleaseBuild: isReleaseBuild,
    );

    test('is accepted for the developer’s own machine only', () {
      for (final baseUrl in [
        'http://localhost:3000',
        'http://127.0.0.1:3000',
        'http://10.0.2.2:3000',
      ]) {
        expect(parse(baseUrl)?.value, baseUrl, reason: baseUrl);
      }
      for (final baseUrl in [
        'http://192.168.1.20:3000',
        'http://partners.example.com',
        'http://localhost.evil.example',
        'http://10.0.2.20:3000',
      ]) {
        expect(parse(baseUrl), isNull, reason: baseUrl);
      }
    });

    test('is never accepted in a release build, whatever the flag says', () {
      expect(parse('http://localhost:3000', isReleaseBuild: true), isNull);
      expect(parse('http://10.0.2.2:3000', isReleaseBuild: true), isNull);
    });

    test('is never accepted without the development flag', () {
      expect(parse('http://localhost:3000', isDevelopment: false), isNull);
    });

    test('does not get in the way of https, in any build', () {
      expect(
        parse('https://partners.example.com', isReleaseBuild: true)?.value,
        'https://partners.example.com',
      );
      expect(
        parse(
          'https://localhost:3443',
          isDevelopment: false,
          isReleaseBuild: true,
        )?.value,
        'https://localhost:3443',
      );
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
