import 'dart:async';
import 'dart:convert';

import 'package:app_platform/app_platform.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:feature_services/src/domain/host_contract.dart';
import 'package:feature_services/src/domain/load_bucket.dart';
import 'package:feature_services/src/domain/navigation.dart';
import 'package:feature_services/src/domain/partner_origin.dart';
import 'package:feature_services/src/domain/service_catalog.dart';
import 'package:feature_services/src/ports.dart';
import 'package:feature_services/src/services_telemetry.dart';

/// Where the container is with the partner's page.
enum MiniAppPhase { loading, ready, unavailable }

/// Why a mini app cannot be shown. [code] is what is reported.
enum MiniAppUnavailableReason {
  /// The build was not told where partner content lives.
  notConfigured('not_configured'),

  /// The device has no connection.
  offline('offline'),

  /// The partner's service is down.
  outage('outage'),

  /// The page did not finish loading in time.
  timeout('timeout'),

  /// The server answered the page request with an error.
  httpError('http_error'),

  /// The page could not be loaded at all.
  loadFailed('load_failed')
  ;

  const MiniAppUnavailableReason(this.code);

  final String code;
}

final class MiniAppState extends Equatable {
  const MiniAppState({
    required this.phase,
    this.reason,
    this.outsideLink,
    this.completed,
    this.closeRequested = false,
  });

  const MiniAppState.loading() : this(phase: MiniAppPhase.loading);

  final MiniAppPhase phase;

  /// Set while [phase] is [MiniAppPhase.unavailable].
  final MiniAppUnavailableReason? reason;

  /// An address outside the partner's origin that the page tried to open
  /// and the customer has not decided about yet.
  final Uri? outsideLink;

  /// Set once the page reported that the customer finished.
  final PartnerCompleted? completed;

  /// The page asked to be closed.
  final bool closeRequested;

  MiniAppState _with({
    Uri? Function()? outsideLink,
    PartnerCompleted? completed,
    bool? closeRequested,
  }) {
    return MiniAppState(
      phase: phase,
      reason: reason,
      outsideLink: outsideLink == null ? this.outsideLink : outsideLink(),
      completed: completed ?? this.completed,
      closeRequested: closeRequested ?? this.closeRequested,
    );
  }

  @override
  List<Object?> get props => [
    phase,
    reason,
    outsideLink,
    completed?.reference,
    completed != null,
    closeRequested,
  ];
}

/// Runs one partner's mini app: decides whether it can be opened, loads it,
/// gives up when it takes too long, keeps it on the partner's origin and
/// reads what the page tells the host.
final class MiniAppCubit extends Cubit<MiniAppState> implements MiniAppEvents {
  MiniAppCubit({
    required ServiceEntry service,
    required PartnerOrigin? origin,
    required HostContext hostContext,
    required ResiliencePolicy policy,
    required Telemetry telemetry,
    required MiniAppSurfaceFactory surfaceFactory,
    Duration loadTimeout = defaultLoadTimeout,
    DateTime Function() now = DateTime.now,
  }) : assert(service.isPartner, 'Only a partner service has a mini app.'),
       _key = service.miniApp!.key,
       _path = service.miniApp!.path,
       _outageServiceId = service.miniApp!.outageServiceId,
       _origin = origin,
       _hostContext = hostContext,
       _policy = policy,
       _telemetry = telemetry,
       _loadTimeout = loadTimeout,
       _now = now,
       super(const MiniAppState.loading()) {
    surface = surfaceFactory(this);
    _faultChanges = policy.faultChanges.listen((_) => _onFaultsChanged());
  }

  /// How long a page may take to load before the customer is told the
  /// service is not available.
  static const Duration defaultLoadTimeout = Duration(seconds: 15);

  /// First status code that means the server did not serve the page.
  static const int _firstErrorStatus = 400;

  final String _key;
  final String _path;
  final String? _outageServiceId;
  final PartnerOrigin? _origin;
  final HostContext _hostContext;
  final ResiliencePolicy _policy;
  final Telemetry _telemetry;
  final Duration _loadTimeout;
  final DateTime Function() _now;

  /// The page. The screen draws it; nothing else touches it.
  late final MiniAppSurface surface;

  late final StreamSubscription<void> _faultChanges;
  Timer? _timeout;
  DateTime? _loadStartedAt;
  bool _openingReported = false;

  /// Counts the loads started. What an earlier load answers late is told
  /// apart by it and dropped.
  int _load = 0;

