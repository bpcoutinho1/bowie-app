import 'package:shared_preferences/shared_preferences.dart';

/// Whether the person agreed to send card photos to be read in the cloud
/// (docs/produto/dados-e-privacidade.md). Asked once per device.
abstract interface class ReadingConsent {
  Future<bool> given();

  Future<void> give();
}

class PrefsReadingConsent implements ReadingConsent {
  PrefsReadingConsent([SharedPreferencesAsync? prefs])
    : _prefs = prefs ?? SharedPreferencesAsync();

  static const _key = 'card_reading_consent_v1';
  final SharedPreferencesAsync _prefs;

  @override
  Future<bool> given() async => await _prefs.getBool(_key) ?? false;

  @override
  Future<void> give() => _prefs.setBool(_key, true);
}

class MemoryReadingConsent implements ReadingConsent {
  MemoryReadingConsent({this.value = false});

  bool value;

  @override
  Future<bool> given() async => value;

  @override
  Future<void> give() async => value = true;
}
