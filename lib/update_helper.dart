import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:install_plugin_v2/install_plugin_v2.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateHelper {
  static const String jsonUrl = 'https://raw.githubusercontent.com/ConanFLYFF/conanstream-mobile/main/version.json';

  static Future<void> checkUpdate(BuildContext context) async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentBuildNumber = int.tryParse(packageInfo.buildNumber) ?? 0;

      final response = await http.get(Uri.parse(jsonUrl)).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final int remoteVersionCode = data['versionCode'] ?? 0;
        final String notes = data['releaseNotes'] ?? '';
        final String apkUrl = data['apkUrl'] ?? '';
        final String exeUrl = data['exeUrl'] ?? '';

        if (remoteVersionCode > currentBuildNumber && context.mounted) {
          _showUpdateDialog(
            context: context,
            versionName: data['versionName'] ?? '$remoteVersionCode',
            notes: notes,
            apkUrl: apkUrl,
            exeUrl: exeUrl,
          );
        }
      }
    } catch (_) {
      // Ignorer si pas de connexion
    }
  }

  static void _showUpdateDialog({
    required BuildContext context,
    required String versionName,
    required String notes,
    required String apkUrl,
    required String exeUrl,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0C101C),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF00E5FF), width: 1.5),
        ),
        title: Text(
          Platform.isWindows ? 'Mise à jour Windows disponible' : 'Mise à jour Android disponible',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Version $versionName est disponible.', style: const TextStyle(color: Color(0xFF00E5FF))),
            const SizedBox(height: 10),
            Text(notes, style: const TextStyle(color: Colors.white70)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Plus tard', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E5FF),
              foregroundColor: Colors.black,
            ),
            onPressed: () async {
              Navigator.pop(context);
              if (Platform.isAndroid) {
                _downloadAndInstallAndroid(context, apkUrl);
              } else if (Platform.isWindows) {
                final Uri url = Uri.parse(exeUrl);
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                }
              }
            },
            child: const Text('Mettre à jour'),
          ),
        ],
      ),
    );
  }

  static Future<void> _downloadAndInstallAndroid(BuildContext context, String url) async {
    try {
      // Afficher un indicateur de téléchargement (optionnel mais propre)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Téléchargement de la mise à jour en cours...')),
      );

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final dir = await getTemporaryDirectory();
        final filePath = '${dir.path}/update.apk';
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);

        // Lancer l'installation de l'APK
        await InstallPlugin.installApk(filePath);
      } else {
        throw Exception('Erreur de téléchargement');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Échec de la mise à jour : $e')),
        );
      }
    }
  }
}