  /// Opens the mini app, or opens it again after a failure.
  Future<void> start() async {
    final load = ++_load;
    _timeout?.cancel();
    emit(const MiniAppState.loading());
    if (!_openingReported) {
      _openingReported = true;
      _report(ServicesTelemetry.opened);
    }

    final origin = _origin;
    if (origin == null) return _fail(MiniAppUnavailableReason.notConfigured);

    // Nothing is requested here: it asks the policy whether the partner can
    // be reached, so an outage published by the resilience lab, a device
    // without connection and injected latency all take the same path as for
    // any other backend.
    final reachable = await _policy.run<void>(
      () async {},
      idempotent: false,
      serviceId: _outageServiceId,
    );
    if (isClosed || load != _load) return;
    if (reachable case Failed(:final failure)) {
      return _fail(_reasonFor(failure));
    }

    _loadStartedAt = _now();
    _timeout = Timer(_loadTimeout, () {
      if (load == _load) _fail(MiniAppUnavailableReason.timeout);
    });
    try {
      await surface.load(origin.resolve(_path));
    } on Object {
      if (load == _load) _fail(MiniAppUnavailableReason.loadFailed);
    }
  }

  /// The customer decided about the outside link, one way or the other.
  void outsideLinkHandled() {
    if (state.outsideLink != null) emit(state._with(outsideLink: () => null));
  }

  @override
  NavigationVerdict onNavigation(Uri target, {bool isMainFrame = true}) {
    final origin = _origin;
    if (origin == null) return NavigationVerdict.refuse;

    final verdict = judgeNavigation(target, origin);
    if (verdict == NavigationVerdict.stay) return verdict;

    // The origin only: the rest of the address may carry what the customer
    // typed.
    _report(ServicesTelemetry.navigationBlocked, {
      ServicesTelemetry.originKey:
          originOf(target) ?? ServicesTelemetry.noOrigin,
    });
    // Only what the customer asked for is offered outside. A frame that
    // points elsewhere is something the page embedded: it is kept out and
    // nobody is asked.
    final isOffered = verdict == NavigationVerdict.offerOutside && isMainFrame;
    if (isOffered && !isClosed) {
      emit(state._with(outsideLink: () => target));
    }
    return isOffered ? verdict : NavigationVerdict.refuse;
  }

  @override
  void onPageFinished() {
    final origin = _origin;
    if (isClosed || origin == null || state.phase != MiniAppPhase.loading) {
      return;
    }
    _timeout?.cancel();
    emit(const MiniAppState(phase: MiniAppPhase.ready));

    final startedAt = _loadStartedAt;
    _report(ServicesTelemetry.loaded, {
      ServicesTelemetry.durationKey: LoadBucket.of(
        startedAt == null ? Duration.zero : _now().difference(startedAt),
      ),
    });
    unawaited(
      surface.postToPage(
        jsonEncode(_hostContext.toJson()),
        targetOrigin: origin.value,
      ),
    );
  }

  @override
  void onLoadFailed() => _fail(MiniAppUnavailableReason.loadFailed);

  @override
  void onHttpError(int statusCode) {
    if (statusCode >= _firstErrorStatus) {
      _fail(MiniAppUnavailableReason.httpError);
    }
  }

  @override
  void onMessage(String raw) {
    // A page that is not shown has nothing to say to the host.
    if (isClosed || state.phase != MiniAppPhase.ready) return;

    switch (parsePartnerMessage(raw)) {
      case null:
        _report(ServicesTelemetry.messageDropped);
      case PartnerClosed():
        emit(state._with(closeRequested: true));
      case final PartnerCompleted completed:
        emit(state._with(completed: completed));
        _report(ServicesTelemetry.completed);
    }
  }

  /// A fault published or lifted by the resilience lab takes effect on the
  /// mini app that is open, not only on the next one.
  void _onFaultsChanged() {
    final serviceId = _outageServiceId;
    if (serviceId == null || isClosed) return;

    final isDown = _policy.isTakenDown(serviceId);
    final failedForOutage =
        state.phase == MiniAppPhase.unavailable &&
        state.reason == MiniAppUnavailableReason.outage;
    if (isDown && state.phase != MiniAppPhase.unavailable) {
      _fail(MiniAppUnavailableReason.outage);
    } else if (!isDown && failedForOutage) {
      unawaited(start());
    }
  }

  void _fail(MiniAppUnavailableReason reason) {
    if (isClosed) return;
    _timeout?.cancel();
    // Whatever the abandoned load reports from here on is not about what
    // the customer is looking at.
    _load++;
    emit(MiniAppState(phase: MiniAppPhase.unavailable, reason: reason));
    _report(ServicesTelemetry.unavailable, {
      ServicesTelemetry.reasonKey: reason.code,
    });
  }

  void _report(String event, [Map<String, Object> details = const {}]) {
    _telemetry.event(
      event,
      parameters: {ServicesTelemetry.serviceKey: _key, ...details},
    );
  }

  static MiniAppUnavailableReason _reasonFor(AppFailure failure) =>
      switch (failure) {
        OfflineFailure() => MiniAppUnavailableReason.offline,
        ServiceUnavailableFailure() => MiniAppUnavailableReason.outage,
        TimeoutFailure() => MiniAppUnavailableReason.timeout,
        UnexpectedFailure() => MiniAppUnavailableReason.loadFailed,
      };

  @override
  Future<void> close() async {
    _timeout?.cancel();
    await _faultChanges.cancel();
    return super.close();
  }
}
