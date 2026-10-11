class AppConstants {
  static const String appName = 'Vocabify';

  // Supabase Configuration
  static const String supabaseUrl = 'https://iqribysjojmpjjctjlbf.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlxcmlieXNqb2ptcGpqY3RqbGJmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc4MDc0NjIsImV4cCI6MjA5MzM4MzQ2Mn0.0e2lB1Ebe9H58byMYTSQBlktYsj-_XO5LnkMIHYWrB0';

  // Outbox storage key
  static const String outboxKey = 'vocabify_outbox_v1';
  static const String cachedProfileKey = 'vocabify_cached_profile';
  static const String themeKey = 'vocabify_theme_mode';
}
