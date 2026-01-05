class Env {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static const aiModelName =
      String.fromEnvironment('AI_MODEL_NAME', defaultValue: 'gemini-1.5-flash');
}

class SupabaseConfig {
  const SupabaseConfig({required this.url, required this.anonKey});

  final String url;
  final String anonKey;

  static SupabaseConfig? fromEnvOrNull() {
    if (Env.supabaseUrl.isEmpty || Env.supabaseAnonKey.isEmpty) {
      return null;
    }
    return const SupabaseConfig(url: Env.supabaseUrl, anonKey: Env.supabaseAnonKey);
  }
}

