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

  Future<void> saveInstance(String id, Map<String, String> details) async {
    final file = File(p.join(_instancesDir.path, '$id.json'));
    await file.writeAsString(jsonEncode(details));
  }

  Future<Map<String, String>?> loadInstance(String id) async {
    final file = File(p.join(_instancesDir.path, '$id.json'));
    if (!await file.exists()) return null;
    final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    return data.map((k, v) => MapEntry(k, v.toString()));
  }

  Future<List<Map<String, String>>> loadAllInstances() async {
    final files = _instancesDir.listSync().whereType<File>().where((f) => f.path.endsWith('.json'));
    final List<Map<String, String>> instances = [];
    for (final f in files) {
      final data = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      instances.add(data.map((k, v) => MapEntry(k, v.toString())));
    }
    return instances;
  }

  Future<void> deleteInstance(String id) async {
    final file = File(p.join(_instancesDir.path, '$id.json'));
    if (await file.exists()) await file.delete();
  }

  Future<void> clearAll() async {
    await for (final f in _instancesDir.list()) {
      if (f is File && f.path.endsWith('.json')) await f.delete();
    }
  }
}
