import 'dart:async';

import 'package:app_platform/app_platform.dart';
import 'package:design_system/design_system.dart';
import 'package:feature_home/src/home_composition.dart';
import 'package:feature_home/src/home_composition_cubit.dart';
import 'package:feature_home/src/home_strings.dart';
import 'package:feature_home/src/home_telemetry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:module_kit/module_kit.dart';

/// The home of the signed-in customer.
///
/// It draws nothing of its own besides the greeting: what appears, and in
/// what order, is the composition made from the published configuration,
/// and each module is drawn by the package that registered it. It reads
/// `RemoteConfigCubit`, `ConnectivityCubit` and `Telemetry` from the tree.
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    required this.registry,
    required this.destinations,
    required this.productName,
    required this.firstName,
    required this.fullName,
    super.key,
  });

  final HomeModuleRegistry registry;
  final DestinationResolver destinations;
  final String productName;

  /// How the customer is greeted.
  final String firstName;

  /// Where the avatar's initials come from.
  final String fullName;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => HomeCompositionCubit(
        config: context.read<RemoteConfigCubit>(),
        registry: registry,
        telemetry: context.read<Telemetry>(),
      ),
      child: Scaffold(
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _HomeHeader(
              productName: productName,
              greeting: HomeStrings.greeting(firstName),
              initials: initialsOf(fullName),
            ),
            Expanded(
              child: _HomeBody(registry: registry, destinations: destinations),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.productName,
    required this.greeting,
    required this.initials,
  });

  final String productName;
  final String greeting;
  final String initials;

  static const double _avatar = 40;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.surface,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.metrics.screenMargin,
            vertical: AppSpacing.x3,
          ),
          child: Row(
            children: [
              if (initials.isNotEmpty) ...[
                ExcludeSemantics(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.surfaceInset,
                      shape: BoxShape.circle,
                    ),
                    child: SizedBox.square(
                      dimension: _avatar,
                      child: Center(
                        child: Text(
                          initials,
                          style: AppTypography.captionStrong.copyWith(
                            color: scheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.x3),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      productName,
                      style: AppTypography.caption.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                    Semantics(
                      header: true,
                      child: Text(
                        greeting,
                        style: AppTypography.subtitle.copyWith(
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeBody extends StatefulWidget {
  const _HomeBody({required this.registry, required this.destinations});

  final HomeModuleRegistry registry;
  final DestinationResolver destinations;

  @override
  State<_HomeBody> createState() => _HomeBodyState();
}

class _HomeBodyState extends State<_HomeBody> implements HomeModuleHost {
  /// What each module with data of its own last reported.
  final Map<String, HomeModuleStatus> _statuses = {};
  final List<Future<void> Function()> _refreshers = [];

  bool _rebuildScheduled = false;
  bool _isRefreshing = false;
  bool _reportedNothingToShow = false;

  @override
  void report(String moduleId, HomeModuleStatus status) {
    if (_statuses[moduleId] == status) return;
    _statuses[moduleId] = status;

    // Modules report while they are being built, when this widget cannot be
    // marked for rebuilding. The new status is taken in after the frame.
    if (_rebuildScheduled) return;
    _rebuildScheduled = true;
    WidgetsBinding.instance
      ..addPostFrameCallback((_) {
        _rebuildScheduled = false;
        if (mounted) setState(() {});
      })
      ..ensureVisualUpdate();
  }

  @override
  VoidCallback addRefresher(Future<void> Function() refresh) {
    _refreshers.add(refresh);
    return () => _refreshers.remove(refresh);
  }

  Future<void> _refreshAll() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);

    context.read<Telemetry>().event(
      HomeTelemetry.refreshRequested,
      parameters: {HomeTelemetry.modulesKey: _refreshers.length},
    );
    // Each module reports its own outcome; one that throws must not keep
    // the others, or the indicator, waiting.
    await Future.wait([
      for (final refresh in [..._refreshers])
        refresh().catchError((Object _) {}),
    ]);

    if (mounted) setState(() => _isRefreshing = false);
  }

  /// Whether every module with data of its own has failed with nothing to
  /// show. Modules that carry no data never report, so a home made only of
  /// them is never in this state.
  bool _nothingToShow(HomeComposition composition) {
    final reported = [
      for (final module in composition.modules) ?_statuses[module.id],
    ];
    return reported.isNotEmpty &&
        reported.every((status) => status == HomeModuleStatus.failed);
  }

  bool _hasSomethingSaved(HomeComposition composition) => composition.modules
      .any((module) => _statuses[module.id] == HomeModuleStatus.ready);

  void _reportNothingToShow(bool nothingToShow) {
    if (nothingToShow && !_reportedNothingToShow) {
      context.read<Telemetry>().event(HomeTelemetry.nothingToShow);
    }
    _reportedNothingToShow = nothingToShow;
  }

  @override
  Widget build(BuildContext context) {
    final composition = context.watch<HomeCompositionCubit>().state.composition;
    if (composition == null) return const _HomeSkeleton();

    // A module that left the composition no longer counts.
    final current = {for (final module in composition.modules) module.id};
    _statuses.removeWhere((id, _) => !current.contains(id));

    if (composition.modules.isEmpty) {
      return const _Centered(
        child: EmptyState(
          icon: Icons.home_outlined,
          title: HomeStrings.emptyTitle,
          message: HomeStrings.emptyMessage,
        ),
      );
    }

    final nothingToShow = _nothingToShow(composition);
    _reportNothingToShow(nothingToShow);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ConnectionBanner(hasSavedData: _hasSomethingSaved(composition)),
        Expanded(
          child: Stack(
            children: [
              // Kept in the tree while hidden: the modules go on listening,
              // and the home returns the moment one of them has data.
              Offstage(
                offstage: nothingToShow,
                child: RefreshIndicator(
                  onRefresh: _refreshAll,
                  child: _modules(context, composition),
                ),
              ),
              if (nothingToShow)
                _Centered(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const EmptyState(
                        icon: Icons.cloud_off,
                        title: HomeStrings.nothingToShowTitle,
                        message: HomeStrings.nothingToShowMessage,
                      ),
                      const SizedBox(height: AppSpacing.x6),
                      AppButton(
                        label: HomeStrings.retry,
                        isLoading: _isRefreshing,
                        onPressed: () => unawaited(_refreshAll()),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _modules(BuildContext context, HomeComposition composition) {
    return ListView(
      // Always scrollable, so a short home can still be pulled down.
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(
        horizontal: context.metrics.screenMargin,
        vertical: context.metrics.moduleGap,
      ),
      children: [
        for (final (index, module) in composition.modules.indexed) ...[
          if (index > 0) SizedBox(height: context.metrics.moduleGap),
          // Keyed by its id: a module that keeps its place in a newly
          // published configuration keeps its state too.
          KeyedSubtree(
            key: ValueKey(module.id),
            child: Builder(
              builder: (context) => widget.registry.builderFor(module.type)!(
                context,
                HomeModuleContext(
                  id: module.id,
                  type: module.type,
                  props: module.props,
                  destinations: widget.destinations,
                  host: this,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Centers [child] and lets it scroll when it does not fit.
class _Centered extends StatelessWidget {
  const _Centered({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(context.metrics.screenMargin),
        child: child,
      ),
    );
  }
}

/// Shown for the instant between opening the home and having a
/// configuration to compose it from.
class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  static const List<double> _blocks = [64, 146, 96];

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(
        horizontal: context.metrics.screenMargin,
        vertical: context.metrics.moduleGap,
      ),
      children: [
        for (final (index, height) in _blocks.indexed) ...[
          if (index > 0) SizedBox(height: context.metrics.moduleGap),
          SkeletonBlock(height: height),
        ],
      ],
    );
  }
}
