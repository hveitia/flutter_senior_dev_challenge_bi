import 'package:flutter/widgets.dart';
import 'package:module_kit/src/home_module.dart';

/// Keeps the home informed about a module: it reports [status] every time it
/// changes, registers [onRefresh] for as long as the module is on screen and
/// withdraws the report when it leaves.
///
/// A module wraps its content in it instead of talking to the host itself.
class HomeModuleBinding extends StatefulWidget {
  const HomeModuleBinding({
    required this.module,
    required this.status,
    required this.child,
    this.onRefresh,
    super.key,
  });

  /// What a module returns when it has nothing to draw: it takes no space
  /// and tells the home, which closes the gap it would have left.
  const HomeModuleBinding.hidden({required this.module, super.key})
    : status = HomeModuleStatus.hidden,
      onRefresh = null,
      child = const SizedBox.shrink();

  final HomeModuleContext module;
  final HomeModuleStatus status;

  /// Brings the module's data up to date. It completes when the refresh is
  /// over, however it ended.
  final Future<void> Function()? onRefresh;
  final Widget child;

  @override
  State<HomeModuleBinding> createState() => _HomeModuleBindingState();
}

class _HomeModuleBindingState extends State<HomeModuleBinding> {
  VoidCallback? _removeRefresher;

  @override
  void initState() {
    super.initState();
    _report();
    if (widget.onRefresh != null) {
      // Registered once and forwarded, so the home always runs the refresh
      // of the latest build without registering again on every rebuild.
      _removeRefresher = widget.module.host.addRefresher(
        () => widget.onRefresh?.call() ?? Future<void>.value(),
      );
    }
  }

  @override
  void didUpdateWidget(HomeModuleBinding oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.status != oldWidget.status) _report();
  }

  void _report() => widget.module.host.report(widget.module.id, widget.status);

  @override
  void dispose() {
    _removeRefresher?.call();
    widget.module.host.withdraw(widget.module.id);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
