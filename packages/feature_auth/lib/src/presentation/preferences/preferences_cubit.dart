import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:feature_auth/src/domain/auth_repository.dart';
import 'package:feature_auth/src/domain/auth_result.dart';
import 'package:feature_auth/src/domain/user_profile.dart';

final class PreferencesState extends Equatable {
  const PreferencesState({
    required this.segment,
    required this.interests,
    required this.savedSegment,
    required this.savedInterests,
    this.isSaving = false,
    this.wasSaved = false,
    this.failure,
  });

  /// What is selected on screen.
  final Segment segment;
  final Set<Interest> interests;

  /// What the stored profile has.
  final Segment savedSegment;
  final Set<Interest> savedInterests;

  final bool isSaving;

  /// The last save went through. It is what tells the screen to close.
  final bool wasSaved;
  final AuthFailure? failure;

  bool get hasChanges =>
      segment != savedSegment ||
      interests.length != savedInterests.length ||
      !interests.containsAll(savedInterests);

  bool get canSave => hasChanges && !isSaving;

  @override
  List<Object?> get props => [
    segment,
    interests,
    savedSegment,
    savedInterests,
    isSaving,
    wasSaved,
    failure,
  ];
}

/// The customer changing what personalizes their home after sign-up: the
/// interests and the segment the home is composed for.
final class PreferencesCubit extends Cubit<PreferencesState> {
  PreferencesCubit({
    required AuthRepository repository,
    required Segment segment,
    required Set<Interest> interests,
  }) : _repository = repository,
       super(
         PreferencesState(
           segment: segment,
           interests: interests,
           savedSegment: segment,
           savedInterests: interests,
         ),
       );

  final AuthRepository _repository;

  void segmentSelected(Segment segment) => _edit(segment: segment);

  void interestToggled(Interest interest) {
    final interests = {...state.interests};
    if (!interests.remove(interest)) interests.add(interest);
    _edit(interests: interests);
  }

  /// Any edit also clears the failure of the last attempt: it no longer
  /// describes what is on screen.
  void _edit({Segment? segment, Set<Interest>? interests}) {
    if (state.isSaving) return;
    emit(
      PreferencesState(
        segment: segment ?? state.segment,
        interests: interests ?? state.interests,
        savedSegment: state.savedSegment,
        savedInterests: state.savedInterests,
      ),
    );
  }

  Future<void> save() async {
    if (!state.canSave) return;
    final segment = state.segment;
    final interests = state.interests;

    emit(
      PreferencesState(
        segment: segment,
        interests: interests,
        savedSegment: state.savedSegment,
        savedInterests: state.savedInterests,
        isSaving: true,
      ),
    );

    final result = await _repository.updatePreferences(
      segment: segment,
      interests: interests,
    );
    if (isClosed) return;

    emit(switch (result) {
      AuthOk() => PreferencesState(
        segment: segment,
        interests: interests,
        savedSegment: segment,
        savedInterests: interests,
        wasSaved: true,
      ),
      AuthError(:final failure) => PreferencesState(
        segment: segment,
        interests: interests,
        savedSegment: state.savedSegment,
        savedInterests: state.savedInterests,
        failure: failure,
      ),
    });
  }
}
