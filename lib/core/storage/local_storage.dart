/// Small key-value local persistence (backed by [SharedPreferences] in production).
abstract class LocalStorage {
  String? getString(String key);

  Future<void> setString(String key, String value);

  Future<void> remove(String key);

  bool? getBool(String key);

  Future<void> setBool(String key, bool value);

  int? getInt(String key);

  Future<void> setInt(String key, int value);
}
