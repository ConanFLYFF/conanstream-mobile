import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:r_upgrade/r_upgrade.dart';

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
        return StatefulBuilder(
          builder: (context, setState) {
            bool isDownloading = false;
            double progress = 0.0;

            void startAutoUpgrade() async {
              setState(() {
                isDownloading = true;
              });

              // Télécharge et déclenche l'installation Android automatiquement
              int? id = await RUpgrade.upgrade(
                apkUrl,
                fileName: 'conanstream-update.apk',
                isAutoRequestInstall: true, // 👈 Lance l'installation dès la fin du téléchargement
              );

              // Écoute la progression du téléchargement
              RUpgrade.stream.listen((DownloadInfo info) {
                if (info.status == DownloadStatus.DOWNLOADING) {
                  setState(() {
                    progress = (info.percent ?? 0) / 100;
                  });
                } else if (info.status == DownloadStatus.STATUS_SUCCESSFUL) {
                  if (context.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                }
              });
            }

            return AlertDialog(
              backgroundColor: const Color(0xFF0C101C),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: const [
                  Icon(Icons.system_update, color: Colors.indigoAccent),
                  SizedBox(width: 10),
                  Text('Mise à jour disponible 🚀', style: TextStyle(color: Colors.white, fontSize: 18)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Une nouvelle version ($version) est disponible. Cliquez sur Mettre à jour pour lancer l\'installation automatique.',
                    style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14),
                  ),
                  if (isDownloading) ...[
                    const SizedBox(height: 20),
                    LinearProgressIndicator(
                      value: progress > 0 ? progress : null,
                      color: Colors.indigoAccent,
                      backgroundColor: Colors.white10,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Téléchargement : ${(progress * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(color: Colors.indigoAccent, fontWeight: FontWeight.bold),
                    ),
                  ],
                ],
              ),
              actions: isDownloading
                  ? []
                  : [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('Plus tard', style: TextStyle(color: Colors.white60)),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigoAccent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: startAutoUpgrade,
                        child: const Text('METTRE À JOUR'),
                      ),
                    ],
            );
          },
        );
      },
    );
  }
}