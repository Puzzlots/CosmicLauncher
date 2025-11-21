import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ItchSecureStore {
  static final _storage = const FlutterSecureStorage();
  static const _key = "itch_api_key";

  static Future<void> saveKey(String value) async {
    await _storage.write(key: _key, value: value);
  }

  static Future<String?> loadKey() async {
    return await _storage.read(key: _key);
  }

  static Future<void> deleteKey() async {
    await _storage.delete(key: _key);
  }
}
