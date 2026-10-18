// App-wide toast + confirm (web Toast / NoticeCard parity).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/app_colors.dart';

enum AppToastTone { success, warning, error, info }

class AppToast {
  AppToast._();

  static OverlayEntry? _entry;
  static final GlobalKey<_ToastHostState> _hostKey =
      GlobalKey<_ToastHostState>();
  static Timer? _timer;
  static Completer<bool>? _confirmCompleter;

  static const _titles = <AppToastTone, String>{
    AppToastTone.success: 'Saved',
    AppToastTone.error: 'Failed',
    AppToastTone.warning: 'Please review',
    AppToastTone.info: 'Updated',
  };

  static const inOut = Duration(milliseconds: 260);

  static void show(
    BuildContext context,
    String message, {
    AppToastTone tone = AppToastTone.info,
    String? title,
    Duration duration = const Duration(milliseconds: 2200),
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    _haptic(tone);
    _resolveConfirm(false);
    _removeNow();

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
          child: _ToastHost(
            key: _hostKey,
            tone: tone,
            title: heading,
            message: body.isEmpty || body == heading ? null : body,
            onClose: dismiss,
            confirmLabel: 'OK',
            onConfirm: dismiss,
          ),
        );
      },
    );

    overlay.insert(_entry!);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _hostKey.currentState?.playIn();
    });

    if (duration > Duration.zero) {
      _timer = Timer(duration, dismiss);
    }
  }

  /// Toast-style confirm (no AlertDialog). True = confirmed.
  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    String? message,
    String confirmLabel = 'Delete',
    String cancelLabel = 'Cancel',
    AppToastTone tone = AppToastTone.error,
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return Future.value(false);

    _haptic(tone);
    _resolveConfirm(false);
    _removeNow();

    final completer = Completer<bool>();
    _confirmCompleter = completer;

    void finish(bool value) {
      if (completer.isCompleted) return;
      completer.complete(value);
      if (identical(_confirmCompleter, completer)) {
        _confirmCompleter = null;
      }
      dismiss();
    }

    _entry = OverlayEntry(
      builder: (ctx) {
        final top = MediaQuery.paddingOf(ctx).top + 12;
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => finish(false),
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.55),
                ),
              ),
            ),
            Positioned(
              top: top,
              left: 16,
              right: 16,
              child: _ToastHost(
                key: _hostKey,
                tone: tone,
                title: title,
                message: message,
                onClose: () => finish(false),
                cancelLabel: cancelLabel,
                confirmLabel: confirmLabel,
                onCancel: () => finish(false),
                onConfirm: () => finish(true),
              ),
            ),
          ],
        );
      },
    );

    overlay.insert(_entry!);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _hostKey.currentState?.playIn();
    });

    return completer.future;
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

    final host = _hostKey.currentState;
    if (host == null) {
      _removeNow();
      return;
    }

    // Always clear entry even if playOut throws / never completes.
    host.playOut().whenComplete(_removeNow).catchError((_) {
      _removeNow();
    });
  }

  static void _haptic(AppToastTone tone) {
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
  }

  static void _resolveConfirm(bool value) {
    final c = _confirmCompleter;
    if (c == null || c.isCompleted) return;
    c.complete(value);
    _confirmCompleter = null;
  }

  static void _removeNow() {
    _timer?.cancel();
    _timer = null;
    // Never leave a hung confirm future if the overlay is torn down.
    _resolveConfirm(false);
    final entry = _entry;
    _entry = null;
    entry?.remove();
  }
}

class _ToastHost extends StatefulWidget {
  const _ToastHost({
    super.key,
    required this.tone,
    required this.title,
    required this.message,
    required this.onClose,
    this.cancelLabel,
    this.confirmLabel,
    this.onCancel,
    this.onConfirm,
  });

  final AppToastTone tone;
  final String title;
  final String? message;
  final VoidCallback onClose;
  final String? cancelLabel;
  final String? confirmLabel;
  final VoidCallback? onCancel;
  final VoidCallback? onConfirm;

  @override
  State<_ToastHost> createState() => _ToastHostState();
}

class _ToastHostState extends State<_ToastHost>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: AppToast.inOut,
  );

  late final Animation<double> _fade = CurvedAnimation(
    parent: _motion,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );

  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, -0.28),
    end: Offset.zero,
  ).animate(
    CurvedAnimation(
      parent: _motion,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    ),
  );

  late final Animation<double> _scale = Tween<double>(
    begin: 0.96,
    end: 1,
  ).animate(
    CurvedAnimation(
      parent: _motion,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInCubic,
    ),
  );

  void playIn() {
    if (!mounted) return;
    _motion.forward(from: 0);
  }

  Future<void> playOut() async {
    if (!mounted) return;
    if (_motion.value == 0) return;
    await _motion.reverse();
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slide,
      child: FadeTransition(
        opacity: _fade,
        child: ScaleTransition(
          scale: _scale,
          alignment: Alignment.topCenter,
          child: _ToastBanner(
            tone: widget.tone,
            title: widget.title,
            message: widget.message,
            onClose: widget.onClose,
            cancelLabel: widget.cancelLabel,
            confirmLabel: widget.confirmLabel,
            onCancel: widget.onCancel,
            onConfirm: widget.onConfirm,
          ),
        ),
      ),
    );
  }
}

class _ToastBanner extends StatelessWidget {
  const _ToastBanner({
    required this.tone,
    required this.title,
    required this.message,
    required this.onClose,
    this.cancelLabel,
    this.confirmLabel,
    this.onCancel,
    this.onConfirm,
  });

  final AppToastTone tone;
  final String title;
  final String? message;
  final VoidCallback onClose;
  final String? cancelLabel;
  final String? confirmLabel;
  final VoidCallback? onCancel;
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final accent = _toneColor(tone);
    final icon = switch (tone) {
      AppToastTone.success => Icons.check_circle_rounded,
      AppToastTone.info => Icons.help_rounded,
      AppToastTone.warning || AppToastTone.error => Icons.warning_rounded,
    };
    final hasActions = onConfirm != null || onCancel != null;

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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
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
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
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
                                maxLines: 4,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  height: 1.3,
                                  color: colors.textSecondary,
                                ),
                              ),
                            ],
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
                  if (hasActions) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (onCancel != null) ...[
                          Expanded(
                            child: TextButton(
                              onPressed: onCancel,
                              style: TextButton.styleFrom(
                                backgroundColor: colors.surfaceHover,
                                foregroundColor: colors.textPrimary,
                                minimumSize: const Size(0, 36),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: Text(
                                cancelLabel ?? 'Cancel',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (onConfirm != null)
                          Expanded(
                            child: TextButton(
                              onPressed: onConfirm,
                              style: TextButton.styleFrom(
                                backgroundColor: accent,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(0, 36),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: Text(
                                confirmLabel ?? 'OK',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                      ],
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

  Color _toneColor(AppToastTone tone) {
    return switch (tone) {
      AppToastTone.success => const Color(0xFF34C759),
      AppToastTone.error => const Color(0xFFFF3B30),
      AppToastTone.warning => const Color(0xFFFF9500),
      AppToastTone.info => const Color(0xFF007AFF),
    };
  }
}
