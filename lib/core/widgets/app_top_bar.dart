// Fixed shell title bar (above scrolling tab bodies).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/app_colors.dart';
import '../../features/reminders/data/notification_inbox_store.dart';
import '../../features/reminders/presentation/widgets/notifications_sheet.dart';
import '../navigation/app_tab.dart';
import 'app_sheet.dart';
import 'app_toast.dart';

class AppTopBar extends StatelessWidget {
  const AppTopBar({super.key, required this.tab});

  final AppTab tab;

  static const height = 56.0;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Material(
      color: colors.background.withValues(alpha: 0.9),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: colors.border.withValues(alpha: 0.9)),
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: height,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Page title — left
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        layoutBuilder: (current, previous) {
                          return Stack(
                            alignment: Alignment.centerLeft,
                            children: [
                              ...previous,
                              ?current,
                            ],
                          );
                        },
                        transitionBuilder: (child, animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: child,
                          );
                        },
                        child: FittedBox(
                          key: ValueKey(tab),
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'PERSONAL FINANCE',
                                maxLines: 1,
                                textAlign: TextAlign.left,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.4,
                                  color: colors.accent,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                tab.label,
                                maxLines: 1,
                                textAlign: TextAlign.left,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.3,
                                  height: 1.1,
                                  color: colors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Bell + profile — right (web Header order)
                  const SizedBox(width: 12),
                  MediaQuery.withNoTextScaling(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListenableBuilder(
                          listenable: NotificationInboxStore.instance,
                          builder: (context, _) {
                            final unread =
                                NotificationInboxStore.instance.unreadCount;
                            return Stack(
                              clipBehavior: Clip.none,
                              children: [
                                _IconBtn(
                                  tooltip: 'Notifications',
                                  colors: colors,
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    showNotificationsSheet(context);
                                  },
                                  child: Icon(
                                    unread > 0
                                        ? Icons.notifications_rounded
                                        : Icons.notifications_none_rounded,
                                    size: 18,
                                    color: colors.textSecondary,
                                  ),
                                ),
                                if (unread > 0)
                                  Positioned(
                                    right: 2,
                                    top: 2,
                                    child: Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: colors.error,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(width: 8),
                        _IconBtn(
                          tooltip: 'Profile',
                          colors: colors,
                          accent: true,
                          onTap: () {
                            HapticFeedback.lightImpact();
                            _openProfileSheet(context);
                          },
                          child: const Icon(
                            Icons.person_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openProfileSheet(BuildContext context) {
    final colors = AppColors.of(context);
    showAppSheet<void>(
      context: context,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 12,
            bottom: MediaQuery.paddingOf(ctx).bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.border,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Profile',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: colors.accent,
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.border),
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    size: 34,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Profile stays on this device. App preferences are in More → Settings.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: colors.textMuted,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  AppToast.show(
                    context,
                    'Profile editing coming soon.',
                    tone: AppToastTone.info,
                    title: 'Profile',
                  );
                },
                style: FilledButton.styleFrom(
                  backgroundColor: colors.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Edit profile',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({
    required this.tooltip,
    required this.colors,
    required this.onTap,
    required this.child,
    this.accent = false,
  });

  final String tooltip;
  final AppPalette colors;
  final VoidCallback onTap;
  final Widget child;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: accent ? colors.accent : colors.surfaceElevated,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: accent ? colors.accent : colors.border,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
