import 'package:red5/core/storage/local_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SharedPreferencesStorage implements LocalStorage {
  SharedPreferencesStorage(this._prefs);

  final SharedPreferences _prefs;

  static Future<SharedPreferencesStorage> create() async {
    final prefs = await SharedPreferences.getInstance();
    return SharedPreferencesStorage(prefs);
  }

  @override
  String? getString(String key) => _prefs.getString(key);

  @override
  Future<void> setString(String key, String value) async {
    await _prefs.setString(key, value);
  }

  @override
  Future<void> remove(String key) async {
    await _prefs.remove(key);
  }

  @override
  bool? getBool(String key) => _prefs.getBool(key);

  @override
  Future<void> setBool(String key, bool value) async {
    await _prefs.setBool(key, value);
  }

  @override
  int? getInt(String key) => _prefs.getInt(key);

  @override
  Future<void> setInt(String key, int value) async {
    await _prefs.setInt(key, value);
  }
}
