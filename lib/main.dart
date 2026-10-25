import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/shared_prefs_helper.dart';

void main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // 📱 Configuration Mobile / Tablette (Android & iOS)
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }

    // Initialisation de MediaKit
    try {
      MediaKit.ensureInitialized();
    } catch (e) {
      debugPrint("Erreur MediaKit : $e");
    }

    runApp(const MyApp());
  }, (error, stack) {
    debugPrint("CRASH GLOBAL CAPTURÉ : $error");
    debugPrint(stack.toString());
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ConanStream',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF000000),
      ),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _particleController;

  late Animation<double> _zoomAnim;
  late Animation<double> _flashAnim;
  late Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();

    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5500),
    );

    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _flashAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 15),
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 85),
    ]).animate(_mainController);

    _zoomAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _mainController, curve: const Interval(0.1, 0.6, curve: Curves.elasticOut)),
    );

    _shakeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _mainController, curve: const Interval(0.1, 0.3, curve: Curves.bounceIn)),
    );

    _mainController.forward();

    Timer(const Duration(milliseconds: 5800), _navigateToNextScreen);
  }

  Future<void> _navigateToNextScreen() async {
    final accounts = await SharedPrefsHelper.getAccounts();
    if (!mounted) return;

    Widget targetScreen;
    if (accounts.isNotEmpty) {
      final activeAccount = accounts.last;
      targetScreen = HomeScreen(
        serverUrl: activeAccount.serverUrl,
        username: activeAccount.username,
        password: activeAccount.password,
      );
    } else {
      targetScreen = const LoginScreen();
    }

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 800),
        pageBuilder: (_, __, ___) => targetScreen,
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  void dispose() {
    _mainController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: Center(
        child: AnimatedBuilder(
          animation: Listenable.merge([_mainController, _particleController]),
          builder: (context, child) {
            double shakeOffset = math.sin(_shakeAnim.value * math.pi * 8) * (1.0 - _mainController.value) * 10;

            return Transform.translate(
              offset: Offset(shakeOffset, 0),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(1280, 720),
                    painter: EpicCyberpunkPainter(
                      progress: _mainController.value,
                      tick: _particleController.value,
                    ),
                  ),
                  ScaleTransition(
                    scale: _zoomAnim,
                    child: Container(
                      width: 600,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00E5FF).withOpacity(0.6 + (math.sin(_particleController.value * math.pi * 2) * 0.2)),
                            blurRadius: 70,
                            spreadRadius: 10,
                          ),
                          BoxShadow(
                            color: const Color(0xFFD500F9).withOpacity(0.6 + (math.cos(_particleController.value * math.pi * 2) * 0.2)),
                            blurRadius: 70,
                            spreadRadius: 10,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/splash_logo.png',
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(Icons.flash_on, size: 120, color: Color(0xFF00E5FF));
                          },
                        ),
                      ),
                    ),
                  ),
                  if (_flashAnim.value > 0.0)
                    Container(
                      color: Colors.white.withOpacity(_flashAnim.value),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class EpicCyberpunkPainter extends CustomPainter {
  final double progress;
  final double tick;

  EpicCyberpunkPainter({required this.progress, required this.tick});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final rnd = math.Random(1337);

    final paintCyan = Paint()
      ..color = const Color(0xFF00E5FF).withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final paintPurple = Paint()
      ..color = const Color(0xFFD500F9).withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 16; i++) {
      final angle = (i * math.pi / 8) + (tick * math.pi * 0.5);
      final distanceMax = 200.0 + (progress * 500.0 * rnd.nextDouble());

      final startX = center.dx + math.cos(angle) * 100;
      final startY = center.dy + math.sin(angle) * 100;
      final endX = center.dx + math.cos(angle) * distanceMax;
      final endY = center.dy + math.sin(angle) * distanceMax;

      final path = Path()
        ..moveTo(startX, startY)
        ..lineTo(endX, endY);

      canvas.drawPath(path, i % 2 == 0 ? paintCyan : paintPurple);

      canvas.drawCircle(
        Offset(endX, endY),
        3.0 + (rnd.nextDouble() * 3),
        i % 2 == 0 ? paintCyan : paintPurple,
      );
    }
  }

  @override
  bool shouldRepaint(covariant EpicCyberpunkPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.tick != tick;
  }
}