import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/pipeline_result.dart';
import 'platform_url.dart';

/// Thin REST + SSE streaming client for the MED AGENT Django backend.
class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  String baseUrl = getPlatformBaseUrl();
  String? _token;
  Map<String, dynamic>? _cachedUser;

  /// Call once at app startup to load the user's saved server URL.
  Future<void> init() async {
    try {
      final saved = await getPlatformBaseUrlAsync();
      if (saved.isNotEmpty) baseUrl = saved;
    } catch (_) {}
  }

  /// Update the server URL and persist it.
  Future<void> updateBaseUrl(String url) async {
    baseUrl = url;
    await savePlatformBaseUrl(url);
  }

  bool get isAuthenticated => _token != null;
  String? get token => _token;
  Map<String, dynamic>? get cachedUser => _cachedUser;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Token $_token',
      };

  // ── Persistence ──

  Future<void> restoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString('auth_token');
      if (_token != null) {
        try {
          final user = await getMe();
          _cachedUser = user;
        } catch (_) {
          _token = null;
          await prefs.remove('auth_token');
        }
      }
    } catch (_) {}
  }

  Future<void> _saveToken(String token) async {
    _token = token;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', token);
    } catch (_) {}
  }

  Future<void> logout() async {
    _token = null;
    _cachedUser = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
    } catch (_) {}
  }

  // ── Auth ──

  /// Extract a human-readable error from DRF response data.
  /// DRF returns either {"detail": "..."} or {"field": ["error1", ...]}.
  String _extractError(Map<String, dynamic> data) {
    // Simple detail string
    if (data.containsKey('detail')) return data['detail'].toString();
    // Field-level errors from DRF serializer
    final msgs = <String>[];
    data.forEach((field, value) {
      if (value is List) {
        msgs.addAll(value.map((e) => e.toString()));
      } else {
        msgs.add('$field: $value');
      }
    });
    return msgs.isEmpty ? 'Registration failed' : msgs.join('\n');
  }

  Future<Map<String, dynamic>> register(String username, String email, String password, {
    String fullName = '',
    String phone = '',
    String? dateOfBirth,
    String bloodType = '',
    double? heightCm,
    double? weightKg,
    String knownAllergies = '',
    String address = '',
  }) async {
    final body = {
      'username': username,
      'email': email,
      'password': password,
      if (fullName.isNotEmpty) 'full_name': fullName,
      if (phone.isNotEmpty) 'phone': phone,
      if (dateOfBirth != null) 'date_of_birth': dateOfBirth,
      if (bloodType.isNotEmpty) 'blood_type': bloodType,
      if (heightCm != null) 'height_cm': heightCm,
      if (weightKg != null) 'weight_kg': weightKg,
      if (knownAllergies.isNotEmpty) 'known_allergies': knownAllergies,
      if (address.isNotEmpty) 'address': address,
    };
    final res = await http.post(
      Uri.parse('$baseUrl/api/auth/register/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode == 200 || res.statusCode == 201) {
      await _saveToken(data['token'] as String);
      _cachedUser = data['user'] as Map<String, dynamic>?;
      return data;
    }
    throw Exception(_extractError(data));
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/auth/login/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode == 200 || res.statusCode == 201) {
      await _saveToken(data['token'] as String);
      _cachedUser = data['user'] as Map<String, dynamic>?;
      return data;
    }
    throw Exception(_extractError(data));
  }

  Future<Map<String, dynamic>> getMe() async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/auth/me/'),
      headers: _headers,
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      _cachedUser = data;
      return data;
    }
    throw Exception('Failed to load profile');
  }

  // ── Profile ──

  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> fields) async {
    final res = await http.put(
      Uri.parse('$baseUrl/api/auth/me/'),
      headers: _headers,
      body: jsonEncode(fields),
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      _cachedUser = data['user'] as Map<String, dynamic>? ?? data;
      return _cachedUser!;
    }
    throw Exception('Failed to update profile');
  }

  // ── Nearby hospitals ──

  Future<List<Map<String, dynamic>>> getNearbyHospitals({
    required double latitude,
    required double longitude,
    int radius = 5000,
    String category = 'hospital',
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/auth/nearby/'),
      headers: _headers,
      body: jsonEncode({
        'latitude': latitude,
        'longitude': longitude,
        'radius': radius,
        'category': category,
      }),
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return (data['results'] as List).cast<Map<String, dynamic>>();
    }
    throw Exception('Failed to fetch nearby locations');
  }

  // ── Streaming diagnosis ──

  /// Opens an SSE stream to `/api/pipeline/stream/` and yields parsed events.
  /// Each event is a Map with a "type" key: stage_start, stage_output,
  /// stage_validated, beta_fallback, pipeline_halted, pipeline_done, error.
  Stream<Map<String, dynamic>> analyzeStream(String text, {bool beta = true}) async* {
    final url = Uri.parse('$baseUrl/api/pipeline/stream/');
    final request = http.Request('POST', url);
    request.headers.addAll(_headers);
    request.body = jsonEncode({'text': text, 'beta': beta});

    final response = await http.Client().send(request);

    if (response.statusCode != 200) {
      yield {'type': 'error', 'message': 'Server error ${response.statusCode}'};
      return;
    }

    // Process SSE stream line by line.
    String buffer = '';
    await for (final chunk in response.stream.transform(utf8.decoder)) {
      buffer += chunk;
      // SSE events are separated by double newlines.
      while (buffer.contains('\n\n')) {
        final idx = buffer.indexOf('\n\n');
        final eventBlock = buffer.substring(0, idx);
        buffer = buffer.substring(idx + 2);

        for (final line in eventBlock.split('\n')) {
          if (line.startsWith('data: ')) {
            final jsonStr = line.substring(6);
            try {
              final event = jsonDecode(jsonStr) as Map<String, dynamic>;
              yield event;
            } catch (_) {
              // skip malformed lines
            }
          }
        }
      }
    }
  }

  // (analyzeLab removed — unused)

  /// Non-streaming analysis fallback.
  Future<PipelineResult> analyze(String text, {String? model, String? analyzerModel, bool beta = false}) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/pipeline/analyze/'),
      headers: _headers,
      body: jsonEncode({
        'text': text,
        if (model != null) 'model': model,
        if (analyzerModel != null) 'analyzer_model': analyzerModel,
        'beta': beta,
      }),
    );
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode == 200 || res.statusCode == 422) {
      return PipelineResult.fromJson(data);
    }
    throw Exception(data['detail'] ?? 'Analysis failed');
  }
}
