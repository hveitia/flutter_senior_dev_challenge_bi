import 'package:feature_services/src/data/page_events.dart';
import 'package:feature_services/src/domain/navigation.dart';
import 'package:feature_services/src/ports.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records what reaches the container and lets a navigation only stay on
/// `partners.example.com`.
final class _RecordingEvents implements MiniAppEvents {
  final List<(Uri target, bool isMainFrame)> navigations = [];
  final List<int> httpErrors = [];
  final List<(String raw, Uri? page)> messages = [];
  int finished = 0;
  int failed = 0;

  @override
  NavigationVerdict onNavigation(Uri target, {bool isMainFrame = true}) {
    navigations.add((target, isMainFrame));
    return target.host == 'partners.example.com'
        ? NavigationVerdict.stay
        : NavigationVerdict.offerOutside;
  }

  @override
  void onPageFinished() => finished++;

  @override
  void onLoadFailed() => failed++;

  @override
  void onHttpError(int statusCode) => httpErrors.add(statusCode);

  @override
  void onMessage(String raw, {required Uri? page}) => messages.add((raw, page));
}

void main() {
  final page = Uri.parse('https://partners.example.com/partners/recharge');

  late _RecordingEvents events;
  late PageEvents pageEvents;

  setUp(() {
    events = _RecordingEvents();
    pageEvents = PageEvents(events)..page = page;
  });

  group('mayNavigate', () {
    test('follows what the container lets stay', () {
      expect(
        pageEvents.mayNavigate('$page/done', isMainFrame: true),
        isTrue,
      );
    });

    test('does not follow what the container keeps out', () {
      expect(
        pageEvents.mayNavigate(
          'https://www.example.org/terms',
          isMainFrame: true,
        ),
        isFalse,
      );
    });

    test('tells the container whether it is the page or a frame', () {
      pageEvents
        ..mayNavigate('$page/a', isMainFrame: true)
        ..mayNavigate('$page/b', isMainFrame: false);

      expect(events.navigations.map((navigation) => navigation.$2), [
        true,
        false,
      ]);
    });

    test('never follows text that is not an address', () {
      expect(pageEvents.mayNavigate('http://[bad', isMainFrame: true), isFalse);
      expect(events.navigations, isEmpty);
    });
  });

  group('resourceFailed', () {
    test('reports a failure of the page itself', () {
      pageEvents.resourceFailed(isForMainFrame: true);

      expect(events.failed, 1);
    });

    test('ignores a failure of something inside the page', () {
      pageEvents.resourceFailed(isForMainFrame: false);

      expect(events.failed, 0);
    });

    test('takes a failure of unknown scope to be of the page', () {
      pageEvents.resourceFailed(isForMainFrame: null);

      expect(events.failed, 1);
    });
  });

  group('httpError', () {
    test('reports the status the server gave for the page', () {
      pageEvents.httpError(statusCode: 503, requested: page);

      expect(events.httpErrors, [503]);
    });

    test('ignores the status of anything else the page requested', () {
      pageEvents.httpError(
        statusCode: 404,
        requested: Uri.parse('https://partners.example.com/favicon.ico'),
      );

      expect(events.httpErrors, isEmpty);
    });

    test('follows the page as it moves within the partner origin', () {
      final next = Uri.parse('$page/done');
      pageEvents
        ..mayNavigate('$next', isMainFrame: true)
        ..httpError(statusCode: 500, requested: next)
        ..httpError(statusCode: 404, requested: page);

      expect(events.httpErrors, [500]);
    });

    test('does not take a frame for the page', () {
      final frame = Uri.parse('$page/frame');
      pageEvents
        ..mayNavigate('$frame', isMainFrame: false)
        ..httpError(statusCode: 500, requested: frame);

      expect(events.httpErrors, isEmpty);
    });

    test('compares addresses without their fragment', () {
      pageEvents.httpError(
        statusCode: 500,
        requested: Uri.parse('$page#form'),
      );

      expect(events.httpErrors, [500]);
    });

    test('ignores a report that lacks the status or the address', () {
      pageEvents
        ..httpError(statusCode: null, requested: page)
        ..httpError(statusCode: 500, requested: null);

      expect(events.httpErrors, isEmpty);
    });

    test('reports nothing before any page was asked for', () {
      PageEvents(events).httpError(statusCode: 500, requested: page);

      expect(events.httpErrors, isEmpty);
    });
  });

  test('passes on that the page finished, and what it posts with where the '
      'web view is', () {
    pageEvents
      ..pageFinished()
      ..message('{"type":"close"}', currentUrl: '$page#form')
      ..message('{"type":"close"}', currentUrl: null);

    expect(events.finished, 1);
    expect(events.messages, [
      ('{"type":"close"}', Uri.parse('$page#form')),
      ('{"type":"close"}', null),
    ]);
  });
}
