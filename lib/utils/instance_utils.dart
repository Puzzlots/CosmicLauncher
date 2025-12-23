import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

import '../main.dart';
import 'cache_utils.dart';

class InstanceManager {
  final String appName;

  InstanceManager({this.appName = title});

  Directory get _instancesDir {
    final dir = Directory(p.join(getPersistentCacheDir(appName: appName).path, 'instances'));
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
        .map((f) => f.uri.pathSegments.last.split('.').first)
        .toList();

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
