// In-app notification inbox for the top-bar bell.

import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/storage/local_storage.dart';
import '../domain/reminder_item.dart';
import '../../home/presentation/data/static_remember_tips.dart';

class InboxEntry {
  const InboxEntry({
    required this.id,
    required this.title,
    required this.body,
    required this.tone,
    required this.deepLink,
    required this.createdAt,
    this.read = false,
    this.hrefLabel,
  });

  final String id;
  final String title;
  final String body;
  final RememberTone tone;
  final ReminderDeepLink deepLink;
  final String createdAt;
  final bool read;
  final String? hrefLabel;

  InboxEntry copyWith({bool? read}) {
    return InboxEntry(
      id: id,
      title: title,
      body: body,
      tone: tone,
      deepLink: deepLink,
      createdAt: createdAt,
      read: read ?? this.read,
      hrefLabel: hrefLabel,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'tone': tone.name,
        'deepLink': deepLink.name,
        'createdAt': createdAt,
        'read': read,
        if (hrefLabel != null) 'hrefLabel': hrefLabel,
      };

  factory InboxEntry.fromJson(Map<String, dynamic> json) {
    RememberTone tone = RememberTone.info;
    final toneRaw = json['tone'] as String?;
    for (final t in RememberTone.values) {
      if (t.name == toneRaw) {
        tone = t;
        break;
      }
    }
    ReminderDeepLink link = ReminderDeepLink.none;
    final linkRaw = json['deepLink'] as String?;
    for (final l in ReminderDeepLink.values) {
      if (l.name == linkRaw) {
        link = l;
        break;
      }
    }
    return InboxEntry(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      tone: tone,
      deepLink: link,
      createdAt: json['createdAt']?.toString() ?? '',
      read: json['read'] as bool? ?? false,
      hrefLabel: json['hrefLabel']?.toString(),
    );
  }
}

class NotificationInboxStore extends ChangeNotifier {
  NotificationInboxStore._();
  static final instance = NotificationInboxStore._();

  List<InboxEntry> _items = const [];

  List<InboxEntry> get items => _items;

  int get unreadCount => _items.where((e) => !e.read).length;

  void load() {
    final raw = LocalStorage.getString(AppConstants.notificationInboxKey);
    if (raw == null || raw.isEmpty) {
      _items = const [];
      return;
    }
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      _items = [
        for (final row in list)
          if (row is Map)
            InboxEntry.fromJson(Map<String, dynamic>.from(row)),
      ];
    } catch (_) {
      _items = const [];
    }
  }

  Future<void> _persist() async {
    await LocalStorage.setString(
      AppConstants.notificationInboxKey,
      jsonEncode(_items.map((e) => e.toJson()).toList()),
    );
  }

  /// Upsert active reminders into the inbox (keeps read state for known ids).
  Future<void> syncActive(List<ReminderItem> active) async {
    final now = DateTime.now().toIso8601String();
    final byId = {for (final e in _items) e.id: e};
    final next = <InboxEntry>[];

    for (final r in active) {
      if (r.deepLink == ReminderDeepLink.none &&
          !r.id.startsWith('budget-') &&
          !r.id.startsWith('daily-') &&
          !r.id.startsWith('debt-') &&
          !r.id.startsWith('sched-') &&
          !r.id.startsWith('speed-') &&
          !r.id.startsWith('low-balance-')) {
        continue;
      }
      // Skip pure habit/security noise for inbox — keep actionable.
      if (r.id.startsWith('security-') ||
          r.id == 'habit' ||
          r.id == 'daily-avg' ||
          r.id == 'healthy' ||
          r.id == 'empty') {
        continue;
      }
      final prev = byId[r.id];
      next.add(
        InboxEntry(
          id: r.id,
          title: r.title,
          body: r.body,
          tone: r.tone,
          deepLink: r.deepLink,
          createdAt: prev?.createdAt ?? now,
          read: prev?.read ?? false,
          hrefLabel: r.hrefLabel,
        ),
      );
    }

    // Keep recently read items that dropped off (max 30).
    for (final e in _items) {
      if (next.any((n) => n.id == e.id)) continue;
      if (!e.read) continue;
      next.add(e);
    }
    if (next.length > 30) {
      next.removeRange(30, next.length);
    }

    _items = next;
    notifyListeners();
    await _persist();
  }

  Future<void> markRead(String id) async {
    _items = [
      for (final e in _items)
        if (e.id == id) e.copyWith(read: true) else e,
    ];
    notifyListeners();
    await _persist();
  }

  Future<void> markAllRead() async {
    _items = [for (final e in _items) e.copyWith(read: true)];
    notifyListeners();
    await _persist();
  }
}
