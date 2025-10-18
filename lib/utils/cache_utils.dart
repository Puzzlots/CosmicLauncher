import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../main.dart';

Directory getPersistentCacheDir({String appName = title}) {
  late final String base;

  if (Platform.isWindows) {
    base = Platform.environment['APPDATA'] ??
        Platform.environment['LOCALAPPDATA'] ??
        Directory.current.path;
  } else if (Platform.isMacOS) {
    base = p.join(Platform.environment['HOME'] ?? Directory.current.path,
        'Library', 'Application Support');
  } else if (Platform.isLinux) {
    base = Platform.environment['XDG_DATA_HOME'] ??
        p.join(Platform.environment['HOME'] ?? Directory.current.path,
            '.local', 'share');
  } else {
    // Fallback for other OSes
    base = Directory.current.path;
  }

  final dir = Directory(p.join(base, appName));
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  }
  return dir;
}

Future<void> deleteCaches({String appName = title}) async {
  final baseDir = getPersistentCacheDir(appName: appName);
  final cacheDir = Directory(p.join(baseDir.path, 'caches'));

  if (await cacheDir.exists()) {
    try {
      await cacheDir.delete(recursive: true);
      if (kDebugMode) {
        print('Deleted cache directory: ${cacheDir.path}');
      }
    } catch (e) {
      stderr.writeln('Failed to delete cache directory: $e');
    }
  } else {
    if (kDebugMode) {
      print('No cache directory found at ${cacheDir.path}');
    }
  }
}

class PersistentPrefs {
  static PersistentPrefs? _instance;
  late File _file;
  Map<String, dynamic> _cache = {};

  // Timer for debouncing writes
  Timer? _debounce;

  PersistentPrefs._();

  /// Open or create the prefs file
  static Future<PersistentPrefs> open({String appName = title}) async {
    if (_instance != null) return _instance!;

    final dir = getPersistentCacheDir(appName: appName);
    final file = File(p.join("${dir.path}/caches/", 'prefs.json'));
    if (!await file.exists()) await file.create(recursive: true);

    final content = await file.readAsString().catchError((_) => '{}');
    final data = jsonDecode(content.isEmpty ? '{}' : content) as Map<String, dynamic>;

    final instance = PersistentPrefs._();
    instance._file = file;
    instance._cache = data;
    _instance = instance;
    return instance;
  }

  /// --- Internal flush with optional debounce ---
  void _flush({bool debounce = true}) {
    // Cancel previous debounce if any
    _debounce?.cancel();

    if (debounce) {
      // Schedule a write after a short delay
      _debounce = Timer(const Duration(milliseconds: 200), () async {
        final content = await _file.readAsString().catchError((_) => '{}');
        final data = jsonDecode(content.isEmpty ? '{}' : content) as Map<String, dynamic>;
        final merged = {...data, ..._cache};
        await _file.writeAsString(jsonEncode(merged));
      });
    } else {
      // Immediate write
      () async {
        final content = await _file.readAsString().catchError((_) => '{}');
        final data = jsonDecode(content.isEmpty ? '{}' : content) as Map<String, dynamic>;
        final merged = {...data, ..._cache};
        await _file.writeAsString(jsonEncode(merged));
      }();
    }
  }

  /// --- Setters ---
  Future<void> setString(String key, String value) async {
    _cache[key] = value;
    _flush();
  }

  Future<void> setInt(String key, int value) async {
    _cache[key] = value;
    _flush();
  }

  Future<void> setBool(String key, bool value) async {
    _cache[key] = value;
    _flush();
  }

  Future<void> setDouble(String key, double value) async {
    _cache[key] = value;
    _flush();
  }

  /// --- Getters ---
  String getString(String key, {String defaultValue = ''}) {
    final v = _cache[key];
    return v is String ? v : defaultValue;
  }

  int getInt(String key, {int defaultValue = 0}) {
    final v = _cache[key];
    return v is int ? v : defaultValue;
  }

  bool getBool(String key, {bool defaultValue = false}) {
    final v = _cache[key];
    return v is bool ? v : defaultValue;
  }

  double getDouble(String key, {double defaultValue = 0.0}) {
    final v = _cache[key];
    return v is double
        ? v
        : (v is int ? v.toDouble() : defaultValue);
  }

  /// --- Remove key ---
  Future<void> remove(String key) async {
    _cache.remove(key);
    _flush();
  }

  /// --- Clear all ---
  Future<void> clear() async {
    _cache.clear();
    _flush();
  }
}

