import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ad-free time earned by watching a rewarded ad (one hour per ad).
///
/// Tamper-resistant by design: the pass is a *budget of play time*, not a
/// wall-clock expiry. It only counts down while the app is in the foreground,
/// timed with a monotonic [Stopwatch], so changing the device clock or time
/// zone can't extend it. The remaining budget is persisted every few seconds
/// and whenever the app is backgrounded, so killing the app can save at most a
/// few seconds. Earned time is capped so it can't be stockpiled indefinitely.
class AdFreePass extends ChangeNotifier with WidgetsBindingObserver {
  static const Duration reward = Duration(hours: 1);
  static const Duration maxBank = Duration(hours: 3);
  static const String _prefKey = 'ad_free_remaining_ms';
  static const Duration _saveEvery = Duration(seconds: 10);

  final SharedPreferences _prefs;
  final Stopwatch _clock = Stopwatch();
  Timer? _tick;
  Timer? _expiry;
  int _bankMs;

  AdFreePass(this._prefs)
      : _bankMs = (_prefs.getInt(_prefKey) ?? 0).clamp(0, maxBank.inMilliseconds) {
    WidgetsBinding.instance.addObserver(this);
    _resume();
  }

  Duration get remaining =>
      Duration(milliseconds: max(0, _bankMs - _clock.elapsedMilliseconds));
  bool get active => remaining > Duration.zero;

  /// Whether watching another ad would still add time (below the cap).
  bool get canEarnMore => remaining + const Duration(minutes: 5) < maxBank;

  /// Called only from the ad SDK's "user earned reward" callback.
  void grant() {
    _commit();
    _bankMs = min(_bankMs + reward.inMilliseconds, maxBank.inMilliseconds);
    _save();
    _resume();
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _resume();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _pause();
    }
  }

  void _resume() {
    if (_bankMs <= 0) return;
    _clock.start();
    _tick ??= Timer.periodic(_saveEvery, (_) {
      _save();
      notifyListeners(); // refresh the countdown label
    });
    _expiry?.cancel();
    _expiry = Timer(remaining, _onExpired);
  }

  void _pause() {
    _commit();
    _clock.stop();
    _tick?.cancel();
    _tick = null;
    _expiry?.cancel();
    _save();
  }

  void _onExpired() {
    _pause();
    notifyListeners();
  }

  /// Fold elapsed foreground time into the bank and restart the stopwatch.
  void _commit() {
    _bankMs = remaining.inMilliseconds;
    _clock.reset();
  }

  void _save() => _prefs.setInt(_prefKey, remaining.inMilliseconds);

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pause();
    super.dispose();
  }
}
