// Session unlock for masked account balances.

import 'package:flutter/foundation.dart';

import '../data/app_lock_store.dart';

class SensitiveAccessSession extends ChangeNotifier {
  SensitiveAccessSession._();
  static final instance = SensitiveAccessSession._();

  static const defaultTtl = Duration(minutes: 5);

  bool _revealed = false;
  DateTime? _until;

  /// True when balances may be shown (protection off, or unlocked in-session).
  bool get isRevealed {
    if (!AppLockStore.instance.protectAccountBalances) return true;
    if (!AppLockStore.instance.hasPin) return true;
    if (!_revealed) return false;
    final until = _until;
    if (until != null && DateTime.now().isAfter(until)) {
      _revealed = false;
      _until = null;
      return false;
    }
    return true;
  }

  void reveal({Duration ttl = defaultTtl}) {
    _revealed = true;
    _until = DateTime.now().add(ttl);
    notifyListeners();
  }

  void lock() {
    _revealed = false;
    _until = null;
    notifyListeners();
  }

  @visibleForTesting
  void reset() => lock();
}
