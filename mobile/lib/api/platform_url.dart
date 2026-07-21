/// Platform-specific base URL resolution.
/// Uses conditional imports so dart:html is never loaded on Android.

import 'platform_url_stub.dart'
    if (dart.library.js_interop) 'platform_url_web.dart';

/// Returns the backend base URL appropriate for the current platform.
String getPlatformBaseUrl() => resolveBaseUrl();

/// Async version — on Android reads the user's saved URL from SharedPreferences.
Future<String> getPlatformBaseUrlAsync() async {
  try {
    return await resolveBaseUrlAsync();
  } catch (_) {
    return resolveBaseUrl();
  }
}

/// Save a custom base URL (for the Settings screen).
Future<void> savePlatformBaseUrl(String url) async {
  try {
    await saveBaseUrl(url);
  } catch (_) {}
}
