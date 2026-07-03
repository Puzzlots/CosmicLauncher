import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'general_utils.dart';

class ItchSecureStore {
  static final _storage = const FlutterSecureStorage();
  static const _key = "itch_api_key";

  static late String username;

  static Future<void> saveKey(String value) async {
    await _storage.write(key: _key, value: value);
    await _loadUsername(value);
  }

  static Future<String?> loadKey() async {
    return await _storage.read(key: _key);
  }

  static Future<void> deleteKey() async {
    await _storage.delete(key: _key);
  }

  static Future<void> _loadUsername(String value) async {
    username = (await getUsername(value)) ?? 'Saturn';
  }

  static Future<void> init() async {
    await _loadUsername(await loadKey() ?? '');
  }
}
