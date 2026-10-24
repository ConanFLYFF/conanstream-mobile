import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';
import 'shared_prefs_helper.dart';
import 'package:file_picker/file_picker.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Contrôleurs pour Xtream API
  final _xtreamFormKey = GlobalKey<FormState>();
  final TextEditingController _xtreamProfileNameController = TextEditingController(); // 👈 Nouveau champ nom de profil
  final TextEditingController _xtreamUrlController = TextEditingController();
  final TextEditingController _xtreamUsernameController = TextEditingController();
  final TextEditingController _xtreamPasswordController = TextEditingController();

  // Contrôleurs pour Lien M3U
  final _m3uFormKey = GlobalKey<FormState>();
  final TextEditingController _m3uNameController = TextEditingController();
  final TextEditingController _m3uUrlController = TextEditingController();

  // Contrôleurs pour Portail MAC
  final _macFormKey = GlobalKey<FormState>();
  final TextEditingController _macNameController = TextEditingController();
  final TextEditingController _macPortalUrlController = TextEditingController();
  final TextEditingController _macAddressController = TextEditingController();

  // Contrôleurs pour Fichier Local M3U
  final _fileFormKey = GlobalKey<FormState>();
  final TextEditingController _fileNameController = TextEditingController();
  String? _selectedFilePath;

  // Contrôleurs pour Code d'Activation
  final _codeFormKey = GlobalKey<FormState>();
  final TextEditingController _activationCodeController = TextEditingController();

  bool _isLoading = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadSavedTabInputs();
  }

  Future<void> _loadSavedTabInputs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      // Xtream
      _xtreamProfileNameController.text = prefs.getString('saved_input_xtream_profile_name') ?? '';
      _xtreamUrlController.text = prefs.getString('saved_input_xtream_url') ?? 'http://smartprotv.org';
      _xtreamUsernameController.text = prefs.getString('saved_input_xtream_user') ?? '';
      _xtreamPasswordController.text = prefs.getString('saved_input_xtream_pass') ?? '';

      // M3U
      _m3uNameController.text = prefs.getString('saved_input_m3u_name') ?? '';
      _m3uUrlController.text = prefs.getString('saved_input_m3u_url') ?? '';

      // MAC
      _macNameController.text = prefs.getString('saved_input_mac_name') ?? '';
      _macPortalUrlController.text = prefs.getString('saved_input_mac_url') ?? '';
      _macAddressController.text = prefs.getString('saved_input_mac_address') ?? '';

      // Fichier Local
      _fileNameController.text = prefs.getString('saved_input_file_name') ?? '';
      _selectedFilePath = prefs.getString('saved_input_file_path');

      // Code Activation
      _activationCodeController.text = prefs.getString('saved_input_code') ?? '';
    });
  }

  Future<void> _saveTabInputs(String tab) async {
    final prefs = await SharedPreferences.getInstance();
    if (tab == 'xtream') {
      await prefs.setString('saved_input_xtream_profile_name', _xtreamProfileNameController.text.trim());
      await prefs.setString('saved_input_xtream_url', _xtreamUrlController.text.trim());
      await prefs.setString('saved_input_xtream_user', _xtreamUsernameController.text.trim());
      await prefs.setString('saved_input_xtream_pass', _xtreamPasswordController.text.trim());
    } else if (tab == 'm3u') {
      await prefs.setString('saved_input_m3u_name', _m3uNameController.text.trim());
      await prefs.setString('saved_input_m3u_url', _m3uUrlController.text.trim());
    } else if (tab == 'mac') {
      await prefs.setString('saved_input_mac_name', _macNameController.text.trim());
      await prefs.setString('saved_input_mac_url', _macPortalUrlController.text.trim());
      await prefs.setString('saved_input_mac_address', _macAddressController.text.trim());
    } else if (tab == 'file') {
      await prefs.setString('saved_input_file_name', _fileNameController.text.trim());
      if (_selectedFilePath != null) {
        await prefs.setString('saved_input_file_path', _selectedFilePath!);
      }
    } else if (tab == 'code') {
      await prefs.setString('saved_input_code', _activationCodeController.text.trim());
    }
  }

  Future<void> _handleXtreamLogin() async {
    if (!_xtreamFormKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    await _saveTabInputs('xtream');

    String serverUrl = _xtreamUrlController.text.trim();
    if (serverUrl.endsWith('/')) {
      serverUrl = serverUrl.substring(0, serverUrl.length - 1);
    }

    final username = _xtreamUsernameController.text.trim();
    final password = _xtreamPasswordController.text.trim();
    final customProfileName = _xtreamProfileNameController.text.trim();

    HttpClient? client;
    try {
      client = HttpClient();
      client.badCertificateCallback = (X509Certificate cert, String host, int port) => true;
      client.connectionTimeout = const Duration(seconds: 15);

      final authUri = Uri.parse('$serverUrl/player_api.php?username=$username&password=$password');
      final request = await client.getUrl(authUri);
      
      request.headers.set('User-Agent', 'IPTVSmarterPro/3.1.5 (Linux; Android 12)');
      request.headers.set('Accept', '*/*');
      
      final response = await request.close().timeout(const Duration(seconds: 15));
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode == 200) {
        final data = json.decode(responseBody);
        
        if (data is Map && data['user_info'] != null) {
          final userInfo = data['user_info'];
          if (userInfo['auth'] == 1 || userInfo['status'] == 'Active') {
            
            // 💡 Si un nom personnalisé est renseigné, on l'injecte dans le profil sauvegardé
            final effectiveUsername = customProfileName.isNotEmpty ? customProfileName : username;
            
            final profile = AccountProfile(
              serverUrl: serverUrl,
              username: effectiveUsername,
              password: password,
              userInfo: userInfo,
            );
            await SharedPrefsHelper.saveAccount(profile);
            await SharedPrefsHelper.setActiveAccount(profile);

            if (!mounted) return;

            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => HomeScreen(
                  serverUrl: serverUrl,
                  username: effectiveUsername,
                  password: password,
                ),
              ),
            );
            return;
          } else {
            setState(() {
              _errorMessage = 'Compte désactivé ou expiré.';
            });
          }
        } else {
          setState(() {
            _errorMessage = 'Réponse invalide du serveur Xtream.';
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Erreur serveur HTTP : ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur de connexion : $e';
      });
    } finally {
      client?.close();
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleM3uLogin() async {
    if (!_m3uFormKey.currentState!.validate()) return;
    setState(() { _isLoading = true; _errorMessage = ''; });
    await _saveTabInputs('m3u');
    final playlistName = _m3uNameController.text.trim();
    final m3uUrl = _m3uUrlController.text.trim();

    try {
      final profile = AccountProfile(
        serverUrl: m3uUrl,
        username: playlistName.isNotEmpty ? playlistName : 'Playlist M3U',
        password: '',
        userInfo: {'auth': 1, 'status': 'Active', 'username': playlistName},
      );
      await SharedPrefsHelper.saveAccount(profile);
      await SharedPrefsHelper.setActiveAccount(profile);

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => HomeScreen(serverUrl: m3uUrl, username: playlistName, password: ''),
        ),
      );
    } catch (e) {
      setState(() { _errorMessage = 'Erreur lors du traitement du lien M3U : $e'; });
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  Future<void> _handleMacLogin() async {
    if (!_macFormKey.currentState!.validate()) return;
    setState(() { _isLoading = true; _errorMessage = ''; });
    await _saveTabInputs('mac');
    final portalName = _macNameController.text.trim();
    final portalUrl = _macPortalUrlController.text.trim();
    final macAddress = _macAddressController.text.trim();

    try {
      final profile = AccountProfile(
        serverUrl: portalUrl,
        username: portalName.isNotEmpty ? portalName : 'Portail MAC',
        password: macAddress,
        userInfo: {'auth': 1, 'status': 'Active', 'username': portalName},
      );
      await SharedPrefsHelper.saveAccount(profile);
      await SharedPrefsHelper.setActiveAccount(profile);

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => HomeScreen(serverUrl: portalUrl, username: portalName, password: macAddress),
        ),
      );
    } catch (e) {
      setState(() { _errorMessage = 'Erreur de connexion au portail MAC : $e'; });
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  Future<void> _pickLocalFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['m3u', 'm3u8', 'txt'],
      );
      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedFilePath = result.files.single.path;
          if (_fileNameController.text.isEmpty) {
            _fileNameController.text = result.files.single.name;
          }
        });
        await _saveTabInputs('file');
      }
    } catch (e) {
      setState(() { _errorMessage = 'Erreur lors de la sélection du fichier : $e'; });
    }
  }

  Future<void> _handleFileLogin() async {
    if (!_fileFormKey.currentState!.validate() || _selectedFilePath == null) {
      setState(() { _errorMessage = 'Veuillez sélectionner un fichier .m3u valide'; });
      return;
    }
    setState(() { _isLoading = true; _errorMessage = ''; });
    await _saveTabInputs('file');
    final playlistName = _fileNameController.text.trim();

    try {
      final profile = AccountProfile(
        serverUrl: _selectedFilePath!,
        username: playlistName.isNotEmpty ? playlistName : 'Fichier Local',
        password: '',
        userInfo: {'auth': 1, 'status': 'Active', 'username': playlistName},
      );
      await SharedPrefsHelper.saveAccount(profile);
      await SharedPrefsHelper.setActiveAccount(profile);

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => HomeScreen(serverUrl: _selectedFilePath!, username: playlistName, password: ''),
        ),
      );
    } catch (e) {
      setState(() { _errorMessage = 'Erreur lors du chargement du fichier : $e'; });
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  Future<void> _handleCodeLogin() async {
    if (!_codeFormKey.currentState!.validate()) return;
    setState(() { _isLoading = true; _errorMessage = ''; });
    await _saveTabInputs('code');
    final code = _activationCodeController.text.trim();

    try {
      final profile = AccountProfile(
        serverUrl: 'http://code-activation-server.com/$code',
        username: 'Code: $code',
        password: '',
        userInfo: {'auth': 1, 'status': 'Active', 'username': 'Code: $code'},
      );
      await SharedPrefsHelper.saveAccount(profile);
      await SharedPrefsHelper.setActiveAccount(profile);

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => HomeScreen(serverUrl: 'http://code-activation-server.com/$code', username: 'Code: $code', password: ''),
        ),
      );
    } catch (e) {
      setState(() { _errorMessage = 'Code d\'activation invalide ou expiré : $e'; });
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _xtreamProfileNameController.dispose();
    _xtreamUrlController.dispose();
    _xtreamUsernameController.dispose();
    _xtreamPasswordController.dispose();
    _m3uNameController.dispose();
    _m3uUrlController.dispose();
    _macNameController.dispose();
    _macPortalUrlController.dispose();
    _macAddressController.dispose();
    _fileNameController.dispose();
    _activationCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.2,
            colors: [
              Color(0xFF1A2342),
              Color(0xFF090D1A),
              Color(0xFF05070E),
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Container(
              width: 520,
              padding: const EdgeInsets.all(28.0),
              decoration: BoxDecoration(
                color: const Color(0xFF0C101C).withOpacity(0.9),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.indigoAccent.withOpacity(0.2),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.indigoAccent.withOpacity(0.5)),
                    ),
                    child: const Icon(Icons.tv_rounded, color: Colors.indigoAccent, size: 42),
                  ),
                  const SizedBox(height: 16),
                  RichText(
                    text: const TextSpan(
                      children: [
                        TextSpan(text: 'IPTV ', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                        TextSpan(text: 'PRO MAX', style: TextStyle(color: Colors.indigoAccent, fontSize: 22, fontWeight: FontWeight.w900)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Sélectionnez votre méthode de connexion',
                    style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                  ),
                  const SizedBox(height: 16),

                  Container(
                    height: 45,
                    decoration: BoxDecoration(
                      color: const Color(0xFF13192B),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      indicator: BoxDecoration(
                        color: Colors.indigoAccent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.white60,
                      labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      tabs: const [
                        Tab(text: '  Xtream  '),
                        Tab(text: '  Lien M3U  '),
                        Tab(text: '  Portail MAC  '),
                        Tab(text: '  Fichier Local  '),
                        Tab(text: '  Code Act.  '),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  if (_errorMessage.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
                      ),
                      child: Text(
                        _errorMessage,
                        style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ),

                  SizedBox(
                    height: 380, // Agrandit légèrement pour faire place au nouveau champ
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        // ONGLET 1 : XTREAM CODES
                        Form(
                          key: _xtreamFormKey,
                          child: Column(
                            children: [
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _xtreamProfileNameController,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  labelText: 'Nom du profil (Optionnel, ex: Salon)',
                                  labelStyle: const TextStyle(color: Colors.white60),
                                  prefixIcon: const Icon(Icons.badge_rounded, color: Colors.indigoAccent),
                                  filled: true,
                                  fillColor: const Color(0xFF13192B),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.indigoAccent)),
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextFormField(
                                controller: _xtreamUrlController,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  labelText: 'URL du Serveur',
                                  labelStyle: const TextStyle(color: Colors.white60),
                                  prefixIcon: const Icon(Icons.link, color: Colors.indigoAccent),
                                  filled: true,
                                  fillColor: const Color(0xFF13192B),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.indigoAccent)),
                                ),
                                validator: (value) => value == null || value.isEmpty ? 'Entrez l\'URL' : null,
                              ),
                              const SizedBox(height: 10),
                              TextFormField(
                                controller: _xtreamUsernameController,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  labelText: 'Nom d\'utilisateur',
                                  labelStyle: const TextStyle(color: Colors.white60),
                                  prefixIcon: const Icon(Icons.person_rounded, color: Colors.indigoAccent),
                                  filled: true,
                                  fillColor: const Color(0xFF13192B),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.indigoAccent)),
                                ),
                                validator: (value) => value == null || value.isEmpty ? 'Entrez l\'utilisateur' : null,
                              ),
                              const SizedBox(height: 10),
                              TextFormField(
                                controller: _xtreamPasswordController,
                                obscureText: true,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  labelText: 'Mot de passe',
                                  labelStyle: const TextStyle(color: Colors.white60),
                                  prefixIcon: const Icon(Icons.lock_rounded, color: Colors.indigoAccent),
                                  filled: true,
                                  fillColor: const Color(0xFF13192B),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.indigoAccent)),
                                ),
                                validator: (value) => value == null || value.isEmpty ? 'Entrez le mot de passe' : null,
                              ),
                              const Spacer(),
                              SizedBox(
                                width: double.infinity,
                                height: 46,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.indigoAccent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                                  onPressed: _isLoading ? null : _handleXtreamLogin,
                                  child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('CONNEXION XTREAM', style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // ONGLET 2 : LIEN M3U
                        Form(
                          key: _m3uFormKey,
                          child: Column(
                            children: [
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _m3uNameController,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  labelText: 'Nom de la playlist',
                                  labelStyle: const TextStyle(color: Colors.white60),
                                  prefixIcon: const Icon(Icons.playlist_play, color: Colors.indigoAccent),
                                  filled: true,
                                  fillColor: const Color(0xFF13192B),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.indigoAccent)),
                                ),
                                validator: (value) => value == null || value.isEmpty ? 'Entrez un nom' : null,
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _m3uUrlController,
                                style: const TextStyle(color: Colors.white),
                                maxLines: 3,
                                decoration: InputDecoration(
                                  labelText: 'URL du lien M3U (http://...)',
                                  labelStyle: const TextStyle(color: Colors.white60),
                                  prefixIcon: const Icon(Icons.link, color: Colors.indigoAccent),
                                  filled: true,
                                  fillColor: const Color(0xFF13192B),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.indigoAccent)),
                                ),
                                validator: (value) => value == null || value.isEmpty ? 'Entrez l\'URL M3U' : null,
                              ),
                              const Spacer(),
                              SizedBox(
                                width: double.infinity,
                                height: 46,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.indigoAccent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                                  onPressed: _isLoading ? null : _handleM3uLogin,
                                  child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('CHARGER M3U', style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // ONGLET 3 : PORTAIL MAC
                        Form(
                          key: _macFormKey,
                          child: Column(
                            children: [
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _macNameController,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  labelText: 'Nom de la connexion',
                                  labelStyle: const TextStyle(color: Colors.white60),
                                  prefixIcon: const Icon(Icons.tv, color: Colors.indigoAccent),
                                  filled: true,
                                  fillColor: const Color(0xFF13192B),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.indigoAccent)),
                                ),
                                validator: (value) => value == null || value.isEmpty ? 'Entrez un nom' : null,
                              ),
                              const SizedBox(height: 10),
                              TextFormField(
                                controller: _macPortalUrlController,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  labelText: 'URL du Portail (ex: http://.../c/)',
                                  labelStyle: const TextStyle(color: Colors.white60),
                                  prefixIcon: const Icon(Icons.router, color: Colors.indigoAccent),
                                  filled: true,
                                  fillColor: const Color(0xFF13192B),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.indigoAccent)),
                                ),
                                validator: (value) => value == null || value.isEmpty ? 'Entrez l\'URL' : null,
                              ),
                              const SizedBox(height: 10),
                              TextFormField(
                                controller: _macAddressController,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  labelText: 'Adresse MAC (00:1A:79:...)',
                                  labelStyle: const TextStyle(color: Colors.white60),
                                  prefixIcon: const Icon(Icons.settings_ethernet, color: Colors.indigoAccent),
                                  filled: true,
                                  fillColor: const Color(0xFF13192B),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.indigoAccent)),
                                ),
                                validator: (value) => value == null || value.isEmpty ? 'Entrez l\'adresse MAC' : null,
                              ),
                              const Spacer(),
                              SizedBox(
                                width: double.infinity,
                                height: 46,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.indigoAccent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                                  onPressed: _isLoading ? null : _handleMacLogin,
                                  child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('CONNEXION PORTAIL MAC', style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // ONGLET 4 : FICHIER LOCAL
                        Form(
                          key: _fileFormKey,
                          child: Column(
                            children: [
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _fileNameController,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  labelText: 'Nom de la playlist locale',
                                  labelStyle: const TextStyle(color: Colors.white60),
                                  prefixIcon: const Icon(Icons.folder, color: Colors.indigoAccent),
                                  filled: true,
                                  fillColor: const Color(0xFF13192B),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.indigoAccent)),
                                ),
                                validator: (value) => value == null || value.isEmpty ? 'Entrez un nom' : null,
                              ),
                              const SizedBox(height: 20),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF13192B),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white10),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.insert_drive_file, color: Colors.indigoAccent),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        _selectedFilePath ?? 'Aucun fichier sélectionné',
                                        style: TextStyle(color: _selectedFilePath != null ? Colors.white : Colors.white60, fontSize: 13),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.indigoAccent.withOpacity(0.3), foregroundColor: Colors.white),
                                      onPressed: _pickLocalFile,
                                      child: const Text('Parcourir'),
                                    ),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              SizedBox(
                                width: double.infinity,
                                height: 46,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.indigoAccent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                                  onPressed: _isLoading ? null : _handleFileLogin,
                                  child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('CHARGER LE FICHIER', style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // ONGLET 5 : CODE D'ACTIVATION
                        Form(
                          key: _codeFormKey,
                          child: Column(
                            children: [
                              const SizedBox(height: 12),
                              Text(
                                'Entrez le code d\'activation fourni par votre service',
                                style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 20),
                              TextFormField(
                                controller: _activationCodeController,
                                style: const TextStyle(color: Colors.white, fontSize: 18, letterSpacing: 2),
                                textAlign: TextAlign.center,
                                decoration: InputDecoration(
                                  labelText: 'Code à 6 chiffres',
                                  labelStyle: const TextStyle(color: Colors.white60),
                                  filled: true,
                                  fillColor: const Color(0xFF13192B),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.indigoAccent)),
                                ),
                                validator: (value) => value == null || value.isEmpty ? 'Entrez le code d\'activation' : null,
                              ),
                              const Spacer(),
                              SizedBox(
                                width: double.infinity,
                                height: 46,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.indigoAccent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                                  onPressed: _isLoading ? null : _handleCodeLogin,
                                  child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('ACTIVER & SE CONNECTER', style: TextStyle(fontWeight: FontWeight.bold)),
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
        ),
      ),
    );
  }
}