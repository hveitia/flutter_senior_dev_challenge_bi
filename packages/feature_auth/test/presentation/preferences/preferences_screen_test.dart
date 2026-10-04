import 'package:design_system/design_system.dart';
import 'package:feature_auth/src/domain/auth_result.dart';
import 'package:feature_auth/src/domain/user_profile.dart';
import 'package:feature_auth/src/presentation/preferences/preferences_cubit.dart';
import 'package:feature_auth/src/presentation/preferences/preferences_screen.dart';
import 'package:feature_auth/src/testing/auth_fakes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/pump_auth.dart';

void main() {
  late FakeAuthRepository repository;
  var savedCalls = 0;

  Future<void> pump(
    WidgetTester tester, {
    bool online = true,
    double textScale = 1,
  }) async {
    await pumpAuth(
      tester,
      PreferencesScreen(onSaved: () => savedCalls++),
      providers: [
        BlocProvider<PreferencesCubit>(
          create: (_) => PreferencesCubit(
            repository: repository,
            segment: Segment.family,
            interests: const {Interest.saving},
          ),
        ),
      ],
      online: online,
      textScale: textScale,
    );
  }

  Future<void> save(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Guardar cambios'));
    await tester.tap(find.text('Guardar cambios'));
    await tester.pump();
  }

  bool isSelected(WidgetTester tester, String segment) => tester
      .widget<RadioCard>(find.widgetWithText(RadioCard, segment))
      .selected;

  setUp(() {
    repository = FakeAuthRepository();
    savedCalls = 0;
  });

  testWidgets('shows what the profile has', (tester) async {
    await pump(tester);

    expect(find.text('Personalización'), findsOneWidget);
    expect(isSelected(tester, 'Familia'), isTrue);
    expect(isSelected(tester, 'Patrimonio'), isFalse);
    expect(
      tester.widget<AppChip>(find.widgetWithText(AppChip, 'Ahorrar')).selected,
      isTrue,
    );
  });

  testWidgets('has nothing to save until something changes', (tester) async {
    await pump(tester);

    await save(tester);

    expect(repository.preferenceUpdates, isEmpty);
  });

  testWidgets('saves the new segment and interests and tells whoever opened '
      'it', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Invertir'));
    await tester.ensureVisible(find.text('Patrimonio'));
    await tester.tap(find.text('Patrimonio'));
    await tester.pump();
    await save(tester);
    await tester.pump();

    final update = repository.preferenceUpdates.single;
    expect(update.segment, Segment.wealth);
    expect(update.interests, {Interest.saving, Interest.investing});
    expect(savedCalls, 1);
  });

  testWidgets('says why when saving fails and stays open with the choice', (
    tester,
  ) async {
    repository.updatePreferencesResult = const AuthError(
      AuthFailure.unavailable,
    );
    await pump(tester);

    await tester.ensureVisible(find.text('Patrimonio'));
    await tester.tap(find.text('Patrimonio'));
    await tester.pump();
    await save(tester);
    await tester.pump();

    expect(find.byType(InlineAlert), findsOneWidget);
    expect(isSelected(tester, 'Patrimonio'), isTrue);
    expect(savedCalls, 0);
  });

  testWidgets('says so before trying when the device is offline', (
    tester,
  ) async {
    await pump(tester, online: false);

    expect(
      find.text('Sin conexión. Revisa tu red e intenta de nuevo'),
      findsOneWidget,
    );
  });

  testWidgets('fits a small phone with large text', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await pump(tester, textScale: 1.3);

    expect(tester.takeException(), isNull);
  });
}
