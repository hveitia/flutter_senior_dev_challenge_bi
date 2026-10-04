import 'dart:async';

import 'package:design_system/design_system.dart';
import 'package:feature_services/src/domain/partner_origin.dart';
import 'package:feature_services/src/domain/service_catalog.dart';
import 'package:feature_services/src/ports.dart';
import 'package:feature_services/src/presentation/mini_app/mini_app_cubit.dart';
import 'package:feature_services/src/presentation/mini_app/mini_app_unavailable_view.dart';
import 'package:feature_services/src/presentation/services_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The container of a partner's mini app.
///
/// The bar at the top belongs to the bank's app and is always there: it
/// names the service, says whose it is and closes it. The partner's page is
/// drawn below, inside a frame that looks like nothing else in the app, so
/// the customer can tell at a glance where the bank ends and the partner
/// begins.
///
/// It reads [MiniAppCubit] from the tree.
class MiniAppScreen extends StatelessWidget {
  const MiniAppScreen({
    required this.service,
    required this.externalLinks,
    required this.onClose,
    required this.onBackToServices,
    super.key,
  });

  /// A partner service: it has a mini app.
  final ServiceEntry service;
  final ExternalLinks externalLinks;

  /// Leaves the mini app for wherever the customer came from.
  final VoidCallback onClose;
  final VoidCallback onBackToServices;

  @override
  Widget build(BuildContext context) {
    final partner = service.miniApp!.partnerName;

    return BlocConsumer<MiniAppCubit, MiniAppState>(
      listenWhen: (previous, current) =>
          (current.closeRequested && !previous.closeRequested) ||
          (current.outsideLink != null &&
              current.outsideLink != previous.outsideLink),
      listener: (context, state) {
        if (state.closeRequested) return onClose();
        final link = state.outsideLink;
        if (link != null) unawaited(_offerOutside(context, link, partner));
      },
      builder: (context, state) {
        final cubit = context.read<MiniAppCubit>();

        return Scaffold(
          appBar: _HostBar(
            title: service.title,
            caption: ServicesStrings.serviceOf(partner),
            onClose: onClose,
            onLoadAgain: () => unawaited(cubit.start()),
          ),
          body: state.phase == MiniAppPhase.unavailable
              ? MiniAppUnavailableView(
                  reason: state.reason,
                  onRetry: () => unawaited(cubit.start()),
                  onBackToServices: onBackToServices,
                )
              : _PartnerFrame(
                  caption: ServicesStrings.contentOf(partner),
                  completion: switch (state.completed) {
                    null => null,
                    final completed => switch (completed.reference) {
                      null => ServicesStrings.completed,
                      final reference => ServicesStrings.completedWithReference(
                        reference,
                      ),
                    },
                  },
                  loadingLabel: state.phase == MiniAppPhase.loading
                      ? ServicesStrings.loading(service.title)
                      : null,
                  page: cubit.surface.build(context),
                ),
        );
      },
    );
  }

  /// The page tried to open another site. It never opens inside the
  /// container; the customer decides whether it opens in their browser.
  Future<void> _offerOutside(
    BuildContext context,
    Uri link,
    String partner,
  ) async {
    final cubit = context.read<MiniAppCubit>();
    final messenger = ScaffoldMessenger.of(context);

    final open = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(ServicesStrings.outsideTitle),
        content: Text(
          ServicesStrings.outsideMessage(
            // The host only: the rest of the address is the page's business.
            site: originOf(link) ?? link.host,
            partner: partner,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(ServicesStrings.outsideStay),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(ServicesStrings.outsideOpen),
          ),
        ],
      ),
    );
    cubit.outsideLinkHandled();
    if (open != true) return;

    final opened = await externalLinks.open(link);
    if (!opened) {
      messenger.showSnackBar(
        const SnackBar(content: Text(ServicesStrings.outsideFailed)),
      );
    }
  }
}

/// What the menu of the host bar offers. Only what works today: the design
/// also names the partner's conditions, which have no page to open yet.
enum _HostAction { loadAgain }

/// The part of the container that is the bank's own.
class _HostBar extends StatelessWidget implements PreferredSizeWidget {
  const _HostBar({
    required this.title,
    required this.caption,
    required this.onClose,
    required this.onLoadAgain,
  });

  final String title;
  final String caption;
  final VoidCallback onClose;
  final VoidCallback onLoadAgain;

  @override
  Size get preferredSize => const Size.fromHeight(_height);

  /// Room for the title and its caption at the largest text size.
  static const double _height = 72;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AppBar(
      toolbarHeight: _height,
      automaticallyImplyLeading: false,
      leading: IconButton(
        icon: const Icon(Icons.close),
        tooltip: ServicesStrings.close,
        onPressed: onClose,
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodyStrong.copyWith(color: scheme.onSurface),
          ),
          Text(
            caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.caption.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
        ],
      ),
      actions: [
        PopupMenuButton<_HostAction>(
          tooltip: ServicesStrings.moreOptions,
          onSelected: (_) => onLoadAgain(),
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: _HostAction.loadAgain,
              child: Text(ServicesStrings.loadAgain),
            ),
          ],
        ),
      ],
    );
  }
}

/// The partner's page inside its frame: a caption that says whose content
/// it is, a border and square corners that are the partner's, not the
/// bank's.
class _PartnerFrame extends StatelessWidget {
  const _PartnerFrame({
    required this.caption,
    required this.page,
    this.completion,
    this.loadingLabel,
  });

  final String caption;
  final Widget page;

  /// What to say once the page reported that the customer finished.
  final String? completion;

  /// Set while the page is loading: what a screen reader announces.
  final String? loadingLabel;

  @override
  Widget build(BuildContext context) {
    final margin = context.metrics.screenMargin;
    final completion = this.completion;
    final loadingLabel = this.loadingLabel;
    final radius = BorderRadius.circular(AppRadii.partner);

    return Padding(
      padding: EdgeInsets.fromLTRB(margin, AppSpacing.x3, margin, margin),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            caption,
            style: AppTypography.caption.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.x2),
          if (completion != null) ...[
            InlineAlert(
              message: completion,
              tone: AppTone.success,
              icon: Icons.check_circle_outline,
            ),
            const SizedBox(height: AppSpacing.x2),
          ],
          Expanded(
            child: DecoratedBox(
              position: DecorationPosition.foreground,
              decoration: BoxDecoration(
                border: Border.all(color: context.colors.line),
                borderRadius: radius,
              ),
              child: ClipRRect(
                borderRadius: radius,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    page,
                    if (loadingLabel != null)
                      _LoadingCover(label: loadingLabel),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Covers the page until it has loaded, with the outline of a form.
class _LoadingCover extends StatelessWidget {
  const _LoadingCover({required this.label});

  final String label;

  static const double _titleHeight = 28;
  static const double _fieldHeight = 52;
  static const int _fields = 3;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      liveRegion: true,
      child: ExcludeSemantics(
        child: ColoredBox(
          color: Theme.of(context).colorScheme.surface,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.x4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const FractionallySizedBox(
                  alignment: AlignmentDirectional.centerStart,
                  widthFactor: 0.6,
                  child: SkeletonBlock(height: _titleHeight),
                ),
                for (var field = 0; field < _fields; field++) ...[
                  const SizedBox(height: AppSpacing.x4),
                  const SkeletonBlock(height: _fieldHeight),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
