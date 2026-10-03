import 'package:app_platform/app_platform.dart';
import 'package:app_platform/testing.dart';
import 'package:bloc/bloc.dart';
import 'package:flutter_test/flutter_test.dart';

const String _accountNumber = '22004821';
const String _amount = '4820.35';
const String _customerName = 'Valentina';

final class _BalanceState {
  const _BalanceState(this.cents);

  final int cents;

  @override
  String toString() =>
      '_BalanceState($_customerName, account $_accountNumber, \$$_amount)';
}

final class _BalanceCubit extends Cubit<_BalanceState> {
  _BalanceCubit() : super(const _BalanceState(0));

  void load() => emit(const _BalanceState(482035));

  void fail() => addError(
    StateError('No balance for account $_accountNumber of $_customerName'),
    StackTrace.current,
  );
}

enum _Step { idle, sending }

final class _StepCubit extends Cubit<_Step> {
  _StepCubit() : super(_Step.idle);

  void send() => emit(_Step.sending);
}

/// Everything the observer handed to telemetry, flattened to text.
String _everythingReported(InMemoryTelemetry telemetry) {
  return [
    for (final entry in telemetry.logs) ...[entry.message, '${entry.context}'],
    for (final report in telemetry.errors) ...[
      '${report.error}',
      '${report.reason}',
    ],
    for (final event in telemetry.events) ...[
      event.name,
      '${event.parameters}',
    ],
  ].join('\n');
}

void main() {
  late InMemoryTelemetry telemetry;
  late BlocObserver previousObserver;

  setUp(() {
    telemetry = InMemoryTelemetry();
    previousObserver = Bloc.observer;
    Bloc.observer = AppBlocObserver(telemetry);
  });

  tearDown(() => Bloc.observer = previousObserver);

  group('a state change', () {
    test('is logged with the bloc and the state types', () async {
      final cubit = _BalanceCubit()..load();

      final entry = telemetry.logs.single;
      expect(entry.level, LogLevel.debug);
      expect(entry.message, BlocTelemetry.stateChanged);
      expect(entry.context, {
        BlocTelemetry.blocKey: '_BalanceCubit',
        BlocTelemetry.fromKey: '_BalanceState',
        BlocTelemetry.toKey: '_BalanceState',
      });
      await cubit.close();
    });

    test('names the value when the state is an enum', () async {
      final cubit = _StepCubit()..send();

      expect(telemetry.logs.single.context, {
        BlocTelemetry.blocKey: '_StepCubit',
        BlocTelemetry.fromKey: '_Step.idle',
        BlocTelemetry.toKey: '_Step.sending',
      });
      await cubit.close();
    });

    test('never reports what the state contains', () async {
      final cubit = _BalanceCubit()..load();

      final reported = _everythingReported(telemetry);
      expect(reported, isNot(contains(_amount)));
      expect(reported, isNot(contains(_accountNumber)));
      expect(reported, isNot(contains(_customerName)));
      await cubit.close();
    });
  });

  group('an error', () {
    test('is reported with the bloc, the error type and the stack', () async {
      final cubit = _BalanceCubit()..fail();

      final report = telemetry.errors.single;
      expect(report.reason, '${BlocTelemetry.errorReason}:_BalanceCubit');
      expect('${report.error}', contains('StateError'));
      expect('${report.stackTrace}', contains('app_bloc_observer_test.dart'));
      expect(report.fatal, isFalse);
      await cubit.close();
    });

    test('never reports the message of the error', () async {
      final cubit = _BalanceCubit()..fail();

      final reported = _everythingReported(telemetry);
      expect(reported, isNot(contains(_accountNumber)));
      expect(reported, isNot(contains(_customerName)));
      await cubit.close();
    });
  });
}
