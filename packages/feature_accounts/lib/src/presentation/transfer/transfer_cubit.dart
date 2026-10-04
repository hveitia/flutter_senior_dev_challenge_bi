import 'package:app_platform/app_platform.dart';
import 'package:equatable/equatable.dart';
import 'package:feature_accounts/src/domain/account.dart';
import 'package:feature_accounts/src/domain/transfer.dart';
import 'package:feature_accounts/src/domain/transfers_repository.dart';
import 'package:feature_accounts/src/transfers_telemetry.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Where the customer is in the transfer.
enum TransferStep { editing, confirming, sending, done }

final class TransferState extends Equatable {
  const TransferState({
    this.fromAccountId,
    this.toAccountId,
    this.amountCents = 0,
    this.concept = '',
    this.step = TransferStep.editing,
    this.showsErrors = false,
    this.outcome,
  });

  final String? fromAccountId;
  final String? toAccountId;
  final int amountCents;
  final String concept;
  final TransferStep step;

  /// Errors are shown once the customer tried to continue, not while they
  /// are still filling the form in.
  final bool showsErrors;

  /// How the last attempt ended. Set when [step] is [TransferStep.done].
  final TransferOutcome? outcome;

  TransferState copyWith({
    String? fromAccountId,
    String? toAccountId,
    int? amountCents,
    String? concept,
    TransferStep? step,
    bool? showsErrors,
    TransferOutcome? outcome,
  }) => TransferState(
    fromAccountId: fromAccountId ?? this.fromAccountId,
    toAccountId: toAccountId ?? this.toAccountId,
    amountCents: amountCents ?? this.amountCents,
    concept: concept ?? this.concept,
    step: step ?? this.step,
    showsErrors: showsErrors ?? this.showsErrors,
    outcome: outcome ?? this.outcome,
  );

  @override
  List<Object?> get props => [
    fromAccountId,
    toAccountId,
    amountCents,
    concept,
    step,
    showsErrors,
    outcome,
  ];
}

/// The transfer form, its confirmation and its result.
///
/// One order has one id, generated when the customer confirms and kept for
/// every attempt of that order: repeating it after "no pudimos enviarla"
/// settles the same order on the server, never a second one.
final class TransferCubit extends Cubit<TransferState> {
  TransferCubit({
    required TransfersRepository repository,
    required Telemetry telemetry,
    required List<Account> Function() accounts,
    String? fromAccountId,
    String Function() newId = newTransferId,
  }) : _repository = repository,
       _telemetry = telemetry,
       _accounts = accounts,
       _newId = newId,
       super(_initial(accounts(), fromAccountId, repository.unresolved)) {
    _orderId = repository.unresolved?.id;
    _telemetry.event(TransfersTelemetry.started);
  }

  final TransfersRepository _repository;
  final Telemetry _telemetry;
  final List<Account> Function() _accounts;
  final String Function() _newId;

  /// The id of the order being sent. Null until the customer confirms.
  String? _orderId;

  /// Starts from the account the customer came from, and to the other one
  /// when there are exactly two: the common case needs no picking.
  ///
  /// When an earlier order left this device without a final answer, the
  /// screen opens on it instead: until its outcome is known, the only safe
  /// thing to send is that same order, under its same id. A new form here
  /// could move the money a second time.
  static TransferState _initial(
    List<Account> all,
    String? fromAccountId,
    TransferOrder? unresolved,
  ) {
    if (unresolved != null) {
      return TransferState(
        fromAccountId: unresolved.fromAccountId,
        toAccountId: unresolved.toAccountId,
        amountCents: unresolved.amountCents,
        concept: unresolved.concept,
        step: TransferStep.done,
        outcome: const TransferNotSent(TimeoutFailure()),
      );
    }
    final accounts = transferableAccounts(all);
    final from = accounts.where((account) => account.id == fromAccountId);
    final source = from.isEmpty
        ? (accounts.isEmpty ? null : accounts.first)
        : from.first;
    final others = accounts.where((account) => account.id != source?.id);
    return TransferState(
      fromAccountId: source?.id,
      toAccountId: others.length == 1 ? others.first.id : null,
    );
  }

