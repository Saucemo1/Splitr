class ApiConfig {
  // Replace this with your actual Gemini API key
  // You can get it from: https://makersuite.google.com/app/apikey
  static const String geminiApiKey = ''; // Your actual API key
  
  // Alternative: You can also set it via environment variable
  // Run: flutter run -d macos --dart-define=GEMINI_API_KEY=your_actual_key_here
  static String get apiKey {
    const envKey = String.fromEnvironment('GEMINI_API_KEY');
    if (envKey.isNotEmpty) {
      return envKey;
    }
    return geminiApiKey;
  }
}
