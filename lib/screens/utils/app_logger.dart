import 'package:flutter/foundation.dart';

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

  static void storage(String key, dynamic value) {
    final time = DateTime.now().toIso8601String().split('T').last;
    debugPrint('🟨 [$time] [STORAGE] Clé: "$key" -> Valeur: $value');
  }

  static void error(String category, dynamic error, [StackTrace? stack]) {
    final time = DateTime.now().toIso8601String().split('T').last;
    debugPrint('🟥 [$time] [EXCEPTION] [$category] $error');
    if (stack != null) {
      debugPrint('   Stacktrace: $stack');
    }
  }
}


