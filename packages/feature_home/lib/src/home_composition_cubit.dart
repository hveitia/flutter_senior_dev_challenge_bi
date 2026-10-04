import 'dart:async';

import 'package:app_platform/app_platform.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:feature_home/src/home_composition.dart';
import 'package:feature_home/src/home_telemetry.dart';
import 'package:module_kit/module_kit.dart';

final class HomeCompositionState extends Equatable {
  const HomeCompositionState({this.composition, this.configVersion});

  /// Null until a configuration is in use.
  final HomeComposition? composition;

  /// Version of the configuration the composition was made from.
  final int? configVersion;

  @override
  List<Object?> get props => [composition, configVersion];
}

/// The composition of the home, kept current as the configuration changes:
/// a new document published from the backoffice, or a different segment for
/// the customer, recomposes the home without restarting the app.
final class HomeCompositionCubit extends Cubit<HomeCompositionState> {
  HomeCompositionCubit({
    required RemoteConfigCubit config,
    required HomeModuleRegistry registry,
    Telemetry telemetry = const NoopTelemetry(),
  }) : _registry = registry,
       _telemetry = telemetry,
       super(const HomeCompositionState()) {
    _compose(config.state);
    _subscription = config.stream.listen(_compose);
  }

  final HomeModuleRegistry _registry;
  final Telemetry _telemetry;

  late final StreamSubscription<RemoteConfigState> _subscription;

  /// Types already reported as skipped, so a type is reported once however
  /// many times the home is composed again.
  final Set<String> _reported = {};

  void _compose(RemoteConfigState config) {
    final segment = config.segment;
    if (segment == null) return;

    final composition = composeHome(segment, _registry.types);
    for (final type in composition.skippedTypes) {
      if (_reported.add(type)) {
        _telemetry.event(
          HomeTelemetry.moduleSkipped,
          parameters: {HomeTelemetry.typeKey: type},
        );
      }
    }

    emit(
      HomeCompositionState(
        composition: composition,
        configVersion: config.version,
      ),
    );
  }

  @override
  Future<void> close() async {
    await _subscription.cancel();
    return super.close();
  }
}
