import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';

class ActivationService {
  static const String _keyPrefKey = "license_key";
  static const String _salt = "IPTV_PRO_MAX_SECRET_SALT_2026";
  static const String appPrice = "5,00 €"; // Prix fixe de l'application / abonnement

  static Future<String> getDeviceId() async {
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    try {
      AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      return md5.convert(utf8.encode(androidInfo.id)).toString();
    } catch (_) {
      return md5.convert(utf8.encode("DEFAULT_ANDROID_DEVICE")).toString();
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
    String devId = await getDeviceId();
    String expectedKey = generateLicenseKeyForDevice(devId);

    if (inputKey.trim().toUpperCase() == expectedKey) {
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

    const String firstLaunchKey = "first_launch_date";
    int? firstLaunch = prefs.getInt(firstLaunchKey);

    if (firstLaunch == null) {
      firstLaunch = DateTime.now().millisecondsSinceEpoch;
      await prefs.setInt(firstLaunchKey, firstLaunch);
    }

    DateTime startDate = DateTime.fromMillisecondsSinceEpoch(firstLaunch);
    int daysPassed = DateTime.now().difference(startDate).inDays;
    int daysRemaining = 5 - daysPassed;

    if (daysRemaining > 0) {
      return {
        'status': true,
        'reason': 'IN_TRIAL',
        'days_remaining': daysRemaining,
        'price': appPrice,
      };
    } else {
      return {
        'status': false,
        'reason': 'EXPIRED',
        'days_remaining': 0,
        'price': appPrice,
      };
    }
  }
}
```[cite: 11]

Envoie le prochain fichier à traiter pour Android !