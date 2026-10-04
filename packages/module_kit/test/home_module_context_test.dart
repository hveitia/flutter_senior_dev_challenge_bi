import 'package:flutter_test/flutter_test.dart';
import 'package:module_kit/testing.dart';

void main() {
  group('props are read leniently', () {
    final module = moduleContext(
      props: {
        'title': 'Protege tu próximo viaje',
        'limit': 4,
        'ratio': 1.5,
        'action': {'label': 'Cotizar', 'destination': 'services'},
        'actions': [
          {'label': 'Pagar'},
          'not an object',
          {'label': 'Más'},
        ],
      },
    );

    test('a text is returned as it was published', () {
      expect(module.text('title'), 'Protege tu próximo viaje');
    });

    test('a missing, empty or mistyped text is null', () {
      expect(module.text('body'), isNull);
      expect(module.text('limit'), isNull);
      expect(moduleContext(props: {'title': '  '}).text('title'), isNull);
    });

    test('a whole number is returned, anything else is null', () {
      expect(module.integer('limit'), 4);
      expect(module.integer('ratio'), isNull);
      expect(module.integer('title'), isNull);
      expect(module.integer('missing'), isNull);
    });

    test('an object is returned, anything else is null', () {
      expect(module.object('action'), {
        'label': 'Cotizar',
        'destination': 'services',
      });
      expect(module.object('title'), isNull);
      expect(module.object('missing'), isNull);
    });

    test('a list keeps its objects and drops everything else', () {
      expect(module.objects('actions'), [
        {'label': 'Pagar'},
        {'label': 'Más'},
      ]);
    });

    test('a missing or mistyped list is empty', () {
      expect(module.objects('missing'), isEmpty);
      expect(module.objects('title'), isEmpty);
    });
  });
}
