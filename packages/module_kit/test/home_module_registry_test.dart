import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:module_kit/module_kit.dart';

Widget _balance(BuildContext context, HomeModuleContext module) =>
    const SizedBox.shrink();

Widget _movements(BuildContext context, HomeModuleContext module) =>
    const SizedBox.shrink();

void main() {
  late HomeModuleRegistry registry;

  setUp(() => registry = HomeModuleRegistry());

  test('hands back the builder registered for a type', () {
    registry
      ..register('totalBalance', _balance)
      ..register('recentMovements', _movements);

    expect(registry.builderFor('totalBalance'), same(_balance));
    expect(registry.builderFor('recentMovements'), same(_movements));
  });

  test('has no builder for a type nobody registered', () {
    registry.register('totalBalance', _balance);

    expect(registry.builderFor('investmentSummary'), isNull);
  });

  test('lists the registered types', () {
    registry
      ..register('totalBalance', _balance)
      ..register('recentMovements', _movements);

    expect(registry.types, {'totalBalance', 'recentMovements'});
  });

  test('refuses a second owner for the same type', () {
    registry.register('totalBalance', _balance);

    expect(
      () => registry.register('totalBalance', _movements),
      throwsStateError,
    );
    expect(registry.builderFor('totalBalance'), same(_balance));
  });
}
