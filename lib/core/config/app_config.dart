class AppConfig {
  const AppConfig({required this.supabaseUrl, required this.supabaseAnonKey});

  final String supabaseUrl;
  final String supabaseAnonKey;

  /// Keys are base64url (JWT) or `sb_publishable_…`: letters, digits, `.`, `_`, `-`.
  static final _keyPattern = RegExp(r'^[A-Za-z0-9._-]+$');

  bool get isConfigured => problem == null;

  /// What is wrong with the Supabase settings, in Portuguese, or null.
  String? get problem {
    if (supabaseUrl.isEmpty ||
        supabaseAnonKey.isEmpty ||
        supabaseUrl.contains('YOUR_PROJECT') ||
        supabaseAnonKey.contains('YOUR_ANON_KEY')) {
      return 'Esta versão ainda não está conectada ao servidor. Copie '
          'dart_defines.example.json para dart_defines.json, preencha a URL e a '
          'chave anon do Supabase e rode com '
          '--dart-define-from-file=dart_defines.json.';
    }
    if (!supabaseUrl.startsWith('https://')) {
      return 'A SUPABASE_URL do dart_defines.json precisa começar com https://.';
    }
    if (supabaseAnonKey.contains('•')) {
      return 'A chave do Supabase no dart_defines.json está mascarada (com •). '
          'No painel do Supabase, use o botão de copiar ao lado da chave anon '
          'e cole de novo.';
    }
    if (!_keyPattern.hasMatch(supabaseAnonKey)) {
      return 'A chave do Supabase no dart_defines.json tem caracteres inválidos '
          '(espaços, aspas ou quebras de linha). Copie a chave anon de novo.';
    }
    return null;
  }

  factory AppConfig.fromEnvironment() {
    return const AppConfig(
      supabaseUrl: String.fromEnvironment('SUPABASE_URL'),
      supabaseAnonKey: String.fromEnvironment('SUPABASE_ANON_KEY'),
    );
  }
}
