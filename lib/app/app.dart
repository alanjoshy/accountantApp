// Root MaterialApp.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../features/auth/data/app_lock_store.dart';
import '../features/auth/domain/app_session.dart';
import '../features/reminders/data/notification_service.dart';
import '../features/reminders/domain/reminder_item.dart';
import '../features/reminders/domain/reminder_sync.dart';
import '../features/reminders/presentation/widgets/notifications_sheet.dart';
import 'router.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';

class AccountantApp extends StatefulWidget {
  const AccountantApp({super.key});

  @override
  State<AccountantApp> createState() => _AccountantAppState();
}

class _AccountantAppState extends State<AccountantApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    NotificationService.instance.onTap = _onNotificationTap;
  }

  void _onNotificationTap(String? payload) {
    final nav = AppRouter.navigatorKey.currentState;
    if (nav == null || payload == null) return;
    ReminderDeepLink link = ReminderDeepLink.none;
    for (final value in ReminderDeepLink.values) {
      if (value.name == payload) {
        link = value;
        break;
      }
    }
    final ctx = nav.context;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      openReminderDeepLink(ctx, link);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final session = AppSession.instance;
    if (state == AppLifecycleState.paused) {
      session.markPaused();
      return;
    }
    if (state != AppLifecycleState.resumed) return;

    unawaited(() async {
      try {
        await ReminderSync.refresh();
      } catch (e, st) {
        if (kDebugMode) {
          debugPrint('ReminderSync on resume failed: $e\n$st');
        }
      }
    }());

    if (!session.shouldRelock()) return;

    session.lock();
    final nav = AppRouter.navigatorKey.currentState;
    if (nav == null) return;
    nav.pushNamedAndRemoveUntil(AppRouter.lock, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final initial = AppLockStore.instance.shouldShowLock
        ? AppRouter.lock
        : AppRouter.home;

    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        return MaterialApp(
          title: 'Accountant',
          debugShowCheckedModeBanner: false,
          navigatorKey: AppRouter.navigatorKey,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: ThemeController.instance.mode,
          initialRoute: initial,
          onGenerateRoute: AppRouter.onGenerateRoute,
        );
      },
    );
  }
}
