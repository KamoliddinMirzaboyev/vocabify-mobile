class AppConstants {
  static const String appName = 'Vocabify';
  
  // Supabase Configuration
  static const String supabaseUrl = 'https://htnagfbbxffkkoghdtso.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh0bmFnZmJieGZma2tvZ2hkdHNvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc1OTg4NTUsImV4cCI6MjA5MzE3NDg1NX0.HBqHA7cJtVL5BNvS8WALX6YYeLBatc7xjWj6ScPOMss';

  // Groq API Key for Speaking Partner
  // Can be passed via --dart-define=GROQ_API_KEY=your_key or entered in Profile settings
  static const String groqApiKey = String.fromEnvironment('GROQ_API_KEY');

  // Outbox storage key
  static const String outboxKey = 'vocabify_outbox_v1';
  static const String cachedProfileKey = 'vocabify_cached_profile';
  static const String themeKey = 'vocabify_theme_mode';
}
