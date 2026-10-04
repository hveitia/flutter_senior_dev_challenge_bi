import 'dart:async';
import 'dart:convert';

import 'package:app_platform/app_platform.dart';
import 'package:app_platform/testing.dart';
import 'package:fake_async/fake_async.dart';
import 'package:feature_services/src/domain/host_contract.dart';
import 'package:feature_services/src/domain/navigation.dart';
import 'package:feature_services/src/domain/partner_origin.dart';
import 'package:feature_services/src/domain/service_catalog.dart';
import 'package:feature_services/src/presentation/mini_app/mini_app_cubit.dart';
import 'package:feature_services/src/services_telemetry.dart';
import 'package:feature_services/src/testing/services_fakes.dart';
import 'package:flutter_test/flutter_test.dart';

const _taken = ResilienceSettings(
  latency: Duration.zero,
  unavailableServices: {ServiceIds.partnerInsurance},
);

/// A mini app with everything around it driven by the test.
final class _Harness {
  _Harness({
    String serviceKey = ServiceCatalog.travelInsuranceKey,
    bool configured = true,
    bool allowFaultInjection = true,
  }) {
    policy = ResiliencePolicy(
      faults: () => faults,
      allowFaultInjection: allowFaultInjection,
      isOffline: () => offline,
      delay: (_) async {},
    );
    cubit = MiniAppCubit(
      service: ServiceCatalog.standard.partner(serviceKey)!,
      origin: configured
          ? PartnerOrigin.parse(
              'https://partners.example.com',
              isDevelopment: false,
            )
          : null,
      hostContext: const HostContext(locale: 'es-EC', segment: 'family'),
      policy: policy,
      telemetry: telemetry,
      surfaceFactory: (events) => surface = FakeMiniAppSurface(events),
      now: () => now,
    );
  }

  final InMemoryTelemetry telemetry = InMemoryTelemetry();
  ResilienceSettings faults = ResilienceSettings.none;
  bool offline = false;
  DateTime now = DateTime(2026, 10, 3, 10);

  late final ResiliencePolicy policy;
  late final MiniAppCubit cubit;
  late final FakeMiniAppSurface surface;

  /// Publishes [next] as the resilience lab would.
  void publish(ResilienceSettings next) {
    faults = next;
    policy.faultsChanged();
  }

  List<String> get events => [for (final event in telemetry.events) event.name];

  Map<String, Object> parametersOf(String name) =>
      telemetry.events.lastWhere((event) => event.name == name).parameters;
}

/// Runs [body] with a harness whose mini app was started and whose page has
/// not answered yet.
void _started(
  void Function(FakeAsync async, _Harness harness) body, {
  _Harness Function()? create,
}) {
  fakeAsync((async) {
    final harness = (create ?? _Harness.new)();
    unawaited(harness.cubit.start());
    async.flushMicrotasks();
    body(async, harness);
    unawaited(harness.cubit.close());
    async.flushMicrotasks();
  });
}

