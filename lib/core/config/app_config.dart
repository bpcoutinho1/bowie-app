class AppConfig {
  const AppConfig({required this.supabaseUrl, required this.supabaseAnonKey});

  final String supabaseUrl;
  final String supabaseAnonKey;

  bool get isConfigured {
    if (!supabaseUrl.startsWith('https://')) return false;
    if (supabaseAnonKey.isEmpty) return false;
    if (supabaseUrl.contains('YOUR_PROJECT')) return false;
    if (supabaseAnonKey.contains('YOUR_ANON_KEY')) return false;
    return true;
  }

  factory AppConfig.fromEnvironment() {
    return const AppConfig(
      supabaseUrl: String.fromEnvironment('SUPABASE_URL'),
      supabaseAnonKey: String.fromEnvironment('SUPABASE_ANON_KEY'),
    );
  }
}
