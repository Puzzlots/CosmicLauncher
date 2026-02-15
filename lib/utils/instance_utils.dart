import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:polaris/utils/version_cache.dart';

import '../main.dart';
import 'cache_utils.dart';

class InstanceManager {
  static final InstanceManager _instance =
  InstanceManager._internal(baseDir: installPath);

  factory InstanceManager() => _instance;

  InstanceManager._internal({required this.baseDir});

  final String baseDir;

  Map<String, Map<String, List<Map<String, String>>>> currentVersions = {};

  Directory get _instancesDir {
    final dir = Directory(p.join(getPersistentCacheDir(installPath: baseDir).path, 'instances'));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  String getInstanceFilePath(String id) {
    return p.join(_instancesDir.path, '$id.json');
  }

  Future<void> saveInstance(String id, Map<String, dynamic> details) async {
    final file = File(p.join(_instancesDir.path, '$id.json'));
    await file.writeAsString(jsonEncode(details));
  }

  Future<Map<String, dynamic>?> loadInstance(String id) async {
    final file = File(p.join(_instancesDir.path, '$id.json'));
    if (!await file.exists()) return null;

    return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> loadAllInstances() async {
    final ids = _instancesDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .map((f) {
          final name = f.uri.pathSegments.last;
          final parts = name.split('.');
          return parts.length > 1 ? parts.sublist(0, parts.length - 1).join('.') : name;
        })
        .toList();

    if (kDebugMode) {
      print("Loaded: $ids");
    }

    final raw = await Future.wait(ids.map(loadInstance));
    return raw.whereType<Map<String, dynamic>>().toList();
  }


  Future<void> deleteInstance(dynamic id) async {
    final file = File(p.join(_instancesDir.path, '$id.json')); // did u accidentally press the exit button?
    if (await file.exists()) await file.delete(); //shit it crashed idk if that was me pressing the exit button?, it was when i pressed enter on the search
  }

  Future<void> clearAll() async {
    await for (final f in _instancesDir.list()) {
      if (f is File && f.path.endsWith('.json')) await f.delete();
    }
  }

  Future<bool> instanceExists(String id) async {
    final file = File(getInstanceFilePath(id));
    return file.exists();
  }
}
