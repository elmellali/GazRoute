import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// REST client with Idempotency-Key + client_event_id support.
class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  static const String defaultBaseUrl = 'https://gazroute-backend.onrender.com';

  Future<String> get baseUrl async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('api_base') ?? defaultBaseUrl;
  }

  Future<Map<String, String>> _headers({String? idempotencyKey}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
      if (idempotencyKey != null) 'Idempotency-Key': idempotencyKey,
    };
  }

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    String? idempotencyKey,
  }) async {
    final base = await baseUrl;
    final key = idempotencyKey ?? const Uuid().v4();
    final payload = {
      if (!body.containsKey('client_event_id')) 'client_event_id': key,
      ...body,
    };
    final res = await http
        .post(
          Uri.parse('$base$path'),
          headers: await _headers(idempotencyKey: key),
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 25));
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return res.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw ApiException(res.statusCode, _detail(res.body));
  }

  Future<dynamic> get(String path) async {
    final base = await baseUrl;
    final res = await http
        .get(Uri.parse('$base$path'), headers: await _headers())
        .timeout(const Duration(seconds: 25));
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return res.body.isEmpty ? null : jsonDecode(res.body);
    }
    throw ApiException(res.statusCode, _detail(res.body));
  }

  String _detail(String body) {
    try {
      final j = jsonDecode(body);
      if (j is Map && j['detail'] != null) return j['detail'].toString();
    } catch (_) {}
    return body;
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);

  @override
  String toString() => 'API $statusCode: $message';
}
