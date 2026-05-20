import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String _keyApiKey = 'api_key';
  static const String _keyBaseUrl = 'base_url';

  Future<void> saveSettings(String apiKey, String baseUrl) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyApiKey, apiKey);
    await prefs.setString(_keyBaseUrl, baseUrl);
  }

  Future<Map<String, String>> getSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'apiKey': prefs.getString(_keyApiKey) ?? '',
      'baseUrl': prefs.getString(_keyBaseUrl) ?? 'https://api.openai.com/v1',
    };
  }
}