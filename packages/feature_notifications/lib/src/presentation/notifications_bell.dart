import 'package:design_system/design_system.dart';
import 'package:feature_notifications/src/presentation/inbox_cubit.dart';
import 'package:feature_notifications/src/presentation/notifications_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The bell that opens the inbox, with a dot while something is unread.
///
/// The dot is never the only signal: a screen reader hears how many
/// notifications are unread.
class NotificationsBell extends StatelessWidget {
  const NotificationsBell({required this.onOpen, super.key});

  final VoidCallback onOpen;

  static const double _dot = 10;

  /// How far the dot sits from the top right corner of the touch target, so
  /// it lands on the bell itself.
  static const double _dotInset = 10;

  @override
  Widget build(BuildContext context) {
    final unread = context.select<InboxCubit, int>(
      (cubit) => cubit.state.unreadCount,
    );
    final colors = context.colors;

    return Semantics(
      button: true,
      label: unread > 0
          ? NotificationsStrings.bellWithUnread(unread)
          : NotificationsStrings.bell,
      onTap: onOpen,
      child: ExcludeSemantics(
        child: InkResponse(
          onTap: onOpen,
          radius: AppSizes.touchTarget / 2,
          child: SizedBox.square(
            dimension: AppSizes.touchTarget,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.notifications_none,
                  size: AppSizes.icon,
                  color: colors.icon,
                ),
                if (unread > 0)
                  Positioned(
                    top: _dotInset,
                    right: _dotInset,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: colors.brandFill,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(context).colorScheme.surface,
                          width: AppSizes.focusWidth,
                        ),
                      ),
                      child: const SizedBox.square(dimension: _dot),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
