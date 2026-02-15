import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../main.dart';

Directory getPersistentCacheDir({String installPath = installPath}) {
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

  final dir = Directory(p.join(base, installPath));

  if (!dir.existsSync()) {
    final oldDir = Directory(p.join(base, "Polaris Launcher"));
    if (oldDir.existsSync()){
      oldDir.renameSync(dir.path);
    }
    dir.createSync(recursive: true);
  }

  return dir;
}

Future<void> deleteCaches({String folder = 'caches', String installPath = installPath}) async {
  final baseDir = getPersistentCacheDir(installPath: installPath);
  final cacheDir = Directory(p.join(baseDir.path, folder));

  if (await cacheDir.exists()) {
    try {
      await cacheDir.delete(recursive: true);
      if (kDebugMode || verbose) {
        print('Deleted cache directory: ${cacheDir.path}');
      }
    } catch (e) {
      stderr.writeln('Failed to delete cache directory: $e');
    }
  } else {
    if (kDebugMode || verbose) {
      print('No cache directory found at ${cacheDir.path}');
    }
  }
}

class PersistentPrefs {
  final File _file;
  final Map<String, dynamic> _cache;
  Timer? _debounce;

  PersistentPrefs._(this._file, this._cache);

  static Future<PersistentPrefs> open({String installPath = installPath, String fileName = 'prefs.json'}) async {
    final dir = getPersistentCacheDir(installPath: installPath);
    final file = File(p.join(dir.path, 'caches', fileName));
    if (!await file.exists()) await file.create(recursive: true);

    final content = await file.readAsString().catchError((_) => '{}');
    final data = jsonDecode(content.isEmpty ? '{}' : content) as Map<String, dynamic>;
    return PersistentPrefs._(file, data);
  }

  void _flush({bool debounce = true}) {
    _debounce?.cancel();
    if (debounce) {
      _debounce = Timer(const Duration(milliseconds: 200), () async {
        final content = await _file.readAsString().catchError((_) => '{}');
        final existing = jsonDecode(content.isEmpty ? '{}' : content) as Map<String, dynamic>;
        final merged = {...existing, ..._cache};
        await _file.writeAsString(jsonEncode(merged));
      });
    } else {
      () async {
        final content = await _file.readAsString().catchError((_) => '{}');
        final existing = jsonDecode(content.isEmpty ? '{}' : content) as Map<String, dynamic>;
        final merged = {...existing, ..._cache};
        await _file.writeAsString(jsonEncode(merged));
      }();
    }
  }

  // setters
  Future<void> setValue(String key, dynamic value) async {
    _cache[key] = value;
    _flush();
  }

  // getters
  T getValue<T>(String key, {T? defaultValue}) {
    final v = _cache[key];
    return v is T ? v : defaultValue as T;
  }

  Future<void> remove(String key) async {
    _cache.remove(key);
    _flush();
  }

  Future<void> clear() async {
    _cache.clear();
    _flush();
  }
}

int toInt(dynamic v, int fallback) {
  if (v is int) return v;
  if (v is double) return v.floor();
  if (v is String) {
    final n = num.tryParse(v);
    if (n != null) return n.floor();
  }
  return fallback;
}


