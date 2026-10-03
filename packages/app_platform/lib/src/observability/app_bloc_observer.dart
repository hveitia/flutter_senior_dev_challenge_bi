import 'package:app_platform/src/observability/telemetry.dart';
import 'package:bloc/bloc.dart';

/// Names used when reporting what Blocs do.
abstract final class BlocTelemetry {
  static const String stateChanged = 'bloc_state_changed';
  static const String errorReason = 'bloc_error';
  static const String blocKey = 'bloc';
  static const String fromKey = 'from';
  static const String toKey = 'to';
}

/// Reports every state change and every error of every Bloc.
///
/// States and errors in a banking app carry balances, account numbers and
/// names, so nothing they contain is reported: a state is described by its
/// type (and by its value only when it is an enum), an error by its type and
/// its stack trace.
final class AppBlocObserver extends BlocObserver {
  const AppBlocObserver(this._telemetry);

  final Telemetry _telemetry;

  @override
  void onChange(BlocBase<dynamic> bloc, Change<dynamic> change) {
    super.onChange(bloc, change);
    _telemetry.log(
      LogLevel.debug,
      BlocTelemetry.stateChanged,
      context: {
        BlocTelemetry.blocKey: '${bloc.runtimeType}',
        BlocTelemetry.fromKey: _describe(change.currentState),
        BlocTelemetry.toKey: _describe(change.nextState),
      },
    );
  }

  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    _telemetry.recordError(
      RedactedError(error.runtimeType),
      stackTrace,
      reason: '${BlocTelemetry.errorReason}:${bloc.runtimeType}',
    );
    super.onError(bloc, error, stackTrace);
  }

  String _describe(Object? state) {
    final type = '${state.runtimeType}';
    return state is Enum ? '$type.${state.name}' : type;
  }
}

/// Stands in for an error whose message may contain customer data.
final class RedactedError implements Exception {
  const RedactedError(this.type);

  final Type type;

  @override
  String toString() => 'RedactedError($type)';
}
