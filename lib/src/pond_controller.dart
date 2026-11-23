import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'pond.dart';
import 'species_catalog.dart';

typedef CatalogLoader = Future<String> Function();

class PondController extends ChangeNotifier {
  PondController._(
    this.pond,
    this._preferences,
    this._applied,
    this._loadCatalog,
  );

  static const _key = 'pond-v1';
  static const _catalogKey = 'fish-catalog-v1';

  final Pond pond;
  final SharedPreferencesAsync _preferences;
  final CatalogLoader? _loadCatalog;
  DateTime _applied;
  Timer? _timer;
  Future<void> _writes = Future.value();
  int _ticks = 0;
  bool saveFailed = false;
  bool _disposed = false;
  bool _refreshingCatalog = false;

  PondReport? report;
  String reportTitle = '';

  static Future<PondController> load({CatalogLoader? loadCatalog}) async {
    final preferences = SharedPreferencesAsync();
    SpeciesCatalog? catalog;
    try {
      final cached = await preferences.getString(_catalogKey);
      if (cached != null) catalog = SpeciesCatalog.decode(cached);
    } catch (error) {
      debugPrint('Could not read cached fish catalog: $error');
    }
    var pond = Pond.starter(catalog: catalog);
    var lastUpdate = DateTime.now();
    try {
      final raw = await preferences.getString(_key);
      if (raw != null) {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        final restored = Pond.fromJson(
          json['pond'] as Map<String, dynamic>,
          catalog: catalog,
        );
        final restoredAt = DateTime.fromMillisecondsSinceEpoch(
          json['savedAt'] as int,
        );
        pond = restored;
        lastUpdate = restoredAt;
      }
    } catch (error) {
      debugPrint('Could not load pond: $error');
    }
    return PondController._(pond, preferences, lastUpdate, loadCatalog)
      ..resume();
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
    unawaited(_refreshCatalog());
    notifyListeners();
  }

  Future<void> _refreshCatalog() async {
    final loadCatalog = _loadCatalog;
    if (loadCatalog == null || _refreshingCatalog) return;
    _refreshingCatalog = true;
    try {
      final raw = await loadCatalog();
      final catalog = SpeciesCatalog.decode(raw);
      if (_disposed || catalog.revision <= pond.catalog.revision) return;
      if (_timer != null) _advance();
      pond.applyCatalog(catalog);
      unawaited(_persist());
      notifyListeners();
      await _preferences.setString(_catalogKey, raw);
    } catch (error) {
      debugPrint('Could not refresh fish catalog: $error');
    } finally {
      _refreshingCatalog = false;
    }
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
