import 'dart:async';

import 'package:app_platform/app_platform.dart';
import 'package:design_system/design_system.dart';
import 'package:feature_home/src/connection_notice.dart';
import 'package:feature_home/src/home_composition.dart';
import 'package:feature_home/src/home_composition_cubit.dart';
import 'package:feature_home/src/home_header.dart';
import 'package:feature_home/src/home_host_controller.dart';
import 'package:feature_home/src/home_strings.dart';
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
            HomeHeader(
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

/// Lays out the composition. Everything it decides comes from the
/// [HomeHostController]: which modules are hidden, whether anything can be
/// shown and whether a refresh is running.
class _HomeBody extends StatefulWidget {
  const _HomeBody({required this.registry, required this.destinations});

  final HomeModuleRegistry registry;
  final DestinationResolver destinations;

  @override
  State<_HomeBody> createState() => _HomeBodyState();
}

class _HomeBodyState extends State<_HomeBody> {
  late final HomeHostController _host;
  bool _rebuildScheduled = false;

  @override
  void initState() {
    super.initState();
    _host = HomeHostController(telemetry: context.read<Telemetry>())
      ..addListener(_onHostChanged);
    _follow(context.read<HomeCompositionCubit>().state);
  }

  void _follow(HomeCompositionState state) {
    final composition = state.composition;
    if (composition == null) return;
    _host.show([for (final module in composition.modules) module.id]);
  }

  /// Modules report while they are being built, when this widget cannot be
  /// marked for rebuilding. Whatever changed is taken in after the frame.
  void _onHostChanged() {
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
  void dispose() {
    _host
      ..removeListener(_onHostChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<HomeCompositionCubit, HomeCompositionState>(
      listener: (context, state) => _follow(state),
      builder: (context, state) {
        final composition = state.composition;
        if (composition == null) return const _HomeSkeleton();

        if (composition.modules.isEmpty) return const _NothingPublished();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ConnectionNotice(hasSavedData: _host.hasData),
            Expanded(
              child: Stack(
                children: [
                  // Kept in the tree while hidden: the modules go on
                  // listening, and the home returns the moment one of them
                  // has something to show.
                  Offstage(
                    offstage: _host.nothingToShow || _host.isBlank,
                    child: RefreshIndicator(
                      onRefresh: _host.refreshAll,
                      child: _modules(context, composition),
                    ),
                  ),
                  if (_host.nothingToShow)
                    _NothingToShow(
                      isRetrying: _host.isRefreshing,
                      onRetry: () => unawaited(_host.refreshAll()),
                    )
                  else if (_host.isBlank)
                    const _NothingPublished(),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _modules(BuildContext context, HomeComposition composition) {
    final composedTypes = {
      for (final module in composition.modules) module.type,
    };
    var drawn = 0;

    return ListView(
      // Always scrollable, so a short home can still be pulled down.
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(
        horizontal: context.metrics.screenMargin,
        vertical: context.metrics.moduleGap,
      ),
      children: [
        for (final module in composition.modules) ...[
          // A module that draws nothing takes no space, so it gets no gap
          // either. It stays in the tree to say when it has something.
          if (!_host.isHidden(module.id) && drawn++ > 0)
            SizedBox(height: context.metrics.moduleGap),
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
                  host: _host,
                  composedTypes: composedTypes,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Every module that would draw something is a data module that failed.
class _NothingToShow extends StatelessWidget {
  const _NothingToShow({required this.isRetrying, required this.onRetry});

  final bool isRetrying;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _Centered(
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
            isLoading: isRetrying,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}

/// The configuration publishes no module this customer would see: nothing
/// failed, there is simply nothing to draw.
class _NothingPublished extends StatelessWidget {
  const _NothingPublished();

  @override
  Widget build(BuildContext context) {
    return const _Centered(
      child: EmptyState(
        icon: Icons.home_outlined,
        title: HomeStrings.emptyTitle,
        message: HomeStrings.emptyMessage,
      ),
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
/// configuration to compose it from. It cannot know which modules will
/// come, so it stands for none in particular.
class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  static const int _blocks = 3;
  static const double _blockHeight = 96;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(
        horizontal: context.metrics.screenMargin,
        vertical: context.metrics.moduleGap,
      ),
      children: [
        for (var block = 0; block < _blocks; block++) ...[
          if (block > 0) SizedBox(height: context.metrics.moduleGap),
          const SkeletonBlock(height: _blockHeight),
        ],
      ],
    );
  }
}
