import 'package:flutter_test/flutter_test.dart';

import 'package:bowie/core/config/app_config.dart';

const url = 'https://abc.supabase.co';
const key = 'eyJhbGciOiJIUzI1NiJ9.eyJyb2xlIjoiYW5vbiJ9.abc_DEF-123';

void main() {
  test('a real URL and key are accepted', () {
    expect(
      const AppConfig(supabaseUrl: url, supabaseAnonKey: key).problem,
      isNull,
    );
    expect(
      const AppConfig(
        supabaseUrl: url,
        supabaseAnonKey: 'sb_publishable_AbC-123',
      ).isConfigured,
      isTrue,
    );
  });

  test('missing or example values ask to fill dart_defines.json', () {
    const missing = AppConfig(supabaseUrl: '', supabaseAnonKey: '');
    const example = AppConfig(
      supabaseUrl: 'https://YOUR_PROJECT.supabase.co',
      supabaseAnonKey: 'YOUR_ANON_KEY',
    );
    expect(missing.problem, contains('não está conectada'));
    expect(example.problem, contains('não está conectada'));
  });

  test('a key copied while masked is caught before any request', () {
    const masked = AppConfig(
      supabaseUrl: url,
      supabaseAnonKey: 'eyJhbGci••••••••',
    );
    expect(masked.isConfigured, isFalse);
    expect(masked.problem, contains('mascarada'));
  });

  test('stray spaces or quotes in the key are caught', () {
    const spaced = AppConfig(supabaseUrl: url, supabaseAnonKey: '$key ');
    expect(spaced.problem, contains('caracteres inválidos'));
  });

  test('the URL must use https', () {
    const http = AppConfig(
      supabaseUrl: 'http://abc.supabase.co',
      supabaseAnonKey: key,
    );
    expect(http.problem, contains('https://'));
  });
}
