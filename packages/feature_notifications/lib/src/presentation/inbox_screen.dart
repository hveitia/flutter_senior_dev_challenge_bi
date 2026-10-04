import 'dart:async';

import 'package:app_platform/app_platform.dart';
import 'package:design_system/design_system.dart';
import 'package:feature_notifications/src/domain/inbox_item.dart';
import 'package:feature_notifications/src/notifications_telemetry.dart';
import 'package:feature_notifications/src/presentation/inbox_cubit.dart';
import 'package:feature_notifications/src/presentation/inbox_time.dart';
import 'package:feature_notifications/src/presentation/notifications_strings.dart';
import 'package:feature_notifications/src/presentation/permission_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:module_kit/module_kit.dart';

/// The customer's notifications, newest first, split into today and before.
///
/// It reads the `InboxCubit`, `PermissionCubit` and `ConnectivityCubit` the
/// app provides for the signed-in customer.
class InboxScreen extends StatelessWidget {
  const InboxScreen({
    required this.destinations,
    required this.onInvite,
    this.now = DateTime.now,
    super.key,
  });

  /// Where a notification's destination leads in this build.
  final DestinationResolver destinations;

  /// Opens the invitation to turn notifications on.
  final VoidCallback onInvite;
  final DateTime Function() now;

  /// How many placeholder rows stand in for the inbox while it loads.
  static const int _placeholderRows = 4;
  static const double _placeholderRowHeight = 72;

