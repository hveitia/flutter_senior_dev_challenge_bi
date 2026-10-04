import 'package:app_platform/app_platform.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:feature_accounts/src/domain/accounts_repository.dart';
import 'package:feature_accounts/src/domain/movement.dart';

final class BalanceTrendState extends Equatable {
  const BalanceTrendState({
    this.movements,
    this.isComplete = false,
    this.hasFailed = false,
  });

  /// The movements of the period, or null until they have been read once.
  final List<Movement>? movements;

  /// Whether [movements] reaches back to the first day of the period.
  final bool isComplete;

  /// The last read failed. What an earlier read brought is still there.
  final bool hasFailed;

  @override
  List<Object?> get props => [movements, isComplete, hasFailed];
}

/// Reads the movements a balance trend is worked out from.
///
/// It only holds the movements. The trend itself is worked out where it is
/// drawn, from these and the balance on screen, so the line always ends at
/// the amount shown next to it.
final class BalanceTrendCubit extends Cubit<BalanceTrendState> {
  BalanceTrendCubit({
    required AccountsRepository repository,
    required this.days,
    required DateTime Function() now,
  }) : _repository = repository,
       _now = now,
       super(const BalanceTrendState());

  /// The most movements read for a trend. A period with more is drawn only
  /// for the days this many movements cover.
  static const int fetchLimit = 200;

  /// How many days the trend covers, today included.
  final int days;

  final AccountsRepository _repository;
  final DateTime Function() _now;

  Future<void> load() async {
    final now = _now();
    final firstDay = DateTime(now.year, now.month, now.day - (days - 1));

    final result = await _repository.movementsSince(
      firstDay,
      limit: fetchLimit,
    );
    if (isClosed) return;

    emit(switch (result) {
      Success(value: final snapshot) => BalanceTrendState(
        movements: snapshot.value,
        isComplete: snapshot.value.length < fetchLimit,
      ),
      Failed() => BalanceTrendState(
        movements: state.movements,
        isComplete: state.isComplete,
        hasFailed: true,
      ),
    });
  }
}
