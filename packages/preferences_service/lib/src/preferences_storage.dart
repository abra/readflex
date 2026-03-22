import 'package:shared_preferences/shared_preferences.dart'
    show SharedPreferencesAsync;

/// Thin wrapper over [SharedPreferencesAsync].
///
/// Centralises all SharedPreferences access so that the storage backend
/// can be replaced (e.g. Hive, SQLite) without touching feature packages.
class PreferencesStorage {
  PreferencesStorage() : _prefs = SharedPreferencesAsync();

  final SharedPreferencesAsync _prefs;

  Future<String?> getString(String key) => _prefs.getString(key);

  Future<void> setString(String key, String value) =>
      _prefs.setString(key, value);
}
