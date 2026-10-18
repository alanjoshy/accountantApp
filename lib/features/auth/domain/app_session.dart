// In-memory unlock state for app lock + resume.

import 'package:flutter/foundation.dart';

import '../data/app_lock_store.dart';
import 'sensitive_access_session.dart';

class AppSession extends ChangeNotifier {
  AppSession._();
  static final instance = AppSession._();

  /// Grace after background before re-lock (avoids control-center blips).
  static const resumeGrace = Duration(seconds: 20);

  bool _unlocked = false;
  DateTime? _pausedAt;
  bool _authenticating = false;

  bool get isUnlocked => _unlocked;

  bool get isAuthenticating => _authenticating;

  void setAuthenticating(bool value) {
    _authenticating = value;
  }

  void unlock() {
    _unlocked = true;
    _pausedAt = null;
    notifyListeners();
  }

  void lock() {
    _unlocked = false;
    SensitiveAccessSession.instance.lock();
    notifyListeners();
  }

  void markPaused() {
    if (_authenticating) return;
    _pausedAt = DateTime.now();
  }

  bool shouldRelock({Duration grace = resumeGrace}) {
    final lock = AppLockStore.instance;
    if (!lock.shouldShowLock || !lock.lockOnResume) return false;
    if (_authenticating) return false;
    if (!_unlocked) return true;
    final paused = _pausedAt;
    if (paused == null) return false;
    return DateTime.now().difference(paused) >= grace;
  }

  /// Test / bootstrap helper.
  @visibleForTesting
  void reset() {
    _unlocked = false;
    _pausedAt = null;
    _authenticating = false;
    SensitiveAccessSession.instance.lock();
  }
}
