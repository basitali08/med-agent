import 'package:shared_preferences/shared_preferences.dart';

/// Stub (non-web) implementation — returns the host machine URL.
/// The user can change this at runtime via Settings > Server URL.
/// Stored in SharedPreferences so it persists across app restarts.

const String _defaultBaseUrl = 'http://192.168.100.24:8000';
const String prefsKeyBaseUrl = 'server_base_url';

/// Synchronous fallback — returns the default or last-saved URL.
String resolveBaseUrl() => _defaultBaseUrl;

/// Async version — reads the user's saved URL from SharedPreferences.
Future<String> resolveBaseUrlAsync() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(prefsKeyBaseUrl) ?? _defaultBaseUrl;
}

/// Save a new base URL to SharedPreferences.
Future<void> saveBaseUrl(String url) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(prefsKeyBaseUrl, url);
}
