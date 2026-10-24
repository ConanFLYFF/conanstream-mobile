import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:ota_update/ota_update.dart';

class UpdateService {
  // Ton dépôt GitHub
  static const String githubRepo = "ConanFLYFF/conanstream-mobile";

  static Future<void> checkForUpdates(BuildContext context) async {
    try {
      // 1. Récupérer la version actuelle de l'application
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      String currentVersion = packageInfo.version;

      // 2. Vérifier la dernière version sur l'API GitHub
      final response = await http.get(
        Uri.parse('https://api.github.com/repos/$githubRepo/releases/latest'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        String latestVersion = data['tag_name'].toString().replaceAll('v', '');
        
        // Chercher le fichier .apk dans les assets de la Release GitHub
        String? apkUrl;
        if (data['assets'] != null && data['assets'] is List) {
          for (var asset in data['assets']) {
            if (asset['name'].toString().endsWith('.apk')) {
              apkUrl = asset['browser_download_url'];
              break;
            }
          }
        }

        // 3. Si une version plus récente est disponible avec un APK
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
            String downloadProgress = '0%';

            void startDownload() {
              setState(() {
                isDownloading = true;
              });

              try {
                // Télécharge l'APK et lance directement l'installation Android
                OtaUpdate().execute(apkUrl, destinationFilename: 'app-update.apk').listen(
                  (OtaEvent event) {
                    if (event.status == OtaStatus.DOWNLOADING) {
                      setState(() {
                        downloadProgress = '${event.value}%';
                      });
                    } else if (event.status == OtaStatus.INSTALLING) {
                      // Android prend la main pour afficher l'écran d'installation "Mettre à jour"
                      Navigator.of(dialogContext).pop();
                    }
                  },
                  onError: (error) {
                    setState(() {
                      isDownloading = false;
                    });
                  },
                );
              } catch (e) {
                setState(() {
                  isDownloading = false;
                });
              }
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
                    'Une nouvelle version ($version) de ConanStream est disponible.',
                    style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14),
                  ),
                  const SizedBox(height: 20),
                  if (isDownloading) ...[
                    LinearProgressIndicator(color: Colors.indigoAccent, backgroundColor: Colors.white10),
                    const SizedBox(height: 12),
                    Text(
                      'Téléchargement en cours : $downloadProgress',
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
                        onPressed: startDownload,
                        child: const Text('OK / METTRE À JOUR'),
                      ),
                    ],
            );
          },
        );
      },
    );
  }
}