import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:feature_auth/src/domain/auth_result.dart';
import 'package:feature_auth/src/domain/user_profile.dart';
import 'package:feature_auth/src/presentation/preferences/preferences_cubit.dart';
import 'package:feature_auth/src/testing/auth_fakes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeAuthRepository repository;

  PreferencesCubit build() => PreferencesCubit(
    repository: repository,
    segment: Segment.family,
    interests: const {Interest.saving, Interest.travel},
  );

  setUp(() => repository = FakeAuthRepository());

  test('starts from what the profile has, with nothing to save', () {
    final cubit = build();

    expect(cubit.state.segment, Segment.family);
    expect(cubit.state.interests, {Interest.saving, Interest.travel});
    expect(cubit.state.hasChanges, isFalse);
    expect(cubit.state.canSave, isFalse);
  });

  blocTest<PreferencesCubit, PreferencesState>(
    'has changes to save after choosing another segment or interest',
    build: build,
    act: (cubit) => cubit
      ..segmentSelected(Segment.wealth)
      ..interestToggled(Interest.investing)
      ..interestToggled(Interest.travel),
    verify: (cubit) {
      expect(cubit.state.segment, Segment.wealth);
      expect(cubit.state.interests, {Interest.saving, Interest.investing});
      expect(cubit.state.canSave, isTrue);
    },
  );

  blocTest<PreferencesCubit, PreferencesState>(
    'has nothing to save again once a change is undone',
    build: build,
    act: (cubit) => cubit
      ..segmentSelected(Segment.wealth)
      ..segmentSelected(Segment.family)
      ..interestToggled(Interest.credit)
      ..interestToggled(Interest.credit),
    verify: (cubit) => expect(cubit.state.hasChanges, isFalse),
  );

  test('saves what was chosen and then has nothing left to save', () async {
    final cubit = build()
      ..segmentSelected(Segment.wealth)
      ..interestToggled(Interest.investing);

    await cubit.save();

    expect(repository.preferenceUpdates.single.segment, Segment.wealth);
    expect(repository.preferenceUpdates.single.interests, {
      Interest.saving,
      Interest.travel,
      Interest.investing,
    });
    expect(cubit.state.wasSaved, isTrue);
    expect(cubit.state.hasChanges, isFalse);
    expect(cubit.state.isSaving, isFalse);
  });

  test('says it is saving while the request is in flight, and does not send '
      'it twice', () async {
    repository.gate = Completer<void>();
    final cubit = build()..segmentSelected(Segment.wealth);

    final first = cubit.save();
    expect(cubit.state.isSaving, isTrue);
    expect(cubit.state.canSave, isFalse);
    await cubit.save();

    repository.gate!.complete();
    await first;

    expect(repository.preferenceUpdates, hasLength(1));
  });

  test('keeps the choice and says why when saving fails', () async {
    repository.updatePreferencesResult = const AuthError(AuthFailure.offline);
    final cubit = build()..segmentSelected(Segment.wealth);

    await cubit.save();

    expect(cubit.state.failure, AuthFailure.offline);
    expect(cubit.state.segment, Segment.wealth);
    expect(cubit.state.wasSaved, isFalse);
    expect(cubit.state.canSave, isTrue);
  });

  test(
    'clears the failure as soon as the customer changes something',
    () async {
      repository.updatePreferencesResult = const AuthError(AuthFailure.offline);
      final cubit = build()..segmentSelected(Segment.wealth);
      await cubit.save();

      cubit.interestToggled(Interest.credit);

      expect(cubit.state.failure, isNull);
    },
  );

  test('does nothing when there is nothing to save', () async {
    final cubit = build();

    await cubit.save();

    expect(repository.preferenceUpdates, isEmpty);
  });

  test('ignores the answer when it was closed meanwhile', () async {
    repository.gate = Completer<void>();
    final cubit = build()..segmentSelected(Segment.wealth);

    final saving = cubit.save();
    await cubit.close();
    repository.gate!.complete();

    await expectLater(saving, completes);
  });
}
