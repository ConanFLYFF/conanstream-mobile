import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'shared_prefs_helper.dart';
import 'login_screen.dart';
import 'glass_card.dart';
import 'device_info_screen.dart';
import '../services/activation_service.dart';

class SettingsScreen extends StatefulWidget {
  final String serverUrl;
  final String username;
  final String password;
  final Map userInfo;
  final VoidCallback onLogout;

  const SettingsScreen({
    super.key,
    required this.serverUrl,
    required this.username,
    required this.password,
    this.userInfo = const {},
    required this.onLogout,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  List<AccountProfile> _savedAccounts = [];
  bool _isLoadingAccounts = true;

  // Licence Application
  bool _isAppActivated = false;
  bool _isAppTrial = true;
  int _appDaysRemaining = 5;
  String _appStatusText = "Chargement...";

  // Données dynamiques du fournisseur
  Map _fetchedUserInfo = {};
  bool _isLoadingUserInfo = true;

  // Préférences utilisateur
  String _selectedAudioLang = 'Français';
  String _selectedSubLang = 'Désactivés';
  bool _autoPauseOnFocus = true;

  final List<String> _audioLanguages = ['Français', 'Anglais', 'Langue originale'];
  final List<String> _subLanguages = ['Désactivés', 'Français', 'Anglais'];

  @override
  void initState() {
    super.initState();
    _fetchedUserInfo = widget.userInfo;
    _loadAccounts();
    _loadPreferences();
    _loadAppLicenseStatus();
    _fetchServerUserInfoIfNeeded();
  }

  Future<void> _fetchServerUserInfoIfNeeded() async {
    Map info = widget.userInfo['user_info'] ?? widget.userInfo;
    if (info.isEmpty && widget.serverUrl.isNotEmpty && widget.username.isNotEmpty) {
      try {
        final url = Uri.parse('${widget.serverUrl}/player_api.php?username=${widget.username}&password=${widget.password}');
        final response = await http.get(url).timeout(const Duration(seconds: 5));
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (mounted && data != null && data['user_info'] != null) {
            setState(() {
              _fetchedUserInfo = data;
              _isLoadingUserInfo = false;
            });
            return;
          }
        }
      } catch (_) {}
    }
    if (mounted) {
      setState(() {
        _isLoadingUserInfo = false;
      });
    }
  }

  Future<void> _loadAppLicenseStatus() async {
    var accessStatus = await ActivationService.checkAccessStatus();
    bool activated = accessStatus['reason'] == 'ACTIVATED';
    bool trial = accessStatus['reason'] == 'IN_TRIAL';
    int daysLeft = accessStatus['days_remaining'] ?? 5;

    if (mounted) {
      setState(() {
        _isAppActivated = activated;
        _isAppTrial = trial;
        _appDaysRemaining = daysLeft;

        if (_isAppActivated) {
          _appStatusText = "ACTIF (Licence à vie)";
        } else if (_isAppTrial) {
          _appStatusText = "ESSAI GRATUIT ($_appDaysRemaining jour(s) restant(s))";
        } else {
          _appStatusText = "INACTIF (Période d'essai expirée)";
        }
      });
    }
  }

  Future<void> _loadAccounts() async {
    final accounts = await SharedPrefsHelper.getAccounts();
    if (mounted) {
      setState(() {
        _savedAccounts = accounts;
        _isLoadingAccounts = false;
      });
    }
  }

  Future<void> _loadPreferences() async {
    final audio = await SharedPrefsHelper.getAudioLanguage();
    final sub = await SharedPrefsHelper.getSubtitleLanguage();
    final autoPause = await SharedPrefsHelper.getAutoPauseOnFocusLoss();
    if (mounted) {
      setState(() {
        _selectedAudioLang = audio;
        _selectedSubLang = sub;
        _autoPauseOnFocus = autoPause;
      });
    }
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null ||
        timestamp.toString() == 'null' ||
        timestamp.toString() == '0' ||
        timestamp.toString().isEmpty ||
        timestamp.toString() == '-1') {
      return 'Illimité';
    }
    try {
      int parsedTimestamp;
      if (timestamp is int) {
        parsedTimestamp = timestamp;
      } else {
        parsedTimestamp = int.parse(timestamp.toString());
      }

      if (parsedTimestamp > 100000000000) {
        parsedTimestamp = (parsedTimestamp / 1000).round();
      }

      final date = DateTime.fromMillisecondsSinceEpoch(parsedTimestamp * 1000);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (_) {
      return timestamp.toString();
    }
  }

  Future<void> _clearAppCache(BuildContext context) async {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Cache vidé avec succès !', style: TextStyle(color: Colors.white)),
        backgroundColor: Color(0xFF00E676),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showAccountsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0C101C),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFF00E5FF), width: 1.5),
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Comptes enregistrés', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            IconButton(
              icon: const Icon(Icons.person_add_rounded, color: Color(0xFF00E5FF)),
              tooltip: 'Ajouter un compte',
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
            ),
          ],
        ),
        content: SizedBox(
          width: 400,
          height: 250,
          child: _isLoadingAccounts
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF)))
              : _savedAccounts.isEmpty
                  ? const Center(child: Text('Aucun autre compte enregistré.', style: TextStyle(color: Colors.white54)))
                  : ListView.builder(
                      itemCount: _savedAccounts.length,
                      itemBuilder: (context, index) {
                        final acc = _savedAccounts[index];
                        final isCurrent = acc.username == widget.username;

                        return ListTile(
                          title: Text(acc.username, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          subtitle: Text(acc.serverUrl, style: const TextStyle(color: Colors.white54, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                          trailing: isCurrent
                              ? const Chip(label: Text('Actif', style: TextStyle(color: Colors.white, fontSize: 11)), backgroundColor: Color(0xFF00E676))
                              : IconButton(
                                  icon: const Icon(Icons.delete_rounded, color: Colors.redAccent),
                                  onPressed: () async {
                                    await SharedPrefsHelper.deleteAccount(acc.username);
                                    _loadAccounts();
                                  },
                                ),
                        );
                      },
                    ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer', style: TextStyle(color: Colors.white60)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Map info = {};
    if (_fetchedUserInfo.containsKey('user_info')) {
      info = _fetchedUserInfo['user_info'] ?? {};
    } else {
      info = _fetchedUserInfo;
    }

    String providerStatus = 'Actif';
    dynamic rawExp = info['exp_date'] ?? info['expiry_date'] ?? info['expiration'] ?? info['valid_until'] ?? info['date_end'];
    String expDate = _formatDate(rawExp);
    dynamic maxConn = info['max_connections'] ?? '1';

    return Scaffold(
      backgroundColor: const Color(0xFF070A14),
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.0, -0.3),
                  radius: 1.4,
                  colors: [
                    Color(0xFF0D2847),
                    Color(0xFF070A14),
                    Color(0xFF020306),
                  ],
                ),
              ),
            ),
          ),
          Column(
            children: [
              AppBar(
                backgroundColor: const Color(0xFF0C101C).withOpacity(0.8),
                elevation: 0,
                title: const Text('Paramètres & Configuration', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // SECTION 1 : LICENCE DE L'APPLICATION
                      const Text(
                        'Licence de l\'Application (ConanStream)',
                        style: TextStyle(color: Color(0xFF00E5FF), fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.1),
                      ),
                      const SizedBox(height: 16),
                      GlassCard(
                        borderColor: const Color(0xFF00E5FF),
                        borderRadius: 16,
                        opacity: 0.08,
                        child: Column(
                          children: [
                            _infoRow(
                              'Statut de l\'application :',
                              _appStatusText,
                              _isAppActivated
                                  ? const Color(0xFF00E676)
                                  : (_isAppTrial ? Colors.amber : Colors.redAccent),
                            ),
                            const Divider(color: Colors.white10, height: 24),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.verified_user_rounded, color: Color(0xFF00E5FF)),
                              title: const Text('Gestion de Licence & Paiement', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              subtitle: const Text('Voir l\'identifiant de l\'appareil et gérer la licence à vie', style: TextStyle(color: Colors.white54, fontSize: 12)),
                              trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF00E5FF)),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const DeviceInfoScreen()),
                                ).then((_) => _loadAppLicenseStatus());
                              },
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // SECTION 2 : ABONNEMENT FOURNISSEUR IPTV
                      const Text(
                        'Abonnement du Fournisseur IPTV',
                        style: TextStyle(color: Colors.amber, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.1),
                      ),
                      const SizedBox(height: 16),
                      GlassCard(
                        borderColor: Colors.amber,
                        borderRadius: 16,
                        opacity: 0.08,
                        child: Column(
                          children: [
                            _infoRow('Compte Fournisseur :', widget.username, Colors.white),
                            const Divider(color: Colors.white10, height: 24),
                            _infoRow('Statut du serveur :', providerStatus, const Color(0xFF00E676)),
                            const Divider(color: Colors.white10, height: 24),
                            _infoRow(
                              'Date d\'expiration (IPTV) :',
                              _isLoadingUserInfo ? 'Chargement...' : expDate,
                              Colors.amber,
                            ),
                            const Divider(color: Colors.white10, height: 24),
                            _infoRow('Connexions simultanées :', maxConn.toString(), Colors.white70),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // SECTION 3 : CONFORT DE LECTURE
                      const Text(
                        'Confort de Lecture',
                        style: TextStyle(color: Color(0xFFD500F9), fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.1),
                      ),
                      const SizedBox(height: 16),
                      GlassCard(
                        borderColor: const Color(0xFFD500F9),
                        borderRadius: 16,
                        opacity: 0.08,
                        child: Column(
                          children: [
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.audiotrack_rounded, color: Color(0xFFD500F9)),
                              title: const Text('Langue audio par défaut', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                              trailing: DropdownButton<String>(
                                value: _selectedAudioLang,
                                dropdownColor: const Color(0xFF0C101C),
                                style: const TextStyle(color: Colors.white),
                                underline: const SizedBox(),
                                items: _audioLanguages.map((lang) {
                                  return DropdownMenuItem(value: lang, child: Text(lang));
                                }).toList(),
                                onChanged: (val) async {
                                  if (val != null) {
                                    setState(() => _selectedAudioLang = val);
                                    await SharedPrefsHelper.setAudioLanguage(val);
                                  }
                                },
                              ),
                            ),
                            const Divider(color: Colors.white10, height: 1),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.subtitles_rounded, color: Color(0xFFD500F9)),
                              title: const Text('Sous-titres par défaut', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                              trailing: DropdownButton<String>(
                                value: _selectedSubLang,
                                dropdownColor: const Color(0xFF0C101C),
                                style: const TextStyle(color: Colors.white),
                                underline: const SizedBox(),
                                items: _subLanguages.map((sub) {
                                  return DropdownMenuItem(value: sub, child: Text(sub));
                                }).toList(),
                                onChanged: (val) async {
                                  if (val != null) {
                                    setState(() => _selectedSubLang = val);
                                    await SharedPrefsHelper.setSubtitleLanguage(val);
                                  }
                                },
                              ),
                            ),
                            const Divider(color: Colors.white10, height: 1),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              secondary: const Icon(Icons.pause_circle_outline_rounded, color: Color(0xFFD500F9)),
                              title: const Text('Pause auto sur perte de focus', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                              subtitle: const Text('Met en pause la lecture si l\'application passe en arrière-plan', style: TextStyle(color: Colors.white54, fontSize: 12)),
                              value: _autoPauseOnFocus,
                              activeColor: const Color(0xFF00E5FF),
                              onChanged: (val) async {
                                setState(() => _autoPauseOnFocus = val);
                                await SharedPrefsHelper.setAutoPauseOnFocusLoss(val);
                              },
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // SECTION 4 : GESTION & MAINTENANCE
                      const Text(
                        'Gestion & Maintenance',
                        style: TextStyle(color: Color(0xFF00E676), fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.1),
                      ),
                      const SizedBox(height: 16),
                      GlassCard(
                        borderColor: const Color(0xFF00E676),
                        borderRadius: 16,
                        opacity: 0.08,
                        child: Column(
                          children: [
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.manage_accounts_rounded, color: Color(0xFF00E676)),
                              title: const Text('Gérer les profils enregistrés', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                              subtitle: const Text('Voir ou supprimer les comptes mémorisés', style: TextStyle(color: Colors.white54, fontSize: 12)),
                              trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white54),
                              onTap: _showAccountsDialog,
                            ),
                            const Divider(color: Colors.white10, height: 1),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.cleaning_services_rounded, color: Color(0xFF00E676)),
                              title: const Text('Vider le cache de l\'application', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                              subtitle: const Text('Effacer les images et affiches en cache', style: TextStyle(color: Colors.white54, fontSize: 12)),
                              trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white54),
                              onTap: () => _clearAppCache(context),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 40),

                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent.withOpacity(0.15),
                            foregroundColor: Colors.redAccent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(color: Colors.redAccent, width: 1.2),
                            ),
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                          label: const Text(
                            'SE DÉCONNECTER',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 1.1),
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            widget.onLogout();
                          },
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Center(
                        child: Text(
                          'ConanStream • v1.0.0 (Android)',
                          style: TextStyle(color: Colors.white38, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 15)),
        Text(value, style: TextStyle(color: valueColor, fontSize: 15, fontWeight: FontWeight.bold)),
      ],
    );
  }
}