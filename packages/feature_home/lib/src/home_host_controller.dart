import 'dart:async';

import 'package:app_platform/app_platform.dart';
import 'package:feature_home/src/home_telemetry.dart';
import 'package:flutter/foundation.dart';
import 'package:module_kit/module_kit.dart';

/// The home's side of the module contract: it keeps what the modules
/// report, decides what the home as a whole can show and runs their
/// refreshers.
///
/// It knows module ids and statuses and nothing about what a module draws,
/// so the screen that listens to it stays a layout.
final class HomeHostController extends ChangeNotifier
    implements HomeModuleHost {
  HomeHostController({Telemetry telemetry = const NoopTelemetry()})
    : _telemetry = telemetry;

  /// How long one module may take to refresh before the home stops waiting
  /// for it. Above the worst case of a read that uses every retry of the
  /// resilience policy, so only a refresher that never answers hits it.
  static const Duration refresherTimeout = Duration(seconds: 30);

  final Telemetry _telemetry;

  /// The modules of the composition on screen, top to bottom.
  List<String> _moduleIds = const [];

  /// What each module last reported. A module that draws published content
  /// and nothing else has no entry and counts as shown.
  final Map<String, HomeModuleStatus> _statuses = {};
  final List<Future<void> Function()> _refreshers = [];

  bool _isRefreshing = false;
  bool _nothingToShow = false;
  bool _isDisposed = false;

  /// Whether every module that would draw something is a data module that
  /// failed. One healthy module, with or without data, is enough for the
  /// home to stay on screen.
  bool get nothingToShow => _nothingToShow;

  /// Whether every module of the composition is hidden: nothing failed and
  /// there is nothing to draw.
  bool get isBlank => _moduleIds.isNotEmpty && _moduleIds.every(isHidden);

  /// Whether some module is showing data, fresh or saved.
  bool get hasData =>
      _moduleIds.any((id) => _statuses[id] == HomeModuleStatus.ready);

  bool get isRefreshing => _isRefreshing;

  /// Whether the module with [moduleId] said it has nothing to draw.
  bool isHidden(String moduleId) =>
      _statuses[moduleId] == HomeModuleStatus.hidden;

  /// Tells the controller which modules make up the home now.
  void show(Iterable<String> moduleIds) {
    final next = List<String>.unmodifiable(moduleIds);
    if (listEquals(next, _moduleIds)) return;
    _moduleIds = next;
    _changed();
  }

  @override
  void report(String moduleId, HomeModuleStatus status) {
    if (_statuses[moduleId] == status) return;
    _statuses[moduleId] = status;
    _changed();
  }

  @override
  void withdraw(String moduleId) {
    if (_statuses.remove(moduleId) == null) return;
    _changed();
  }

  @override
  VoidCallback addRefresher(Future<void> Function() refresh) {
    _refreshers.add(refresh);
    return () => _refreshers.remove(refresh);
  }

  /// Brings every module up to date and completes when all of them have
  /// answered, failed or run out of time. Each module reports its own
  /// outcome, so one that fails or never answers keeps neither the others
  /// nor the indicator waiting.
  Future<void> refreshAll() async {
    if (_isRefreshing) return;
    _isRefreshing = true;
    _notify();

    _telemetry.event(
      HomeTelemetry.refreshRequested,
      parameters: {HomeTelemetry.modulesKey: _refreshers.length},
    );
    await Future.wait([
      for (final refresh in [..._refreshers]) _bounded(refresh),
    ]);

    _isRefreshing = false;
    _notify();
  }

  /// `Future.sync` turns a refresher that throws before returning its
  /// future into a failed future, which is then handled like any other.
  Future<void> _bounded(Future<void> Function() refresh) => Future.sync(
    refresh,
  ).timeout(refresherTimeout).then<void>((_) {}, onError: (Object _) {});

  void _changed() {
    final visible = _moduleIds.where((id) => !isHidden(id));
    final nothingToShow =
        visible.isNotEmpty &&
        visible.every((id) => _statuses[id] == HomeModuleStatus.failed);

    if (nothingToShow && !_nothingToShow) {
      _telemetry.event(HomeTelemetry.nothingToShow);
    }
    _nothingToShow = nothingToShow;
    _notify();
  }

  void _notify() {
    if (!_isDisposed) notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
