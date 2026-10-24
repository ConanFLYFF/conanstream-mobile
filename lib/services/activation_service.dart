import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';

class ActivationService {
  static const String _keyPrefKey = "license_key";
  static const String _salt = "IPTV_PRO_MAX_SECRET_SALT_2026";
  static const String appPrice = "5,00 €";

  // 🔑 Clé maître universelle dédiée à tes tests pour n'importe quel PC
  static const String masterTestKey = "CONAN-5EUR-TEST";

  // 🌐 URL de ton futur serveur Webhook / API de vérification de paiement
  static const String _activationServerUrl = "https://ton-domaine-activation.com/api/check.php";

  static Future<String> getDeviceId() async {
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    try {
      WindowsDeviceInfo windowsInfo = await deviceInfo.windowsInfo;
      return md5.convert(utf8.encode(windowsInfo.deviceId)).toString();
    } catch (_) {
      return md5.convert(utf8.encode("DEFAULT_WINDOWS_DEVICE")).toString();
    }
  }

  static Future<String> getNetworkSignature() async {
    String devId = await getDeviceId();
    return md5.convert(utf8.encode("$devId$_salt")).toString();
  }

  static String generateLicenseKeyForDevice(String deviceId) {
    String raw = "${deviceId.toUpperCase()}_$_salt";
    return md5.convert(utf8.encode(raw)).toString().toUpperCase().substring(0, 16);
  }

  // 🚀 Tente d'interroger ton serveur pour voir si le paiement a été effectué pour cet appareil
  static Future<bool> checkOnlineActivation() async {
    try {
      String devId = await getDeviceId();
      HttpClient client = HttpClient();
      client.badCertificateCallback = (cert, host, port) => true;

      final uri = Uri.parse('$_activationServerUrl?device_id=$devId');
      final request = await client.getUrl(uri).timeout(const Duration(seconds: 5));
      final response = await request.close().timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        String responseBody = await response.transform(utf8.decoder).join();
        Map<String, dynamic> data = json.decode(responseBody);

        // Si le serveur Webhook PayPal valide le paiement pour ce device_id
        if (data['status'] == 'PAID' || data['active'] == true) {
          String expectedKey = generateLicenseKeyForDevice(devId);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_keyPrefKey, expectedKey);
          client.close();
          return true;
        }
      }
      client.close();
    } catch (_) {
      // Si pas d'internet ou serveur non disponible, on ignore silencieusement
    }
    return false;
  }

  static Future<bool> activateLicense(String inputKey) async {
    String cleanedInput = inputKey.trim().toUpperCase();
    
    String devId = await getDeviceId();
    String expectedKey = generateLicenseKeyForDevice(devId);

    // On valide soit la clé générée pour l'appareil, soit la clé maître de test
    if (cleanedInput == expectedKey || cleanedInput == masterTestKey) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyPrefKey, expectedKey);
      return true;
    }
    return false;
  }

  static Future<Map<String, dynamic>> checkAccessStatus() async {
    final prefs = await SharedPreferences.getInstance();
    String? savedKey = prefs.getString(_keyPrefKey);

    String devId = await getDeviceId();
    String expectedKey = generateLicenseKeyForDevice(devId);

    // 1. Si déjà activé en local
    if (savedKey != null && savedKey == expectedKey) {
      return {
        'status': true,
        'reason': 'ACTIVATED',
        'days_remaining': 9999,
        'price': appPrice,
      };
    }

    // 2. Vérification automatique en ligne si le paiement Webhook est passé
    bool onlineActivated = await checkOnlineActivation();
    if (onlineActivated) {
      return {
        'status': true,
        'reason': 'ACTIVATED',
        'days_remaining': 9999,
        'price': appPrice,
      };
    }

    // 3. Sinon, mode période d'essai 5 jours
    return {
      'status': true,
      'reason': 'IN_TRIAL',
      'days_remaining': 5,
      'price': appPrice,
    };
  }
}