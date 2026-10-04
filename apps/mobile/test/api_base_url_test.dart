import 'package:banca_digital/api_base_url.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('a release build', () {
    test('uses an https address as given', () {
      expect(
        apiBaseUrlFor('https://api.example.com/', mode: BuildMode.release),
        Uri.parse('https://api.example.com/'),
      );
    });

    for (final address in [
      'http://api.example.com/',
      'http://localhost:3210/',
      'http://10.0.2.2:3210/',
    ]) {
      test('refuses $address: the session token would travel unencrypted', () {
        expect(
          () => apiBaseUrlFor(address, mode: BuildMode.release),
          throwsA(isA<ApiBaseUrlError>()),
        );
      });
    }

    test('refuses to start with no address instead of aiming at the '
        "developer's machine", () {
      expect(
        () => apiBaseUrlFor('', mode: BuildMode.release),
        throwsA(isA<ApiBaseUrlError>()),
      );
    });

    for (final address in [
      'https://localhost/',
      'https://127.0.0.1/',
      'https://10.0.2.2/',
    ]) {
      test('refuses $address: a published app has no server on the phone', () {
        expect(
          () => apiBaseUrlFor(address, mode: BuildMode.release),
          throwsA(isA<ApiBaseUrlError>()),
        );
      });
    }
  });

  for (final mode in [BuildMode.debug, BuildMode.profile]) {
    group('a ${mode.name} build', () {
      test("with no address, uses the API on the developer's machine", () {
        expect(
          apiBaseUrlFor('', mode: mode),
          Uri.parse('http://localhost:3210/'),
        );
      });

      for (final address in [
        'http://localhost:3210/',
        'http://127.0.0.1:3210/',
        'http://10.0.2.2:3210/',
      ]) {
        test('accepts $address, the development hosts', () {
          expect(apiBaseUrlFor(address, mode: mode), Uri.parse(address));
        });
      }

      test('refuses plain http to any other host', () {
        expect(
          () => apiBaseUrlFor('http://192.168.1.20:3210/', mode: mode),
          throwsA(isA<ApiBaseUrlError>()),
        );
        expect(
          () => apiBaseUrlFor('http://localhost.example.com/', mode: mode),
          throwsA(isA<ApiBaseUrlError>()),
        );
      });

      test('accepts https to any host', () {
        expect(
          apiBaseUrlFor('https://staging.example.com/', mode: mode),
          Uri.parse('https://staging.example.com/'),
        );
      });
    });
  }

  for (final address in [
    'ftp://api.example.com/',
    'api.example.com',
    'https://',
    'https://user:secret@api.example.com/',
    'not a url',
  ]) {
    test('refuses "$address" in any build', () {
      for (final mode in BuildMode.values) {
        expect(
          () => apiBaseUrlFor(address, mode: mode),
          throwsA(isA<ApiBaseUrlError>()),
          reason: mode.name,
        );
      }
    });
  }

  test('adds the final slash, so paths resolve under the address', () {
    expect(
      apiBaseUrlFor(
        'https://api.example.com/v1',
        mode: BuildMode.release,
      ).resolve('api/transfers').toString(),
      'https://api.example.com/v1/api/transfers',
    );
  });
}
