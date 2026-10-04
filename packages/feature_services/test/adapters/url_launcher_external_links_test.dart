import 'package:feature_services/adapters.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  late List<(Uri url, LaunchMode mode)> launched;

  UrlLauncherExternalLinks links({bool answers = true, Object? throws}) {
    return UrlLauncherExternalLinks(
      launch: (url, {mode = LaunchMode.platformDefault}) async {
        launched.add((url, mode));
        // Whatever the plugin throws reaches the adapter as an object.
        // ignore: only_throw_errors
        if (throws != null) throw throws;
        return answers;
      },
    );
  }

  setUp(() => launched = []);

  test('hands a secure page to another app, never to an in-app view', () async {
    final terms = Uri.parse('https://www.example.org/terms');

    expect(await links().open(terms), isTrue);
    expect(launched, [(terms, LaunchMode.externalApplication)]);
  });

  test('refuses anything that is not a secure web page', () async {
    for (final address in [
      'http://www.example.org/terms',
      'tel:+593991234567',
      'intent://scan/#Intent;scheme=zxing;end',
      'file:///sdcard/secret.txt',
      'javascript:alert(1)',
      'https:///nohost',
    ]) {
      expect(await links().open(Uri.parse(address)), isFalse, reason: address);
    }

    expect(launched, isEmpty);
  });

  test('answers no when the device could not open it', () async {
    final opened = await links(
      answers: false,
    ).open(Uri.parse('https://www.example.org/terms'));

    expect(opened, isFalse);
  });

  test('answers no instead of failing when there is no browser', () async {
    final opened = await links(
      throws: StateError('no activity'),
    ).open(Uri.parse('https://www.example.org/terms'));

    expect(opened, isFalse);
  });
}
