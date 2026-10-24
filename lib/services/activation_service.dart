import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';

class ActivationService {
  static const String _keyPrefKey = "license_key";
  static const String _salt = "IPTV_PRO_MAX_SECRET_SALT_2026";
  static const String appPrice = "5,00 €";

  // 🔑 Clé maître universelle dédiée à tes tests pour n'importe quel PC
  static const String masterTestKey = "CONAN-5EUR-TEST";

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

    if (savedKey != null && savedKey == expectedKey) {
      return {
        'status': true,
        'reason': 'ACTIVATED',
        'days_remaining': 9999,
        'price': appPrice,
      };
    }

    return {
      'status': true,
      'reason': 'IN_TRIAL',
      'days_remaining': 5,
      'price': appPrice,
    };
  }
}