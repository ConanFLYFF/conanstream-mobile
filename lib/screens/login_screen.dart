import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'home_screen.dart';
import 'shared_prefs_helper.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadLastAccount();
  }

  Future<void> _loadLastAccount() async {
    final accounts = await SharedPrefsHelper.getAccounts();
    if (accounts.isNotEmpty) {
      final lastAcc = accounts.last;
      setState(() {
        _urlController.text = lastAcc.serverUrl;
        _usernameController.text = lastAcc.username;
        _passwordController.text = lastAcc.password;
      });
    }
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    String serverUrl = _urlController.text.trim();
    if (serverUrl.endsWith('/')) {
      serverUrl = serverUrl.substring(0, serverUrl.length - 1);
    }

    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    try {
      final uri = Uri.parse(serverUrl);
      final host = uri.host;
      
      String targetUrl = serverUrl;
      Map<String, String> headers = {};

      // Contournement total sans DNS : on tape directement sur l'IP 1.1.1.1 de Cloudflare
      try {
        final dohRes = await http.get(
          Uri.parse('https://1.1.1.1/dns-query?name=$host&type=A'),
          headers: {
            'Accept': 'application/dns-json',
            'Host': 'cloudflare-dns.com',
          },
        ).timeout(const Duration(seconds: 5));

        if (dohRes.statusCode == 200) {
          final dohData = json.decode(dohRes.body);
          final answers = dohData['Answer'];
          if (answers != null && answers is List && answers.isNotEmpty) {
            final ip = answers.first['data'];
            targetUrl = serverUrl.replaceFirst(host, ip);
            headers['Host'] = host; // Indispensable pour que le serveur IPTV accepte la requête par IP
          }
        }
      } catch (_) {
        // En cas d'échec, on essaie de garder l'URL d'origine
      }

      final authUrl = Uri.parse('$targetUrl/player_api.php?username=$username&password=$password');
      final response = await http.get(authUrl, headers: headers).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data is Map && data['user_info'] != null) {
          final userInfo = data['user_info'];
          if (userInfo['auth'] == 1 || userInfo['status'] == 'Active') {
            
            final profile = AccountProfile(
              serverUrl: serverUrl,
              username: username,
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
                  username: username,
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
            _errorMessage = 'Identifiants invalides ou réponse du serveur incorrecte.';
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Erreur de connexion au serveur (Code ${response.statusCode}).';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur technique: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
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
              width: 450,
              padding: const EdgeInsets.all(32.0),
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
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.indigoAccent.withOpacity(0.2),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.indigoAccent.withOpacity(0.5)),
                      ),
                      child: const Icon(Icons.tv_rounded, color: Colors.indigoAccent, size: 48),
                    ),
                    const SizedBox(height: 20),
                    RichText(
                      text: const TextSpan(
                        children: [
                          TextSpan(text: 'IPTV ', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                          TextSpan(text: 'PRO MAX', style: TextStyle(color: Colors.indigoAccent, fontSize: 24, fontWeight: FontWeight.w900)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Connectez-vous à votre abonnement Xtream',
                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
                    ),
                    const SizedBox(height: 30),

                    if (_errorMessage.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
                        ),
                        child: Text(
                          _errorMessage,
                          style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                      ),

                    // Champ URL du serveur
                    TextFormField(
                      controller: _urlController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'URL du Serveur (ex: http://provider.com:80)',
                        labelStyle: const TextStyle(color: Colors.white60),
                        prefixIcon: const Icon(Icons.link, color: Colors.indigoAccent),
                        filled: true,
                        fillColor: const Color(0xFF13192B),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.indigoAccent)),
                      ),
                      validator: (value) => value == null || value.isEmpty ? 'Veuillez entrer l\'URL du serveur' : null,
                    ),
                    const SizedBox(height: 16),

                    // Champ Nom d'utilisateur
                    TextFormField(
                      controller: _usernameController,
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
                      validator: (value) => value == null || value.isEmpty ? 'Veuillez entrer votre nom d\'utilisateur' : null,
                    ),
                    const SizedBox(height: 16),

                    // Champ Mot de passe
                    TextFormField(
                      controller: _passwordController,
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
                      validator: (value) => value == null || value.isEmpty ? 'Veuillez entrer votre mot de passe' : null,
                    ),
                    const SizedBox(height: 30),

                    // Bouton de connexion
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigoAccent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 5,
                          shadowColor: Colors.indigoAccent.withOpacity(0.5),
                        ),
                        onPressed: _isLoading ? null : _handleLogin,
                        child: _isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                              )
                            : const Text(
                                'CONNEXION',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}