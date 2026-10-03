import 'dart:async';

import 'package:app_platform/src/config/config_repository.dart';
import 'package:app_platform/src/config/home_config.dart';
import 'package:bloc/bloc.dart';

final class RemoteConfigState {
  const RemoteConfigState({this.snapshot, this.segmentId});

  final ConfigSnapshot? snapshot;

  /// The customer's segment as the app knows it. It may not exist in the
  /// published document; [segment] resolves the one actually used.
  final String? segmentId;

  bool get isReady => snapshot != null;

  HomeConfig? get config => snapshot?.config;

  int? get version => snapshot?.config.configVersion;

  ConfigOrigin? get origin => snapshot?.origin;

  SegmentConfig? get segment => snapshot?.config.segmentFor(segmentId);
}

/// The configuration the app is running with, kept current as the backoffice
/// publishes changes.
final class RemoteConfigCubit extends Cubit<RemoteConfigState> {
  RemoteConfigCubit(this._repository, {String? segmentId})
    : super(RemoteConfigState(segmentId: segmentId));

  final ConfigRepository _repository;
  StreamSubscription<ConfigSnapshot>? _subscription;

  void start() {
    _subscription ??= _repository.watch().listen(
      (snapshot) => emit(
        RemoteConfigState(snapshot: snapshot, segmentId: state.segmentId),
      ),
      onError: addError,
    );
  }

  void selectSegment(String? segmentId) {
    emit(RemoteConfigState(snapshot: state.snapshot, segmentId: segmentId));
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