  @override
  Widget build(BuildContext context) {
    final inbox = context.watch<InboxCubit>().state;
    final margin = context.metrics.screenMargin;

    return Scaffold(
      appBar: AppBar(
        title: const Text(NotificationsStrings.inboxTitle),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConnectionBanner(
            kind: switch (context.watch<ConnectivityCubit>().state) {
              ConnectivityStatus.online => null,
              ConnectivityStatus.offline => StatusBannerKind.offline,
              ConnectivityStatus.slow => StatusBannerKind.slow,
              ConnectivityStatus.restored => StatusBannerKind.restored,
            },
            hasSavedData: inbox.hasItems,
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: context.read<InboxCubit>().refresh,
              child: ListView(
                padding: EdgeInsets.fromLTRB(margin, margin, margin, margin),
                children: [
                  _PermissionNotice(onInvite: onInvite),
                  if (inbox.needsOutdatedNotice) ...[
                    const InlineAlert(
                      message: NotificationsStrings.outdated,
                      tone: AppTone.warning,
                      icon: Icons.sync_problem,
                    ),
                    const SizedBox(height: AppSpacing.x4),
                  ],
                  ..._content(context, inbox),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _content(BuildContext context, InboxState inbox) {
    final items = inbox.items;
    if (items == null) {
      if (inbox.hasFailed) {
        return [
          InlineError(
            message: NotificationsStrings.loadFailed,
            isRetrying: inbox.isLoading,
            onRetry: () => unawaited(context.read<InboxCubit>().retry()),
          ),
        ];
      }
      return [
        for (var index = 0; index < _placeholderRows; index++) ...[
          const SkeletonBlock(height: _placeholderRowHeight),
          const SizedBox(height: AppSpacing.x3),
        ],
      ];
    }
    if (items.isEmpty) {
      return const [
        EmptyState(
          icon: Icons.notifications_none,
          title: NotificationsStrings.emptyTitle,
          message: NotificationsStrings.emptyMessage,
        ),
      ];
    }

    final current = now();
    final groups = groupInbox(items, now: current);
    return [
      if (groups.today.isNotEmpty) ...[
        const GroupHeader(label: NotificationsStrings.today),
        for (final item in groups.today) _row(context, item, current),
      ],
      if (groups.earlier.isNotEmpty) ...[
        const GroupHeader(label: NotificationsStrings.earlier),
        for (final item in groups.earlier) _row(context, item, current),
      ],
    ];
  }

  Widget _row(BuildContext context, InboxItem item, DateTime current) {
    final open = destinations.resolve(item.destination);
    return InboxRow(
      key: ValueKey(item.id),
      item: item,
      arrival: arrivalLabel(item.createdAt, now: current),
      destinationLabel: open == null
          ? null
          : NotificationsStrings.destinationLabel(item.destination),
      onTap: () {
        unawaited(context.read<InboxCubit>().markRead(item));
        context.read<Telemetry>().event(
          NotificationsTelemetry.opened,
          parameters: {
            NotificationsTelemetry.kindKey: item.kind.name,
            NotificationsTelemetry.sourceKey: NotificationsTelemetry.fromInbox,
          },
        );
        open?.call(context);
      },
    );
  }
}

/// Says why no notification reaches this device and offers the way to
/// change it. It draws nothing when notifications are on.
class _PermissionNotice extends StatelessWidget {
  const _PermissionNotice({required this.onInvite});

  final VoidCallback onInvite;

  @override
  Widget build(BuildContext context) {
    final permission = context.watch<PermissionCubit>().state;
    final (title, action, onAction) = switch (permission) {
      PermissionState(isDenied: true) => (
        NotificationsStrings.disabledTitle,
        NotificationsStrings.openSettings,
        () => unawaited(context.read<PermissionCubit>().openSystemSettings()),
      ),
      PermissionState(canInvite: true) => (
        NotificationsStrings.notEnabledTitle,
        NotificationsStrings.enable,
        onInvite,
      ),
      _ => (null, null, null),
    };
    if (title == null || action == null || onAction == null) {
      return const SizedBox.shrink();
    }

    final colors = context.colors;
    final foreground = colors.foreground(AppTone.warning);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.x4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.tint(AppTone.warning),
          borderRadius: BorderRadius.circular(context.metrics.cardRadius),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.x4,
            AppSpacing.x3,
            AppSpacing.x4,
            AppSpacing.x1,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ExcludeSemantics(
                    child: Icon(
                      Icons.notifications_off_outlined,
                      size: AppSizes.iconMedium,
                      color: foreground,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.x2),
                  Expanded(
                    child: Text(
                      title,
                      style: AppTypography.body.copyWith(color: foreground),
                    ),
                  ),
                ],
              ),
              AppButton(
                label: action,
                variant: AppButtonVariant.text,
                expand: false,
                onPressed: onAction,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One notification of the inbox.
class InboxRow extends StatelessWidget {
  const InboxRow({
    required this.item,
    required this.arrival,
    required this.onTap,
    this.destinationLabel,
    super.key,
  });

  final InboxItem item;

  /// When it arrived, already written for the customer.
  final String arrival;

  /// Where it leads, or null when it leads nowhere in this build.
  final String? destinationLabel;
  final VoidCallback onTap;

  static const double _unreadDot = 8;

  static IconData _icon(NotificationKind kind) => switch (kind) {
    NotificationKind.movement => Icons.swap_horiz,
    NotificationKind.security => Icons.verified_user_outlined,
    NotificationKind.benefit => Icons.card_giftcard,
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final scheme = Theme.of(context).colorScheme;
    final titleStyle = item.isRead
        ? AppTypography.body
        : AppTypography.bodyStrong;

    return Semantics(
      button: true,
      label: [
        if (!item.isRead) NotificationsStrings.unread,
        item.title,
        item.body,
        arrival,
        ?destinationLabel,
      ].join('. '),
      onTap: onTap,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: colors.line),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.x3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    _icon(item.kind),
                    size: AppSizes.icon,
                    color: colors.icon,
                  ),
                  const SizedBox(width: AppSpacing.x3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: titleStyle.copyWith(color: scheme.onSurface),
                        ),
                        const SizedBox(height: AppSpacing.x1),
                        Text(
                          item.body,
                          style: AppTypography.body.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.x2),
                        Text(
                          arrival,
                          style: AppTypography.caption.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                        if (destinationLabel case final label?) ...[
                          const SizedBox(height: AppSpacing.x1),
                          Text(
                            label,
                            style: AppTypography.caption.copyWith(
                              color: colors.link,
                            ),
                          ),
                        ],
                        if (!item.isRead) ...[
                          const SizedBox(height: AppSpacing.x1),
                          Row(
                            children: [
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  color: colors.brandFill,
                                  shape: BoxShape.circle,
                                ),
                                child: const SizedBox.square(
                                  dimension: _unreadDot,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.x2),
                              Text(
                                NotificationsStrings.unread,
                                style: AppTypography.captionStrong.copyWith(
                                  color: scheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (destinationLabel != null) ...[
                    const SizedBox(width: AppSpacing.x2),
                    Icon(
                      Icons.chevron_right,
                      size: AppSizes.icon,
                      color: colors.icon,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
