import 'package:shared_preferences/shared_preferences.dart';

/// Small yes-or-no choices kept on the phone, like a dismissed tip.
abstract interface class Flags {
  Future<bool> isSet(String key);

  Future<void> set(String key);
}

class PrefsFlags implements Flags {
  PrefsFlags([SharedPreferencesAsync? prefs])
    : _prefs = prefs ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _prefs;

  @override
  Future<bool> isSet(String key) async => await _prefs.getBool(key) ?? false;

  @override
  Future<void> set(String key) => _prefs.setBool(key, true);
}

class MemoryFlags implements Flags {
  final _set = <String>{};

  @override
  Future<bool> isSet(String key) async => _set.contains(key);

  @override
  Future<void> set(String key) async => _set.add(key);
}