void main() {
  group('opening', () {
    test('loads the path of the mini app on the partner origin', () {
      _started((async, harness) {
        expect(harness.cubit.state.phase, MiniAppPhase.loading);
        expect(harness.surface.loaded.map((uri) => '$uri'), [
          'https://partners.example.com/partners/travel-insurance',
        ]);
      });
    });

    test('is ready once the page finishes loading', () {
      _started((async, harness) {
        harness.surface.events.onPageFinished();

        expect(harness.cubit.state.phase, MiniAppPhase.ready);
      });
    });

    test('sends the page its context, addressed to the partner origin', () {
      _started((async, harness) {
        harness.surface.events.onPageFinished();
        async.flushMicrotasks();

        final posted = harness.surface.posted.single;
        expect(posted.targetOrigin, 'https://partners.example.com');
        expect(jsonDecode(posted.json), {
          'type': 'context',
          'version': 1,
          'locale': 'es-EC',
          'segment': 'family',
        });
      });
    });

    test('sends nothing to a page that did not load', () {
      _started((async, harness) {
        harness.surface.events.onLoadFailed();
        harness.surface.events.onPageFinished();
        async.flushMicrotasks();

        expect(harness.surface.posted, isEmpty);
        expect(harness.cubit.state.phase, MiniAppPhase.unavailable);
      });
    });
  });

  group('unavailable', () {
    void expectUnavailable(_Harness harness, MiniAppUnavailableReason reason) {
      expect(harness.cubit.state.phase, MiniAppPhase.unavailable);
      expect(harness.cubit.state.reason, reason);
      expect(harness.parametersOf(ServicesTelemetry.unavailable), {
        ServicesTelemetry.serviceKey: ServiceCatalog.travelInsuranceKey,
        ServicesTelemetry.reasonKey: reason.code,
      });
    }

    test('when the build has no partner origin, without loading anything', () {
      _started(create: () => _Harness(configured: false), (async, harness) {
        expectUnavailable(harness, MiniAppUnavailableReason.notConfigured);
        expect(harness.surface.loaded, isEmpty);
      });
    });

    test('when the device is offline, without loading anything', () {
      _started(create: () => _Harness()..offline = true, (async, harness) {
        expectUnavailable(harness, MiniAppUnavailableReason.offline);
        expect(harness.surface.loaded, isEmpty);
      });
    });

    test('when the lab took the partner down, without loading anything', () {
      _started(create: () => _Harness()..faults = _taken, (async, harness) {
        expectUnavailable(harness, MiniAppUnavailableReason.outage);
        expect(harness.surface.loaded, isEmpty);
      });
    });

    test('when the page takes longer than the limit', () {
      _started((async, harness) {
        async.elapse(
          MiniAppCubit.defaultLoadTimeout - const Duration(milliseconds: 1),
        );
        expect(harness.cubit.state.phase, MiniAppPhase.loading);

        async.elapse(const Duration(milliseconds: 1));
        expectUnavailable(harness, MiniAppUnavailableReason.timeout);
      });
    });

    test('not for a page that loaded before the limit', () {
      _started((async, harness) {
        harness.surface.events.onPageFinished();
        async.elapse(MiniAppCubit.defaultLoadTimeout * 2);

        expect(harness.cubit.state.phase, MiniAppPhase.ready);
      });
    });

    test('when the server answers the page with an error', () {
      _started((async, harness) {
        harness.surface.events.onHttpError(503);

        expectUnavailable(harness, MiniAppUnavailableReason.httpError);
      });
    });

    test('not for a redirect or a success status', () {
      _started((async, harness) {
        harness.surface.events
          ..onHttpError(302)
          ..onHttpError(204);

        expect(harness.cubit.state.phase, MiniAppPhase.loading);
      });
    });

    test('when the page cannot be loaded', () {
      _started((async, harness) {
        harness.surface.events.onLoadFailed();

        expectUnavailable(harness, MiniAppUnavailableReason.loadFailed);
      });
    });

    test('when the surface itself refuses to load', () {
      fakeAsync((async) {
        final harness = _Harness();
        harness.surface.loadError = StateError('no web view');
        unawaited(harness.cubit.start());
        async.flushMicrotasks();

        expectUnavailable(harness, MiniAppUnavailableReason.loadFailed);
        unawaited(harness.cubit.close());
        async.flushMicrotasks();
      });
    });

    test('ignores a page that finishes after it was given up', () {
      _started((async, harness) {
        async.elapse(MiniAppCubit.defaultLoadTimeout);
        harness.surface.events.onPageFinished();

        expect(harness.cubit.state.phase, MiniAppPhase.unavailable);
        expect(harness.surface.posted, isEmpty);
      });
    });
  });

  group('retry', () {
    test('loads the page again and can succeed', () {
      _started((async, harness) {
        harness.surface.events.onLoadFailed();

        unawaited(harness.cubit.start());
        async.flushMicrotasks();
        expect(harness.cubit.state.phase, MiniAppPhase.loading);
        expect(harness.surface.loaded, hasLength(2));

        harness.surface.events.onPageFinished();
        expect(harness.cubit.state.phase, MiniAppPhase.ready);
      });
    });

    test('reports the opening once, however many times it is retried', () {
      _started((async, harness) {
        harness.surface.events.onLoadFailed();
        unawaited(harness.cubit.start());
        async.flushMicrotasks();

        expect(
          harness.events.where((name) => name == ServicesTelemetry.opened),
          hasLength(1),
        );
      });
    });

    test('gives the new load its own full time limit', () {
      _started((async, harness) {
        async.elapse(MiniAppCubit.defaultLoadTimeout);
        unawaited(harness.cubit.start());
        async
          ..flushMicrotasks()
          ..elapse(
            MiniAppCubit.defaultLoadTimeout - const Duration(seconds: 1),
          );

        expect(harness.cubit.state.phase, MiniAppPhase.loading);
      });
    });
  });

  group('the resilience lab, with the mini app open', () {
    test('takes it down the moment the outage is published', () {
      _started((async, harness) {
        harness.surface.events.onPageFinished();

        harness.publish(_taken);
        async.flushMicrotasks();

        expect(harness.cubit.state.phase, MiniAppPhase.unavailable);
        expect(harness.cubit.state.reason, MiniAppUnavailableReason.outage);
      });
    });

    test('brings it back by itself when the outage is lifted', () {
      _started(create: () => _Harness()..faults = _taken, (async, harness) {
        harness.publish(ResilienceSettings.none);
        async.flushMicrotasks();

        expect(harness.cubit.state.phase, MiniAppPhase.loading);
        expect(harness.surface.loaded, hasLength(1));
      });
    });

    test('does not reload a page that failed for another reason', () {
      _started((async, harness) {
        harness.surface.events.onLoadFailed();

        harness.publish(ResilienceSettings.none);
        async.flushMicrotasks();

        expect(harness.cubit.state.reason, MiniAppUnavailableReason.loadFailed);
        expect(harness.surface.loaded, hasLength(1));
      });
    });

    test('leaves alone a mini app the outage is not about', () {
      _started(
        create: () => _Harness(serviceKey: ServiceCatalog.rechargeKey),
        (async, harness) {
          harness.surface.events.onPageFinished();

          harness.publish(_taken);
          async.flushMicrotasks();

          expect(harness.cubit.state.phase, MiniAppPhase.ready);
        },
      );
    });

    test('has no effect in a build that does not allow fault injection', () {
      _started(
        create: () => _Harness(allowFaultInjection: false)..faults = _taken,
        (async, harness) {
          expect(harness.cubit.state.phase, MiniAppPhase.loading);
          harness.surface.events.onPageFinished();

          harness.publish(_taken);
          async.flushMicrotasks();

          expect(harness.cubit.state.phase, MiniAppPhase.ready);
        },
      );
    });
  });

  group('navigation', () {
    test('lets the page move within the partner origin', () {
      _started((async, harness) {
        final verdict = harness.surface.events.onNavigation(
          Uri.parse('https://partners.example.com/partners/recharge?step=2'),
        );

        expect(verdict, NavigationVerdict.stay);
        expect(harness.cubit.state.outsideLink, isNull);
        expect(
          harness.events,
          isNot(contains(ServicesTelemetry.navigationBlocked)),
        );
      });
    });

    test('keeps another site out and offers it outside the app', () {
      _started((async, harness) {
        final target = Uri.parse('https://www.example.org/terms?user=42');

        final verdict = harness.surface.events.onNavigation(target);

        expect(verdict, NavigationVerdict.offerOutside);
        expect(harness.cubit.state.outsideLink, target);
      });
    });

    test('reports the origin of what it blocked and nothing else of it', () {
      _started((async, harness) {
        harness.surface.events.onNavigation(
          Uri.parse('https://www.example.org/terms?user=42&cedula=1710034065'),
        );

        expect(harness.parametersOf(ServicesTelemetry.navigationBlocked), {
          ServicesTelemetry.serviceKey: ServiceCatalog.travelInsuranceKey,
          ServicesTelemetry.originKey: 'https://www.example.org',
        });
      });
    });

    test('refuses a file or script address without offering it', () {
      _started((async, harness) {
        for (final target in [
          'file:///data/user/0/app/databases/firestore',
          'javascript:alert(1)',
          'http://www.example.org/',
        ]) {
          expect(
            harness.surface.events.onNavigation(Uri.parse(target)),
            NavigationVerdict.refuse,
            reason: target,
          );
        }

        expect(harness.cubit.state.outsideLink, isNull);
        expect(
          harness.parametersOf(
            ServicesTelemetry.navigationBlocked,
          )[ServicesTelemetry.originKey],
          'http://www.example.org',
        );
      });
    });

    test('keeps a frame of another site out without asking anybody', () {
      _started((async, harness) {
        final verdict = harness.surface.events.onNavigation(
          Uri.parse('https://ads.example.org/banner'),
          isMainFrame: false,
        );

        expect(verdict, NavigationVerdict.refuse);
        expect(harness.cubit.state.outsideLink, isNull);
        expect(
          harness.parametersOf(
            ServicesTelemetry.navigationBlocked,
          )[ServicesTelemetry.originKey],
          'https://ads.example.org',
        );
      });
    });

    test('lets a frame load partner content', () {
      _started((async, harness) {
        final verdict = harness.surface.events.onNavigation(
          Uri.parse('https://partners.example.com/partners/widget'),
          isMainFrame: false,
        );

        expect(verdict, NavigationVerdict.stay);
      });
    });

    test('forgets the outside link once the customer decided', () {
      _started((async, harness) {
        harness.surface.events.onNavigation(
          Uri.parse('https://www.example.org/terms'),
        );

        harness.cubit.outsideLinkHandled();

        expect(harness.cubit.state.outsideLink, isNull);
      });
    });
  });

  group('messages from the page', () {
    test('a close request is passed on', () {
      _started((async, harness) {
        harness.surface.events
          ..onPageFinished()
          ..onMessage('{"type":"close"}');

        expect(harness.cubit.state.closeRequested, isTrue);
      });
    });

    test('a completed operation keeps its reference', () {
      _started((async, harness) {
        harness.surface.events
          ..onPageFinished()
          ..onMessage('{"type":"completed","reference":"SV-00042"}');

        expect(harness.cubit.state.completed?.reference, 'SV-00042');
        expect(harness.cubit.state.phase, MiniAppPhase.ready);
      });
    });

    test('a completed operation is reported without what the page sent', () {
      _started((async, harness) {
        harness.surface.events
          ..onPageFinished()
          ..onMessage(
            '{"type":"completed","reference":"SV-00042","amount":120}',
          );

        expect(harness.parametersOf(ServicesTelemetry.completed), {
          ServicesTelemetry.serviceKey: ServiceCatalog.travelInsuranceKey,
        });
      });
    });

    test('anything outside the contract is dropped and counted', () {
      _started((async, harness) {
        harness.surface.events
          ..onPageFinished()
          ..onMessage('{"type":"open","url":"https://evil.example"}');

        expect(harness.cubit.state.closeRequested, isFalse);
        expect(harness.cubit.state.completed, isNull);
        expect(harness.parametersOf(ServicesTelemetry.messageDropped), {
          ServicesTelemetry.serviceKey: ServiceCatalog.travelInsuranceKey,
        });
      });
    });

    test('are not read before the page is shown', () {
      _started((async, harness) {
        harness.surface.events.onMessage('{"type":"close"}');

        expect(harness.cubit.state.closeRequested, isFalse);
      });
    });
  });

  group('telemetry', () {
    test('reports the opening and the load with a range of time', () {
      _started((async, harness) {
        harness.now = harness.now.add(const Duration(milliseconds: 1500));
        harness.surface.events.onPageFinished();

        expect(harness.events, [
          ServicesTelemetry.opened,
          ServicesTelemetry.loaded,
        ]);
        expect(harness.parametersOf(ServicesTelemetry.loaded), {
          ServicesTelemetry.serviceKey: ServiceCatalog.travelInsuranceKey,
          ServicesTelemetry.durationKey: '1_to_3s',
        });
      });
    });
  });

  test('stops listening to the lab when it is closed', () {
    fakeAsync((async) {
      final harness = _Harness();
      unawaited(harness.cubit.start());
      async.flushMicrotasks();
      unawaited(harness.cubit.close());
      async.flushMicrotasks();

      expect(() => harness.publish(_taken), returnsNormally);
      async
        ..flushMicrotasks()
        ..elapse(MiniAppCubit.defaultLoadTimeout);
      expect(harness.cubit.state.phase, MiniAppPhase.loading);
    });
  });
}
