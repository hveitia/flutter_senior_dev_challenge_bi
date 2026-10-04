import 'package:feature_services/src/domain/navigation.dart';
import 'package:feature_services/src/ports.dart';

/// Turns what a web view reports into the events of the container.
///
/// A web view reports addresses as text, errors of every resource of the
/// page and status codes of every request. This keeps what is about the page
/// itself and decides, for each navigation, whether the web view may follow
/// it. It knows nothing of the plugin, so the decisions can be tested
/// without one.
final class PageEvents {
  PageEvents(this._events);

  final MiniAppEvents _events;

  /// The address the web view shows: the one it was last told to load, or
  /// the one it moved to with the container's permission. Whoever tells the
  /// web view to load an address sets it first.
  Uri? page;

  /// Whether the web view may go to [url]. Text that is not an address is
  /// never followed.
  bool mayNavigate(String url, {required bool isMainFrame}) {
    final target = Uri.tryParse(url);
    if (target == null) return false;

    final stays =
        _events.onNavigation(target, isMainFrame: isMainFrame) ==
        NavigationVerdict.stay;
    if (stays && isMainFrame) page = target;
    return stays;
  }

  void pageFinished() => _events.onPageFinished();

  /// A resource could not be loaded. Only the page itself matters: a missing
  /// image does not make the service unavailable. A web view that does not
  /// say which it was is taken to mean the page.
  void resourceFailed({required bool? isForMainFrame}) {
    if (isForMainFrame ?? true) _events.onLoadFailed();
  }

  /// The server answered the request for [requested] with [statusCode].
  /// Reported only when it is the answer for the page itself.
  void httpError({required int? statusCode, required Uri? requested}) {
    final page = this.page;
    if (statusCode == null || requested == null || page == null) return;
    if (requested.removeFragment() != page.removeFragment()) return;
    _events.onHttpError(statusCode);
  }

  /// The page posted [raw] while the web view was showing [currentUrl].
  void message(String raw, {required String? currentUrl}) => _events.onMessage(
    raw,
    page: currentUrl == null ? null : Uri.tryParse(currentUrl),
  );
}
