import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'outbox_service.dart';

/// Drains local_outbox when connectivity returns.
/// Strict dependency pipeline: CHECK_IN -> DELIVERY -> RETURN -> PAYMENT -> STOP_FINALIZATION
class SyncService {
  SyncService._();
  static final SyncService instance = SyncService._();

  Timer? _timer;
  bool _running = false;

  static const String defaultBaseUrl = 'https://gazroute-backend.onrender.com';

  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 8), (_) => drain());
    Connectivity().onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (online) drain();
    });
  }

  Future<void> drain() async {
    if (_running) return;
    _running = true;
    try {
      final batch = await OutboxService.instance.nextBatch(limit: 20);
      for (final event in batch) {
        await OutboxService.instance.markInFlight(event.clientEventId);
        try {
          final res = await _post(event);
          if (res.success) {
            await OutboxService.instance.markCommitted(event.clientEventId);
          } else {
            await OutboxService.instance.markFailed(
              event.clientEventId,
              res.error ?? 'error',
              isTerminal: res.isTerminal,
            );
            if (!res.isTerminal) {
              break; // Stop batch on transient/network error
            }
          }
        } catch (e) {
          await OutboxService.instance.markFailed(
            event.clientEventId,
            e.toString(),
            isTerminal: false,
          );
          break;
        }
      }
    } finally {
      _running = false;
    }
  }

  Future<_SyncResult> _post(OutboxEvent event) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token == null) {
      return _SyncResult(success: false, error: 'No access token', isTerminal: false);
    }
    final baseUrl = prefs.getString('api_base') ?? defaultBaseUrl;

    // Prefer path embedded in payload (check-in / delivery / closeout / exception).
    String? path;
    String bodyJson = event.payloadJson;
    try {
      final decoded = jsonDecode(event.payloadJson);
      if (decoded is Map<String, dynamic>) {
        if (decoded['path'] is String) {
          path = decoded['path'] as String;
          final stripped = Map<String, dynamic>.from(decoded)..remove('path');
          bodyJson = jsonEncode(stripped);
        }
      }
    } catch (_) {}
    path ??= _pathFor(event.entityType);
    if (path == null) {
      return _SyncResult(success: true); // unknown — drop as committed no-op
    }

    final uri = Uri.parse('$baseUrl$path');
    final res = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
        'Idempotency-Key': event.idempotencyKey,
      },
      body: bodyJson,
    ).timeout(const Duration(seconds: 20));

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return _SyncResult(success: true);
    }
    final isTerminal = res.statusCode >= 400 && res.statusCode < 500;
    return _SyncResult(
      success: false,
      error: 'HTTP ${res.statusCode}: ${res.body}',
      isTerminal: isTerminal,
    );
  }

  String? _pathFor(String entityType) {
    switch (entityType) {
      case 'CHECK_IN':
        return null; // path includes stop id — embedded in payload as `path`
      case 'DELIVERY':
        return null;
      case 'PAYMENT':
        return '/api/v1/payments';
      case 'EXCEPTION':
        return null;
      case 'SAFETY':
        return '/api/v1/safety-incidents';
      case 'CLOSEOUT':
        return null;
      default:
        return null;
    }
  }

  /// Custom drain for path-embedded events (check-in / delivery / exception / closeout).
  Future<bool> postDynamic({
    required String path,
    required String method,
    required Map<String, dynamic> body,
    required String idempotencyKey,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token == null) return false;
    final baseUrl = prefs.getString('api_base') ?? defaultBaseUrl;
    final uri = Uri.parse('$baseUrl$path');
    final res = method == 'POST'
        ? await http.post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
              'Idempotency-Key': idempotencyKey,
            },
            body: jsonEncode(body),
          )
        : await http.get(
            uri,
            headers: {'Authorization': 'Bearer $token'},
          );
    return res.statusCode >= 200 && res.statusCode < 300;
  }
}

class _SyncResult {
  final bool success;
  final bool isTerminal;
  final String? error;
  _SyncResult({required this.success, this.isTerminal = false, this.error});
}

