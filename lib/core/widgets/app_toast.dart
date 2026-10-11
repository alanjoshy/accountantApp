// App-wide toast (web Toast / NoticeCard parity).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/app_colors.dart';

enum AppToastTone { success, warning, error, info }

class AppToast {
  AppToast._();

  static OverlayEntry? _entry;
  static Timer? _timer;

  static const _titles = <AppToastTone, String>{
    AppToastTone.success: 'Saved',
    AppToastTone.error: 'Failed',
    AppToastTone.warning: 'Please review',
    AppToastTone.info: 'Updated',
  };

  static void show(
    BuildContext context,
    String message, {
    AppToastTone tone = AppToastTone.info,
    String? title,
    Duration duration = const Duration(milliseconds: 2200),
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    switch (tone) {
      case AppToastTone.error:
        HapticFeedback.heavyImpact();
      case AppToastTone.warning:
        HapticFeedback.mediumImpact();
      case AppToastTone.success:
        HapticFeedback.lightImpact();
      case AppToastTone.info:
        HapticFeedback.selectionClick();
    }

    dismiss();

    final heading = (title?.trim().isNotEmpty ?? false)
        ? title!.trim()
        : _titles[tone]!;
    final body = message.trim();

    _entry = OverlayEntry(
      builder: (ctx) {
        final top = MediaQuery.paddingOf(ctx).top + 12;
        return Positioned(
          top: top,
          left: 16,
          right: 16,
          child: _ToastBanner(
            tone: tone,
            title: heading,
            message: body.isEmpty || body == heading ? null : body,
            onClose: dismiss,
          ),
        );
      },
    );

    overlay.insert(_entry!);
    if (duration > Duration.zero) {
      _timer = Timer(duration, dismiss);
    }
  }

  static void success(BuildContext context, String message) =>
      show(context, message, tone: AppToastTone.success);

  static void warning(BuildContext context, String message) =>
      show(context, message, tone: AppToastTone.warning);

  static void error(BuildContext context, String message) =>
      show(context, message, tone: AppToastTone.error);

  static void dismiss() {
    _timer?.cancel();
    _timer = null;
    _entry?.remove();
    _entry = null;
  }
}

class _ToastBanner extends StatelessWidget {
  const _ToastBanner({
    required this.tone,
    required this.title,
    required this.message,
    required this.onClose,
  });

  final AppToastTone tone;
  final String title;
  final String? message;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final accent = _toneColor(tone);
    final icon = switch (tone) {
      AppToastTone.success => Icons.check_circle_rounded,
      AppToastTone.info => Icons.help_rounded,
      AppToastTone.warning || AppToastTone.error => Icons.warning_rounded,
    };

    return Material(
      color: Colors.transparent,
      child: Align(
        alignment: Alignment.topCenter,
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surfaceElevated,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.14),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 18, color: accent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            height: 1.25,
                            color: colors.textPrimary,
                          ),
                        ),
                        if (message != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            message!,
                            style: TextStyle(
                              fontSize: 12.5,
                              height: 1.3,
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: onClose,
                            style: TextButton.styleFrom(
                              backgroundColor: accent,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(0, 32),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 6,
                              ),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              'OK',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: onClose,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    icon: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: colors.textMuted,
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

  Color _toneColor(AppToastTone tone) {
    return switch (tone) {
      AppToastTone.success => const Color(0xFF34C759),
      AppToastTone.error => const Color(0xFFFF3B30),
      AppToastTone.warning => const Color(0xFFFF9500),
      AppToastTone.info => const Color(0xFF007AFF),
    };
  }
}
