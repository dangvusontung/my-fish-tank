import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'pond.dart';

class PondController extends ChangeNotifier {
  PondController._(this.pond, this._preferences, this._applied);

  static const _key = 'pond-v1';

  final Pond pond;
  final SharedPreferencesAsync _preferences;
  DateTime _applied;
  Timer? _timer;
  Future<void> _writes = Future.value();
  int _ticks = 0;
  bool saveFailed = false;
  bool _disposed = false;

  PondReport? report;
  String reportTitle = '';

  static Future<PondController> load() async {
    final preferences = SharedPreferencesAsync();
    var pond = Pond.starter();
    var lastUpdate = DateTime.now();
    try {
      final raw = await preferences.getString(_key);
      if (raw != null) {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        final restored = Pond.fromJson(json['pond'] as Map<String, dynamic>);
        final restoredAt = DateTime.fromMillisecondsSinceEpoch(
          json['savedAt'] as int,
        );
        pond = restored;
        lastUpdate = restoredAt;
      }
    } catch (error) {
      debugPrint('Could not load pond: $error');
    }
    return PondController._(pond, preferences, lastUpdate)..resume();
  }

  void resume() {
    if (_timer != null || _disposed) return;
    final gap = DateTime.now().difference(_applied);
    final changes = _advance();
    if (gap >= const Duration(minutes: 1) && changes.hasEvents) {
      reportTitle = 'Hồ khi bạn đi vắng';
      report = changes;
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _advance();
      if (++_ticks % 5 == 0) unawaited(_persist());
      notifyListeners();
    });
    unawaited(_persist());
    notifyListeners();
  }

  void pause() {
    if (_timer == null) return;
    _timer?.cancel();
    _timer = null;
    _advance();
    unawaited(_persist());
  }

  PondReport _advance() {
    final now = DateTime.now();
    final elapsed = now.difference(_applied);
    _applied = now;
    return pond.advance(elapsed);
  }

  Future<void> _persist() {
    final snapshot = jsonEncode({
      'savedAt': _applied.millisecondsSinceEpoch,
      'pond': pond.toJson(),
    });
    return _writes = _writes.then((_) async {
      try {
        await _preferences.setString(_key, snapshot);
        if (saveFailed) {
          saveFailed = false;
          if (!_disposed) notifyListeners();
        }
      } catch (error) {
        debugPrint('Could not save pond: $error');
        if (!saveFailed) {
          saveFailed = true;
          if (!_disposed) notifyListeners();
        }
      }
    });
  }

  T act<T>(T Function(Pond pond) action) {
    _advance();
    final result = action(pond);
    unawaited(_persist());
    notifyListeners();
    return result;
  }

  void testThirtyDays() {
    _advance();
    reportTitle = '30 ngày trong hồ';
    report = pond.advance(const Duration(seconds: 30 * Pond.daySeconds));
    unawaited(_persist());
    notifyListeners();
  }

  void dismissReport() {
    report = null;
    notifyListeners();
  }

  @override
  void dispose() {
    if (_timer != null) pause();
    _disposed = true;
    super.dispose();
  }
}
