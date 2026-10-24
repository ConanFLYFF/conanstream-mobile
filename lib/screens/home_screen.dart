import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'glass_card.dart';
import 'live_channels_screen.dart';
import 'movies_screen.dart';
import 'series_screen.dart';
import 'favorites_screen.dart';
import 'in_progress_screen.dart';
import 'settings_screen.dart';
import 'login_screen.dart';
import '../services/update_service.dart'; // 👈 Import du service de mise à jour

class HomeScreen extends StatefulWidget {
  final String serverUrl;
  final String username;
  final String password;

  const HomeScreen({
    super.key,
    required this.serverUrl,
    required this.username,
    required this.password,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _currentTime = '';
  String _currentDate = '';
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) => _updateTime());

    // 🚀 Vérifie automatiquement les mises à jour GitHub 3 secondes après l'ouverture
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        UpdateService.checkForUpdates(context);
      }
    });
  }

  void _updateTime() {
    final now = DateTime.now();
    if (mounted) {
      setState(() {
        _currentTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
        const months = ['JAN', 'FÉV', 'MAR', 'AVR', 'MAI', 'JUIN', 'JUIL', 'AOÛT', 'SEP', 'OCT', 'NOV', 'DÉC'];
        _currentDate = '${now.day} ${months[now.month - 1]} ${now.year}';
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SettingsScreen(
          serverUrl: widget.serverUrl,
          username: widget.username,
          password: widget.password,
          userInfo: const {},
          onLogout: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
              (route) => false,
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF030509),
      body: Column(
        children: [
          // --- Barre de titre sur mesure 100% stable (Windows Desktop) ---
          if (!kIsWeb && Platform.isWindows)
            Container(
              height: 34,
              color: const Color(0xFF030509),
              child: Row(
                children: [
                  Expanded(
                    child: DragToMoveArea(
                      child: Container(
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.only(left: 16),
                        child: const Text(
                          "ConanStream",
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Bouton Réduire
                  IconButton(
                    icon: const Icon(Icons.remove, size: 16, color: Colors.white70),
                    onPressed: () => windowManager.minimize(),
                    splashRadius: 15,
                  ),
                  // Bouton Agrandir / Restaurer
                  IconButton(
                    icon: const Icon(Icons.crop_square, size: 14, color: Colors.white70),
                    onPressed: () async {
                      if (await windowManager.isMaximized()) {
                        windowManager.unmaximize();
                      } else {
                        windowManager.maximize();
                      }
                    },
                    splashRadius: 15,
                  ),
                  // Bouton Fermer
                  IconButton(
                    icon: const Icon(Icons.close, size: 16, color: Colors.white70),
                    onPressed: () => windowManager.close(),
                    splashRadius: 15,
                    hoverColor: Colors.red,
                  ),
                ],
              ),
            ),

          // --- Contenu principal de l'application ---
          Expanded(
            child: Stack(
              children: [
                // Halos lumineux d'ambiance
                Positioned(
                  top: -100,
                  left: -100,
                  child: Container(
                    width: 500,
                    height: 500,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF00E5FF).withOpacity(0.05),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -100,
                  right: -100,
                  child: Container(
                    width: 500,
                    height: 500,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFD500F9).withOpacity(0.05),
                    ),
                  ),
                ),

                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 20.0),
                    child: Column(
                      children: [
                        // --- En-tête ---
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Text(
                                  _currentTime,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  width: 4,
                                  height: 4,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF00E5FF),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  _currentDate,
                                  style: const TextStyle(
                                    color: Colors.white60,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                            
                            Container(
                              height: 52,
                              decoration: BoxDecoration(
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFD500F9).withOpacity(0.35),
                                    blurRadius: 15,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: Image.asset(
                                'assets/logo.png',
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Icon(Icons.broken_image_rounded, color: Colors.redAccent, size: 28);
                                },
                              ),
                            ),

                            // Bloc du profil cliquable menant aux paramètres
                            InkWell(
                              onTap: _openSettings,
                              borderRadius: BorderRadius.circular(24),
                              child: GlassCard(
                                borderColor: Colors.white24,
                                borderRadius: 24,
                                opacity: 0.04,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.account_circle_rounded, color: Color(0xFF00E5FF), size: 20),
                                    const SizedBox(width: 10),
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(maxWidth: 180),
                                      child: Text(
                                        () {
                                          try {
                                            if (widget.username.startsWith('{')) {
                                              final data = jsonDecode(widget.username);
                                              return data['name'] ?? data['username'] ?? data['id'] ?? widget.username;
                                            }
                                          } catch (_) {}
                                          return widget.username;
                                        }(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w500,
                                          fontSize: 13,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // --- Grille Principale ---
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Colonne Gauche : Films & Séries
                              Expanded(
                                flex: 3,
                                child: Column(
                                  children: [
                                    Expanded(
                                      child: GlassCard(
                                        borderColor: const Color(0xFF00E5FF),
                                        borderRadius: 16,
                                        opacity: 0.05,
                                        onTap: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => MoviesScreen(
                                              serverUrl: widget.serverUrl,
                                              username: widget.username,
                                              password: widget.password,
                                            ),
                                          ),
                                        ),
                                        child: const Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.movie_creation_outlined, size: 32, color: Color(0xFF00E5FF)),
                                            SizedBox(width: 14),
                                            Text(
                                              'FILMS (VOD)',
                                              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Expanded(
                                      child: GlassCard(
                                        borderColor: const Color(0xFFD500F9),
                                        borderRadius: 16,
                                        opacity: 0.05,
                                        onTap: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => SeriesScreen(
                                              serverUrl: widget.serverUrl,
                                              username: widget.username,
                                              password: widget.password,
                                            ),
                                          ),
                                        ),
                                        child: const Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.video_library_outlined, size: 32, color: Color(0xFFD500F9)),
                                            SizedBox(width: 14),
                                            Text(
                                              'SÉRIES',
                                              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(width: 16),

                              // Colonne Centrale : Télévision en direct
                              Expanded(
                                flex: 4,
                                child: GlassCard(
                                  borderColor: const Color(0xFF00E5FF),
                                  borderRadius: 20,
                                  opacity: 0.07,
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => LiveChannelsScreen(
                                        serverUrl: widget.serverUrl,
                                        username: widget.username,
                                        password: widget.password,
                                      ),
                                    ),
                                  ),
                                  child: const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.live_tv_rounded, size: 68, color: Color(0xFF00E5FF)),
                                      SizedBox(height: 18),
                                      Text(
                                        'TÉLÉVISION EN DIRECT',
                                        style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                                        textAlign: TextAlign.center,
                                      ),
                                      SizedBox(height: 6),
                                      Text(
                                        'Chaînes Live & Guide EPG',
                                        style: TextStyle(color: Colors.white54, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              const SizedBox(width: 16),

                              // Colonne Droite : En cours, Favoris & Paramètres
                              Expanded(
                                flex: 3,
                                child: Column(
                                  children: [
                                    Expanded(
                                      child: GlassCard(
                                        borderColor: const Color(0xFFFF007F),
                                        borderRadius: 16,
                                        opacity: 0.05,
                                        onTap: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => InProgressScreen(
                                              serverUrl: widget.serverUrl,
                                              username: widget.username,
                                              password: widget.password,
                                            ),
                                          ),
                                        ),
                                        child: const Row(
                                          children: [
                                            SizedBox(width: 6),
                                            Icon(Icons.history_rounded, size: 30, color: Color(0xFFFF007F)),
                                            SizedBox(width: 12),
                                            Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text('EN COURS', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                                                SizedBox(height: 2),
                                                Text('Reprise rapide', style: TextStyle(color: Colors.white54, fontSize: 11)),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Expanded(
                                      child: GlassCard(
                                        borderColor: const Color(0xFFFF3D00),
                                        borderRadius: 16,
                                        opacity: 0.05,
                                        onTap: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => FavoritesScreen(
                                              serverUrl: widget.serverUrl,
                                              username: widget.username,
                                              password: widget.password,
                                            ),
                                          ),
                                        ),
                                        child: const Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.favorite_rounded, size: 28, color: Color(0xFFFF3D00)),
                                            SizedBox(width: 12),
                                            Text(
                                              'FAVORIS',
                                              style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Expanded(
                                      child: GlassCard(
                                        borderColor: Colors.white38,
                                        borderRadius: 16,
                                        opacity: 0.05,
                                        onTap: _openSettings,
                                        child: const Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.settings_outlined, size: 26, color: Colors.white70),
                                            SizedBox(width: 12),
                                            Text(
                                              'PARAMÈTRES',
                                              style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}