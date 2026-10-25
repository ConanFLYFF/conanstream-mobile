import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Logger interne pour éviter tout problème d'importation inter-dossiers
class AppLogger {
  static void action(String category, String message) {
    final time = DateTime.now().toIso8601String().split('T').last;
    debugPrint('🟩 [$time] [ACTION] [$category] $message');
  }

  static void httpReq(String method, String url, int statusCode, int durationMs, {String? error}) {
    final time = DateTime.now().toIso8601String().split('T').last;
    if (statusCode >= 200 && statusCode < 300) {
      debugPrint('🟦 [$time] [HTTP OK] $method $statusCode (${durationMs}ms) -> $url');
    } else {
      debugPrint('🟥 [$time] [HTTP ERR] $method $statusCode (${durationMs}ms) -> $url | Erreur: ${error ?? 'Code statut invalide'}');
    }
  }

  static void error(String category, dynamic error, [StackTrace? stack]) {
    final time = DateTime.now().toIso8601String().split('T').last;
    debugPrint('🟥 [$time] [EXCEPTION] [$category] $error');
    if (stack != null) {
      debugPrint('   Stacktrace: $stack');
    }
  }
}

class ApiClient {
  static final http.Client _client = http.Client();

  static Future<http.Response?> get(Uri url) async {
    final stopwatch = Stopwatch()..start();
    try {
      final response = await _client.get(url);
      stopwatch.stop();
      AppLogger.httpReq('GET', url.toString(), response.statusCode, stopwatch.elapsedMilliseconds);
      return response;
    } catch (e, stack) {
      stopwatch.stop();
      AppLogger.httpReq('GET', url.toString(), 0, stopwatch.elapsedMilliseconds, error: e.toString());
      AppLogger.error('HTTP_GET', e, stack);
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getJson(Uri url) async {
    final response = await get(url);
    if (response != null && response.statusCode == 200) {
      try {
        return json.decode(response.body) as Map<String, dynamic>;
      } catch (e, stack) {
        AppLogger.error('JSON_DECODE', e, stack);
      }
    }
    return null;
  }
}

