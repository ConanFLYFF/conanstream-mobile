import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateService {
  static const String githubRepo = "ConanFLYFF/conanstream-mobile";

  static Future<void> checkForUpdates(BuildContext context) async {
    try {
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      String currentVersion = packageInfo.version;

      final response = await http.get(
        Uri.parse('https://api.github.com/repos/$githubRepo/releases/latest'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        String latestVersion = data['tag_name'].toString().replaceAll('v', '');
        
        String? apkUrl;
        if (data['assets'] != null && data['assets'] is List) {
          for (var asset in data['assets']) {
            if (asset['name'].toString().endsWith('.apk')) {
              apkUrl = asset['browser_download_url'];
              break;
            }
          }
        }

        if (_isNewerVersion(latestVersion, currentVersion) && apkUrl != null) {
          if (context.mounted) {
            _showUpdateDialog(context, latestVersion, apkUrl);
          }
        }
      }
    } catch (e) {
      debugPrint("Erreur de vérification des mises à jour : $e");
    }
  }

  static bool _isNewerVersion(String latest, String current) {
    List<String> latestParts = latest.split('.');
    List<String> currentParts = current.split('.');

    for (int i = 0; i < 3; i++) {
      int l = i < latestParts.length ? int.tryParse(latestParts[i]) ?? 0 : 0;
      int c = i < currentParts.length ? int.tryParse(currentParts[i]) ?? 0 : 0;
      if (l > c) return true;
      if (l < c) return false;
    }
    return false;
  }

  static void _showUpdateDialog(BuildContext context, String version, String apkUrl) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0C101C),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.system_update, color: Colors.cyanAccent),
              SizedBox(width: 10),
              Text('Mise à jour disponible 🚀', style: TextStyle(color: Colors.white, fontSize: 18)),
            ],
          ),
          content: Text(
            'Une nouvelle version ($version) est disponible. Cliquez sur "Mettre à jour" pour télécharger et installer la dernière version en un clic.',
            style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Plus tard', style: TextStyle(color: Colors.white60)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.cyanAccent,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                Navigator.pop(dialogContext);
                final Uri url = Uri.parse(apkUrl);
                if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Impossible d'ouvrir le lien de téléchargement.")),
                    );
                  }
                }
              },
              child: const Text('METTRE À JOUR', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }
}