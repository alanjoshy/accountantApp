// Shared reminder model for Remember tips + local notifications + inbox.

import 'package:flutter/foundation.dart';

import '../../home/presentation/data/static_remember_tips.dart';

enum ReminderDeepLink {
  none,
  budgets,
  debts,
  scheduled,
  plannedReserves,
  addTransaction,
  settings,
  accounts,
}

class ReminderItem {
  const ReminderItem({
    required this.id,
    required this.title,
    required this.body,
    required this.tone,
    this.deepLink = ReminderDeepLink.none,
    this.hrefLabel,
    this.notifyAt,
    this.notificationId,
  });

  final String id;
  final String title;
  final String body;
  final RememberTone tone;
  final ReminderDeepLink deepLink;
  final String? hrefLabel;

  /// When set, OS local notification should fire at this local time.
  final DateTime? notifyAt;

  /// Stable int id for flutter_local_notifications (null = tip/inbox only).
  final int? notificationId;

  StaticRememberTip toTip({VoidCallback? onOpen}) {
    return StaticRememberTip(
      id: id,
      title: title,
      body: body,
      tone: tone,
      hrefLabel: hrefLabel,
      onOpen: onOpen,
    );
  }
}

int stableNotificationId(String key) {
  // Keep in 32-bit positive range for Android.
  var hash = 0;
  for (final unit in key.codeUnits) {
    hash = 0x1fffffff & (hash + unit);
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    hash ^= hash >> 6;
  }
  hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
  hash ^= hash >> 11;
  hash = 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  return hash == 0 ? 1 : hash;
}
