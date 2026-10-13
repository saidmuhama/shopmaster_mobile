import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/pin_lock_screen.dart';
import 'services/api_service.dart';
import 'services/notification_service.dart';
import 'services/pin_service.dart';

final _navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  ApiService.navigatorKey = _navigatorKey;

  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('[Firebase] init error: $e');
  }

  try {
    await NotificationService.init();
  } catch (e) {
    debugPrint('[Notifications] init error: $e');
  }

  runApp(const MDSProApp());
}

class MDSProApp extends StatefulWidget {
  const MDSProApp({super.key});

  @override
  State<MDSProApp> createState() => _MDSProAppState();
}

class _MDSProAppState extends State<MDSProApp> with WidgetsBindingObserver {
  DateTime? _pausedAt;
  bool _lockShown = false;

  /// Lock triggers after the app has been in background for this long.
  static const _lockAfter = Duration(minutes: 10);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _pausedAt ??= DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final p = _pausedAt;
      _pausedAt = null;
      if (_lockShown || p == null) return;
      if (DateTime.now().difference(p) < _lockAfter) return;
      final hasPIN = await PinService.hasPin();
      if (!hasPIN || !mounted) return;
      _lockShown = true;
      _navigatorKey.currentState?.push(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => PinLockScreen(
            onUnlocked: () => _lockShown = false,
          ),
          fullscreenDialog: true,
          opaque: true,
          transitionDuration: const Duration(milliseconds: 300),
          transitionsBuilder: (_, a, __, child) => FadeTransition(
            opacity: CurvedAnimation(parent: a, curve: Curves.easeOut),
            child: child,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MDSPro',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      navigatorKey: _navigatorKey,
      routes: {
        '/login': (_) => const LoginScreen(),
      },
      home: const SplashScreen(),
    );
  }
}
