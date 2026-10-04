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
    required this.load,
    this.reason,
    this.outsideLink,
    this.completed,
    this.closeRequested = false,
  });

  const MiniAppState.loading(int load)
    : this(phase: MiniAppPhase.loading, load: load);

  final MiniAppPhase phase;

  /// Which load this state is about. Every load has its own surface, so the
  /// screen swaps the page it draws when this changes.
  final int load;

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
      load: load,
      reason: reason,
      outsideLink: outsideLink == null ? this.outsideLink : outsideLink(),
      completed: completed ?? this.completed,
      closeRequested: closeRequested ?? this.closeRequested,
    );
  }

  @override
  List<Object?> get props => [
    phase,
    load,
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
///
/// Every load gets a surface of its own. What a surface reports is only
/// heard while its load is the current one, so a page that was given up, or
/// replaced by a retry, cannot change what the customer sees by answering
/// late.
final class MiniAppCubit extends Cubit<MiniAppState> {
  MiniAppCubit({
    required ServiceEntry service,
    required PartnerOrigin? origin,
    required HostContext Function() hostContext,
    required ResiliencePolicy policy,
    required Telemetry telemetry,
    required MiniAppSurfaceFactory surfaceFactory,
    Future<void> Function()? ensureClean,
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
       _surfaceFactory = surfaceFactory,
       _ensureClean = ensureClean,
       _loadTimeout = loadTimeout,
       _now = now,
       super(const MiniAppState.loading(0)) {
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

  /// Asked every time a page is told its context, so a page loaded after
  /// the customer changed segment hears the new one.
  final HostContext Function() _hostContext;
  final ResiliencePolicy _policy;
  final Telemetry _telemetry;
  final MiniAppSurfaceFactory _surfaceFactory;

  /// Removes what an earlier customer's mini apps left on the device when
  /// the clean-up at their sign-out did not finish.
  final Future<void> Function()? _ensureClean;
  final Duration _loadTimeout;
  final DateTime Function() _now;

  /// The page of the current load, or null before the first one. The
  /// screen draws it; nothing else touches it.
  MiniAppSurface? get surface => _surface;
  MiniAppSurface? _surface;

  late final StreamSubscription<void> _faultChanges;
  Timer? _timeout;
  DateTime? _loadStartedAt;
  bool _openingReported = false;

  /// Counts the loads started and given up. What an earlier load answers
  /// late is told apart by it and dropped.
  int _load = 0;

  /// Opens the mini app, or opens it again: after a failure, on the
  /// customer's request or when an outage is lifted.
  Future<void> start() async {
    if (isClosed) return;
    final load = ++_load;
    _timeout?.cancel();
    final surface = _surface = _surfaceFactory(_LoadEvents(this, load));
    emit(MiniAppState.loading(load));
    if (!_openingReported) {
      _openingReported = true;
      _report(ServicesTelemetry.opened);
    }

    final origin = _origin;
    if (origin == null) return _fail(MiniAppUnavailableReason.notConfigured);

    try {
      await _ensureClean?.call();
    } on Object {
      // Showing a partner's page on top of what another customer's left
      // behind is worse than not showing it.
      if (load == _load) _fail(MiniAppUnavailableReason.loadFailed);
      return;
    }
    if (isClosed || load != _load) return;

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
    // The dialog may outlive the mini app: partners switched off, or the
    // customer left, while it was open.
    if (isClosed || state.outsideLink == null) return;
    emit(state._with(outsideLink: () => null));
  }

  NavigationVerdict _navigation(Uri target, {required bool isMainFrame}) {
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

  void _pageFinished() {
    final origin = _origin;
    if (isClosed || origin == null) return;
    if (state.phase == MiniAppPhase.ready) {
      // The page moved to another page of the partner. A new document has
      // forgotten the context, so it is told again.
      return _sendContext(origin);
    }
    if (state.phase != MiniAppPhase.loading) return;
    _timeout?.cancel();
    emit(MiniAppState(phase: MiniAppPhase.ready, load: _load));

    final startedAt = _loadStartedAt;
    _report(ServicesTelemetry.loaded, {
      ServicesTelemetry.durationKey: LoadBucket.of(
        startedAt == null ? Duration.zero : _now().difference(startedAt),
      ),
    });
    _sendContext(origin);
  }

  void _sendContext(PartnerOrigin origin) {
    unawaited(
      _surface?.postToPage(
        jsonEncode(_hostContext().toJson()),
        targetOrigin: origin.value,
      ),
    );
  }

  void _httpError(int statusCode) {
    if (statusCode >= _firstErrorStatus) {
      _fail(MiniAppUnavailableReason.httpError);
    }
  }

  void _message(String raw, Uri? page) {
    if (isClosed) return;

    // The channel can be reached by any frame of the page, and by a page
    // that is not shown yet. A message counts only when the page is shown
    // and the web view is still on the partner's origin; anything else is
    // dropped and counted, like a message that breaks the contract.
    final origin = _origin;
    final isFromPartner = page != null && origin != null && origin.allows(page);
    final message = state.phase == MiniAppPhase.ready && isFromPartner
        ? parsePartnerMessage(raw)
        : null;

    switch (message) {
      case null:
        _report(ServicesTelemetry.messageDropped);
      case PartnerClosed():
        emit(state._with(closeRequested: true));
      case final PartnerCompleted completed:
        // The first one stands: a page that reports again changes nothing.
        if (state.completed != null) return;
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

  /// Gives the current load up. It also ends it: whatever its surface
  /// reports afterwards is dropped, which is what makes a failure reported
  /// twice count once.
  void _fail(MiniAppUnavailableReason reason) {
    if (isClosed) return;
    _timeout?.cancel();
    final load = ++_load;
    emit(
      MiniAppState(
        phase: MiniAppPhase.unavailable,
        load: load,
        reason: reason,
      ),
    );
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
  Future<void> close() {
    _timeout?.cancel();
    // Not awaited before closing: from this call on the mini app is closed,
    // with no moment in between where it could still be started.
    unawaited(_faultChanges.cancel());
    return super.close();
  }
}

/// What the surface of one load reports, passed on only while that load is
/// the current one.
final class _LoadEvents implements MiniAppEvents {
  const _LoadEvents(this._cubit, this._load);

  final MiniAppCubit _cubit;
  final int _load;

  bool get _isCurrent => _cubit._load == _load;

  @override
  NavigationVerdict onNavigation(Uri target, {bool isMainFrame = true}) =>
      _isCurrent
      ? _cubit._navigation(target, isMainFrame: isMainFrame)
      : NavigationVerdict.refuse;

  @override
  void onPageFinished() {
    if (_isCurrent) _cubit._pageFinished();
  }

  @override
  void onLoadFailed() {
    if (_isCurrent) _cubit._fail(MiniAppUnavailableReason.loadFailed);
  }

  @override
  void onHttpError(int statusCode) {
    if (_isCurrent) _cubit._httpError(statusCode);
  }

  @override
  void onMessage(String raw, {required Uri? page}) {
    if (_isCurrent) _cubit._message(raw, page);
  }
}
