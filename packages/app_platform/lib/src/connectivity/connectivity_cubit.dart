import 'dart:async';

import 'package:bloc/bloc.dart';

/// Tells whether the device has a network connection.
abstract interface class ConnectivityMonitor {
  Future<bool> isOnline();

  /// Emits on every change: `true` when connected, `false` when not.
  Stream<bool> get onlineChanges;
}

/// What the app tells the customer about the connection.
enum ConnectivityStatus {
  online,
  offline,

  /// Connected, but requests are taking longer than they should.
  slow,

  /// Just reconnected. Shown briefly, then it becomes [online] or [slow].
  restored,
}

/// One connection status for the whole app, combining the device's network
/// state with how slowly the backend is answering.
final class ConnectivityCubit extends Cubit<ConnectivityStatus> {
  ConnectivityCubit({
    required ConnectivityMonitor monitor,
    Stream<bool> slowChanges = const Stream.empty(),
    this.restoredFor = defaultRestoredFor,
  }) : _monitor = monitor,
       _slowChanges = slowChanges,
       super(ConnectivityStatus.online);

  static const Duration defaultRestoredFor = Duration(seconds: 4);

  /// How long [ConnectivityStatus.restored] is shown after reconnecting.
  final Duration restoredFor;

  final ConnectivityMonitor _monitor;
  final Stream<bool> _slowChanges;

  StreamSubscription<bool>? _onlineSubscription;
  StreamSubscription<bool>? _slowSubscription;
  Timer? _restoredTimer;
  bool _online = true;
  bool _slow = false;

  void start() {
    if (_onlineSubscription != null) return;

    _onlineSubscription = _monitor.onlineChanges.listen(_onConnection);
    _slowSubscription = _slowChanges.listen(_onSlow);
    unawaited(_readInitialConnection());
  }

  Future<void> _readInitialConnection() async {
    final online = await _monitor.isOnline();
    if (!isClosed) _onConnection(online);
  }

  void _onConnection(bool online) {
    if (online == _online) return;
    _online = online;
    _restoredTimer?.cancel();

    if (!online) {
      emit(ConnectivityStatus.offline);
      return;
    }

    emit(ConnectivityStatus.restored);
    _restoredTimer = Timer(restoredFor, () => emit(_connectedStatus));
  }

  void _onSlow(bool slow) {
    _slow = slow;
    // Offline and the restored notice take precedence; the slow state is
    // picked up when the notice ends.
    final showsConnectedStatus =
        _online && !(_restoredTimer?.isActive ?? false);
    if (showsConnectedStatus) emit(_connectedStatus);
  }

  ConnectivityStatus get _connectedStatus =>
      _slow ? ConnectivityStatus.slow : ConnectivityStatus.online;

  @override
  Future<void> close() async {
    _restoredTimer?.cancel();
    await Future.wait(
      [_onlineSubscription?.cancel(), _slowSubscription?.cancel()].nonNulls,
    );
    return super.close();
  }
}