  List<Account> get candidates => transferableAccounts(_accounts());

  Account? _byId(String? id) {
    for (final account in candidates) {
      if (account.id == id) return account;
    }
    return null;
  }

  Account? get from => _byId(state.fromAccountId);

  Account? get to => _byId(state.toAccountId);

  /// What is wrong with the form as it stands, against the balances the
  /// device has now.
  TransferFormError? get error => validateTransfer(
    from: from,
    to: to,
    amountCents: state.amountCents,
    concept: state.concept,
  );

  bool get _isEditable => state.step == TransferStep.editing;

  void fromSelected(String accountId) {
    if (!_isEditable) return;
    emit(
      TransferState(
        fromAccountId: accountId,
        // The same account cannot be on both sides.
        toAccountId: state.toAccountId == accountId ? null : state.toAccountId,
        amountCents: state.amountCents,
        concept: state.concept,
        showsErrors: state.showsErrors,
      ),
    );
  }

  void toSelected(String accountId) {
    if (!_isEditable || accountId == state.fromAccountId) return;
    emit(state.copyWith(toAccountId: accountId));
  }

  /// [digits] is what the customer typed, the last two being the cents.
  void amountChanged(String digits) {
    if (!_isEditable) return;
    emit(state.copyWith(amountCents: amountCentsFromDigits(digits)));
  }

  void conceptChanged(String concept) {
    if (!_isEditable) return;
    emit(state.copyWith(concept: concept));
  }

  /// Moves on to the confirmation when the form has no error.
  void continueRequested() {
    if (!_isEditable) return;
    if (error != null) {
      emit(state.copyWith(showsErrors: true));
      return;
    }
    emit(state.copyWith(step: TransferStep.confirming));
  }

  /// Back from the confirmation to the form.
  void editRequested() {
    if (state.step != TransferStep.confirming) return;
    emit(state.copyWith(step: TransferStep.editing));
  }

  /// Sends the order. A second call while one is in flight does nothing,
  /// so a double tap cannot send twice.
  Future<void> confirmed() async {
    if (state.step != TransferStep.confirming) return;
    _telemetry.event(TransfersTelemetry.confirmed);
    await _send();
  }

  /// Sends the same order again after it could not be sent.
  Future<void> retryRequested() async {
    if (state.step != TransferStep.done || state.outcome is! TransferNotSent) {
      return;
    }
    await _send();
  }

  /// Back to the form after an order that cannot go any further, to place
  /// a new one under a new id.
  ///
  /// Only for an order the server said no longer matches its id: that id
  /// is spent. An order that may still be carried out keeps its id.
  void startOverRequested() {
    if (state.step != TransferStep.done) return;
    final outcome = state.outcome;
    if (outcome is! TransferStopped ||
        outcome.reason != TransferStop.orderChanged) {
      return;
    }
    _orderId = null;
    emit(
      TransferState(
        fromAccountId: state.fromAccountId,
        toAccountId: state.toAccountId,
        amountCents: state.amountCents,
        concept: state.concept,
      ),
    );
  }

  Future<void> _send() async {
    // The ids, not the accounts as listed now: an order that already left
    // is repeated as it was even if one of its accounts is no longer
    // listed, so the bank can give its final answer for it. A new order
    // only gets here through the form, which requires both accounts.
    final sourceId = state.fromAccountId;
    final destinationId = state.toAccountId;
    if (sourceId == null || destinationId == null) return;

    emit(state.copyWith(step: TransferStep.sending));
    final outcome = await _repository.send(
      TransferOrder(
        id: _orderId ??= _newId(),
        fromAccountId: sourceId,
        toAccountId: destinationId,
        amountCents: state.amountCents,
        concept: state.concept.trim(),
      ),
    );
    if (isClosed) return;
    emit(state.copyWith(step: TransferStep.done, outcome: outcome));
  }
}
