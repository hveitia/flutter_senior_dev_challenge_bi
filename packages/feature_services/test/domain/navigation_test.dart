import 'package:feature_services/src/domain/navigation.dart';
import 'package:feature_services/src/domain/partner_origin.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final origin = PartnerOrigin.parse(
    'https://partners.example.com',
    isDevelopment: false,
  )!;

  NavigationVerdict judge(String target) =>
      judgeNavigation(Uri.parse(target), origin);

  test('partner content stays in the container', () {
    expect(
      judge('https://partners.example.com/partners/recharge'),
      NavigationVerdict.stay,
    );
    expect(
      judge('https://partners.example.com/partners/recharge/done?ref=1'),
      NavigationVerdict.stay,
    );
  });

  test('a secure page of somebody else is offered outside the app', () {
    expect(
      judge('https://www.example.org/terms'),
      NavigationVerdict.offerOutside,
    );
    expect(
      judge('https://partners.example.com.evil.com/login'),
      NavigationVerdict.offerOutside,
    );
    expect(
      judge('https://partners.example.com:8443/'),
      NavigationVerdict.offerOutside,
    );
  });

  test('anything else is refused without an offer', () {
    for (final target in [
      'http://www.example.org/terms',
      'http://partners.example.com/partners/recharge',
      'file:///data/data/app/files/secret.txt',
      'content://media/external/file/1',
      'javascript:alert(document.cookie)',
      'data:text/html,<script>1</script>',
      'intent://scan/#Intent;scheme=zxing;end',
      'tel:+593991234567',
      'mailto:someone@example.org',
      'about:blank',
      'blob:https://partners.example.com/1',
    ]) {
      expect(judge(target), NavigationVerdict.refuse, reason: target);
    }
  });

  test('a development origin over http keeps its own pages only', () {
    final development = PartnerOrigin.parse(
      'http://localhost:3000',
      isDevelopment: true,
    )!;

    expect(
      judgeNavigation(
        Uri.parse('http://localhost:3000/partners/recharge'),
        development,
      ),
      NavigationVerdict.stay,
    );
    expect(
      judgeNavigation(Uri.parse('http://localhost:4000/'), development),
      NavigationVerdict.refuse,
    );
  });
}
