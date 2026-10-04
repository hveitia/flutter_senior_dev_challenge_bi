import 'dart:async';

import 'package:app_platform/app_platform.dart';
import 'package:equatable/equatable.dart';
import 'package:feature_notifications/src/domain/inbox_item.dart';
import 'package:feature_notifications/src/domain/notifications_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Why the inbox could not be brought up to date.
enum InboxFailure {
  offline,
  timeout,
  unavailable,
  unexpected
  ;

  static InboxFailure of(Object error) => switch (error) {
    OfflineFailure() => offline,
    TimeoutFailure() => timeout,
    ServiceUnavailableFailure() => unavailable,
    _ => unexpected,
  };
}

/// What is known about the inbox: the last notifications it can show, where
/// they came from, and whether bringing them up to date is in progress or
/// failed. Showing saved notifications and failing to refresh them are
/// independent facts, as for accounts.
final class InboxState extends Equatable {
  const InboxState({
    this.items,
    this.fromCache = false,
    this.failure,
    this.isLoading = false,
  });

  /// Null until something can be shown.
  final List<InboxItem>? items;
  final bool fromCache;
  final InboxFailure? failure;
  final bool isLoading;

  bool get hasItems => items != null;

  /// Nothing to show yet and nothing has failed: draw the placeholders.
  bool get isWaiting => !hasItems && failure == null;

  /// Nothing to show because loading failed: draw the error.
  bool get hasFailed => !hasItems && failure != null;

  /// Something is shown but could not be brought up to date. Without a
  /// connection it needs no notice of its own: the app already says it is
  /// offline.
  bool get needsOutdatedNotice =>
      hasItems && failure != null && failure != InboxFailure.offline;

  int get unreadCount => items?.where((item) => !item.isRead).length ?? 0;

  @override
  List<Object?> get props => [items, fromCache, failure, isLoading];
}

/// Follows the customer's inbox from sign-in to sign-out.
///
/// It is created with the session, not with the inbox screen, so the bell
/// of the home knows whether something is unread.
final class InboxCubit extends Cubit<InboxState> {
  InboxCubit(this._repository) : super(const InboxState());

  final NotificationsRepository _repository;
  StreamSubscription<InboxSnapshot>? _subscription;

  /// A listener that reported an error delivers nothing more: the next
  /// retry has to listen again, not only ask once.
  bool _listenerBroke = false;

  /// Starts listening and asks the backend once.
  void start() {
    if (_subscription != null) return;
    _listen();
    unawaited(refresh());
  }

  void _listen() {
    _listenerBroke = false;
    _subscription = _repository.watchInbox().listen(
      _onDelivery,
      onError: _onListenerError,
    );
  }

  void _onDelivery(InboxSnapshot snapshot) {
    if (isClosed) return;
    // A saved copy that is empty on a device that never synchronized says
    // nothing about the inbox, so it is not shown as "no notifications".
    if (snapshot.fromCache && snapshot.items.isEmpty && !state.hasItems) {
      return;
    }
    emit(
      InboxState(
        items: snapshot.items,
        fromCache: snapshot.fromCache,
        // Fresh data proves the backend is reachable again.
        failure: snapshot.fromCache ? state.failure : null,
        isLoading: state.isLoading,
      ),
    );
  }

  void _onListenerError(Object error) {
    if (isClosed) return;
    _listenerBroke = true;
    emit(
      InboxState(
        items: state.items,
        fromCache: state.fromCache,
        failure: InboxFailure.of(error),
      ),
    );
  }

  /// Asks the backend for the inbox as it is now.
  Future<void> refresh() async {
    if (state.isLoading) return;
    emit(
      InboxState(
        items: state.items,
        fromCache: state.fromCache,
        failure: state.failure,
        isLoading: true,
      ),
    );

    final result = await _repository.refreshInbox();
    if (isClosed) return;

    emit(switch (result) {
      Success(value: final snapshot) => InboxState(
        items: snapshot.items,
        fromCache: snapshot.fromCache,
      ),
      Failed(:final failure) => InboxState(
        items: state.items,
        fromCache: state.fromCache,
        failure: InboxFailure.of(failure),
      ),
    });
  }

  /// The customer asked to try again after a failure.
  Future<void> retry() async {
    if (_listenerBroke) {
      await _subscription?.cancel();
      if (isClosed) return;
      _listen();
    }
    await refresh();
  }

  /// Marks [item] as read. The screen shows it at once; if the backend
  /// refuses, it goes back to unread.
  Future<void> markRead(InboxItem item) async {
    if (item.isRead) return;
    _replace(item.id, (current) => current.asRead());

    final result = await _repository.markRead(item.id);
    if (isClosed || result is Success<void>) return;
    _replace(item.id, (_) => item);
  }

  void _replace(String id, InboxItem Function(InboxItem current) change) {
    final items = state.items;
    if (items == null) return;
    emit(
      InboxState(
        items: [
          for (final each in items) each.id == id ? change(each) : each,
        ],
        fromCache: state.fromCache,
        failure: state.failure,
        isLoading: state.isLoading,
      ),
    );
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
