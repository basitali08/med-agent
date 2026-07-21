/// Web implementation — uses window.location.hostname to auto-detect the server.

import 'dart:html' as html;

String resolveBaseUrl() {
  try {
    final host = html.window.location.hostname ?? '';
    if (host.isNotEmpty && host != 'localhost' && host != '127.0.0.1') {
      return 'http://$host:8000';
    }
  } catch (_) {}
  return 'http://localhost:8000';
}

/// On web, always return the detected host URL.
Future<String> resolveBaseUrlAsync() async => resolveBaseUrl();

/// On web, custom base URLs are not persisted (use localStorage if needed).
Future<void> saveBaseUrl(String url) async {
  try {
    html.window.localStorage['server_base_url'] = url;
  } catch (_) {}
}
