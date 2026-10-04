import 'package:feature_home/feature_home.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/home_fixtures.dart';

void main() {
  const registered = {'totalBalance', 'accountCarousel', 'recentMovements'};

  HomeComposition compose(List<Map<String, Object?>> modules) {
    final document = configDocument(segments: {'starting': modules});
    return composeHome(segmentOf(document, 'starting'), registered);
  }

  List<String> ids(HomeComposition composition) => [
    for (final module in composition.modules) module.id,
  ];

  test('keeps the modules in the order they were published', () {
    final composition = compose([
      moduleDocument('movements', 'recentMovements'),
      moduleDocument('balance', 'totalBalance'),
      moduleDocument('accounts', 'accountCarousel'),
    ]);

    expect(ids(composition), ['movements', 'balance', 'accounts']);
    expect(composition.skippedTypes, isEmpty);
  });

  test('leaves out a module that was published as not visible', () {
    final composition = compose([
      moduleDocument('balance', 'totalBalance'),
      moduleDocument('accounts', 'accountCarousel', visible: false),
    ]);

    expect(ids(composition), ['balance']);
    expect(composition.skippedTypes, isEmpty);
  });

  test('skips a type this version of the app cannot draw, and names it', () {
    final composition = compose([
      moduleDocument('balance', 'totalBalance'),
      moduleDocument('investments', 'investmentSummary'),
      moduleDocument('services', 'serviceRecommendations'),
      moduleDocument('movements', 'recentMovements'),
    ]);

    expect(ids(composition), ['balance', 'movements']);
    expect(composition.skippedTypes, {
      'investmentSummary',
      'serviceRecommendations',
    });
  });

  test('does not name an unknown type that was not going to be shown', () {
    final composition = compose([
      moduleDocument('balance', 'totalBalance'),
      moduleDocument('investments', 'investmentSummary', visible: false),
    ]);

    expect(composition.skippedTypes, isEmpty);
  });
}
