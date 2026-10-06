import 'package:shared_preferences/shared_preferences.dart';

/// The house last opened on this phone, for people without a house of their
/// own (docs/produto/compras.md).
abstract interface class LastHouse {
  Future<String?> read();

  Future<void> write(String houseId);
}

class PrefsLastHouse implements LastHouse {
  PrefsLastHouse([SharedPreferencesAsync? prefs])
    : _prefs = prefs ?? SharedPreferencesAsync();

  static const _key = 'last_house_id';
  final SharedPreferencesAsync _prefs;

  @override
  Future<String?> read() => _prefs.getString(_key);

  @override
  Future<void> write(String houseId) => _prefs.setString(_key, houseId);
}

class MemoryLastHouse implements LastHouse {
  MemoryLastHouse([this.value]);

  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String houseId) async => value = houseId;
}
