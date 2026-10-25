Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
$ErrorActionPreference = "Stop"

Write-Host "Création des dossiers et écriture des fichiers de code..." -ForegroundColor Green

# 1. Création des dossiers
$dossiers = @("android", "ios", "assets", "lib", "lib\screens")
foreach ($d in$dossiers) {
    if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path$d | Out-Null }
}

# 2. pubspec.yaml
@'
name: iptv_pro_max
description: Application Flutter professionnelle pour la lecture de flux IPTV.
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.6
  http: ^1.2.0
  video_player: ^2.8.2
  chewie: ^1.7.5
  shared_preferences: ^2.2.2

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0

flutter:
  uses-material-design: true
  assets:
    - assets/logo.png
'@ | Out-File -FilePath "pubspec.yaml" -Encoding utf8

Write-Host "[OK] pubspec.yaml généré" -ForegroundColor Yellow

# 3. lib/main.dart
@'
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/login_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  
  runApp(const IPTVApp());
}

class IPTVApp extends StatelessWidget {
  const IPTVApp({Super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IPTV Pro Max',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFF121212),
        cardColor: const Color(0xFF1E1E1E),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1F1F1F),
          elevation: 0,
        ),
      ),
      home: const LoginScreen(),
    );
  }
}
'@ | Out-File -FilePath "lib\main.dart" -Encoding utf8

Write-Host "[OK] lib/main.dart généré" -ForegroundColor Yellow

# 4. lib/screens/login_screen.dart
@'
import 'package:flutter/material.dart';
import 'dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _serverController = TextEditingController(text: 'http://xtream-server.com:8080');
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  void _login() {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });
      Future.delayed(const Duration(seconds: 2), () {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
        });
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => DashboardScreen(
              serverUrl: _serverController.text,
              username: _usernameController.text,
              password: _passwordController.text,
            ),
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.tv_rounded, size: 80, color: Colors.blue),
                  const SizedBox(height: 16),
                  const Text(
                    'IPTV PRO MAX',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _serverController,
                    decoration: const InputDecoration(
                      labelText: 'URL Serveur',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.dns),
                    ),
                    validator: (val) => val!.isEmpty ? 'Veuillez saisir l\'URL du serveur' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _usernameController,
                    decoration: const InputDecoration(
                      labelText: 'Nom d\'utilisateur',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                    validator: (val) => val!.isEmpty ? 'Veuillez saisir un utilisateur' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Mot de passe',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock),
                    ),
                    validator: (val) => val!.isEmpty ? 'Veuillez saisir un mot de passe' : null,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('CONNEXION', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
'@ | Out-File -FilePath "lib\screens\login_screen.dart" -Encoding utf8

Write-Host "[OK] lib/screens/login_screen.dart généré" -ForegroundColor Yellow

# 5. lib/screens/dashboard_screen.dart
@'
import 'package:flutter/material.dart';
import 'live_channels_screen.dart';

class DashboardScreen extends StatelessWidget {
  final String serverUrl;
  final String username;
  final String password;

  const DashboardScreen({
    Super.key,
    required this.serverUrl,
    required this.username,
    required this.password,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('IPTV Pro Max - Accueil'),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle),
            onPressed: () {},
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.count(
          crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 1,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: [
            _buildCategoryCard(
              context,
              title: 'CHAÎNES EN DIRECT',
              icon: Icons.live_tv,
              color: Colors.redAccent,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => LiveChannelsScreen(
                      serverUrl: serverUrl,
                      username: username,
                      password: password,
                    ),
                  ),
                );
              },
            ),
            _buildCategoryCard(
              context,
              title: 'FILMS (VOD)',
              icon: Icons.movie_outlined,
              color: Colors.blueAccent,
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Section VOD bientôt disponible.')),
                );
              },
            ),
            _buildCategoryCard(
              context,
              title: 'SÉRIES',
              icon: Icons.tv_off_sharp,
              color: Colors.greenAccent,
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Section Séries bientôt disponible.')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCard(BuildContext context, {required String title, required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.5), width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: color),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
'@ | Out-File -FilePath "lib\screens\dashboard_screen.dart" -Encoding utf8

Write-Host "[OK] lib/screens/dashboard_screen.dart généré" -ForegroundColor Yellow

# 6. lib/screens/live_channels_screen.dart
@'
import 'package:flutter/material.dart';
import 'player_screen.dart';

class LiveChannelsScreen extends StatefulWidget {
  final String serverUrl;
  final String username;
  final String password;

  const LiveChannelsScreen({
    Super.key,
    required this.serverUrl,
    required this.username,
    required this.password,
  });

  @override
  State<LiveChannelsScreen> createState() => _LiveChannelsScreenState();
}

class _LiveChannelsScreenState extends State<LiveChannelsScreen> {
  final List<Map<String, String>> _channels = [
    {
      'name': 'France 24 HD',
      'url': 'https://static.france24.com/live/F24_FR_LO_HLS/live_tv-tech.m3u8',
      'logo': 'https://upload.wikimedia.org/wikipedia/commons/b/b3/France24.png',
    },
    {
      'name': 'Arte HD',
      'url': 'https://artesimulcast.akamaized.net/hls/live/2031003/artelive_fr/index.m3u8',
      'logo': '',
    },
    {
      'name': 'Big Buck Bunny (Test Stream)',
      'url': 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
      'logo': '',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chaînes en Direct'),
      ),
      body: ListView.separated(
        itemCount: _channels.length,
        separatorBuilder: (context, index) => const Divider(height: 1, color: Colors.white10),
        itemBuilder: (context, index) {
          final channel = _channels[index];
          return ListTile(
            leading: channel['logo']!.isNotEmpty
                ? Image.network(channel['logo']!, width: 40, errorBuilder: (c, e, s) => const Icon(Icons.tv))
                : const Icon(Icons.tv),
            title: Text(channel['name']!, style: const TextStyle(fontWeight: FontWeight.w500)),
            subtitle: const Text('En direct - HD 1080p'),
            trailing: const Icon(Icons.play_arrow_rounded, color: Colors.blue),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PlayerScreen(
                    streamUrl: channel['url']!,
                    channelName: channel['name']!,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
'@ | Out-File -FilePath "lib\screens\live_channels_screen.dart" -Encoding utf8

Write-Host "[OK] lib/screens/live_channels_screen.dart généré" -ForegroundColor Yellow

# 7. lib/screens/player_screen.dart
@'
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

class PlayerScreen extends StatefulWidget {
  final String streamUrl;
  final String channelName;

  const PlayerScreen({
    Super.key,
    required this.streamUrl,
    required this.channelName,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initialize