class AppConfig {
  static const String appName = 'POSAce';
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000/api/v1',
  );
  
  static const String supabaseUrl = 'https://wqjirowshlxfjcjmydfk.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Indxamlyb3dzaGx4Zmpjam15ZGZrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njk0MjI0NjIsImV4cCI6MjA4NDk5ODQ2Mn0.9mDEINfZVcC1MiePGmm_RqGptBv2J6hsAhI3D-r5WDA';
}
