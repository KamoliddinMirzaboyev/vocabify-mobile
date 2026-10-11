class AppConstants {
  static const String appName = 'Vocabify';

  // Supabase Configuration
  static const String supabaseUrl = 'https://htnagfbbxffkkoghdtso.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh0bmFnZmJieGZma2tvZ2hkdHNvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc1OTg4NTUsImV4cCI6MjA5MzE3NDg1NX0.HBqHA7cJtVL5BNvS8WALX6YYeLBatc7xjWj6ScPOMss';

  // Outbox storage key
  static const String outboxKey = 'vocabify_outbox_v1';
  static const String cachedProfileKey = 'vocabify_cached_profile';
  static const String themeKey = 'vocabify_theme_mode';
}
