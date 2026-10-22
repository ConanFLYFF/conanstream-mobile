import 'dart:convert';
import 'package:http/http.dart' as http;
import 'app_logger.dart';

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