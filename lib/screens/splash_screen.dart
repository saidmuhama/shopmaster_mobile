import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../services/pin_service.dart';
import '../theme/app_theme.dart';
import '../utils/animations.dart';
import 'login_screen.dart';
import 'home_screen.dart';
import 'pin_lock_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {

  late AnimationController _bgCtrl;    // background reveal
  late AnimationController _logoCtrl;  // logo + text
  late AnimationController _tagCtrl;   // tagline + progress

  late Animation<double> _bgReveal;
  late Animation<double> _logoScale;
  late Animation<double> _logoFade;
  late Animation<double> _logoGlow;
  late Animation<Offset> _titleSlide;
  late Animation<double> _titleFade;
  late Animation<double> _subtitleFade;
  late Animation<double> _tagFade;
  late Animation<double> _progressWidth;

  @override
  void initState() {
    super.initState();

    _bgCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _logoCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _tagCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));

    _bgReveal = CurvedAnimation(parent: _bgCtrl, curve: Curves.easeOut);

    _logoScale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _logoCtrl, curve: const Interval(0.0, 0.6, curve: Curves.elasticOut)));
    _logoFade = CurvedAnimation(parent: _logoCtrl, curve: const Interval(0.0, 0.4));
    _logoGlow = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoCtrl, curve: const Interval(0.4, 1.0, curve: Curves.easeOut)));

    _titleSlide = Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero).animate(
      CurvedAnimation(parent: _logoCtrl, curve: const Interval(0.3, 0.8, curve: Curves.easeOutCubic)));
    _titleFade = CurvedAnimation(parent: _logoCtrl, curve: const Interval(0.3, 0.7));
    _subtitleFade = CurvedAnimation(parent: _logoCtrl, curve: const Interval(0.55, 0.9));

    _tagFade = CurvedAnimation(parent: _tagCtrl, curve: const Interval(0.0, 0.5));
    _progressWidth = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _tagCtrl, curve: Curves.easeInOut));

    _runSequence();
    _checkAuth();
  }

  void _runSequence() async {
    await _bgCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 100));
    _logoCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 500));
    _tagCtrl.forward();
  }

  Future<void> _checkAuth() async {
    await ApiService.loadSession();
    await Future.delayed(const Duration(milliseconds: 2600));
    if (!mounted) return;
    final user = await ApiService.getCachedUser();
    if (!mounted) return;

    Widget nextScreen;
    if (user == null) {
      nextScreen = const LoginScreen();
    } else {
      final hasPin = await PinService.hasPin();
      if (!mounted) return;
      nextScreen = hasPin
          ? PinLockScreen(userName: user.name, replaceWithHome: true)
          : const HomeScreen();
    }

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => nextScreen,
        transitionDuration: const Duration(milliseconds: 600),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
          child: child),
      ),
    );
  }

  @override
  void dispose() {
    _bgCtrl.dispose(); _logoCtrl.dispose(); _tagCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        // ── Animated background reveal ───────────────────────────────────────
        AnimatedBuilder(
          animation: _bgReveal,
          builder: (_, __) => Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [
                  Color.lerp(Colors.black, const Color(0xFF0F2D1A), _bgReveal.value)!,
                  Color.lerp(Colors.black, const Color(0xFF071810), _bgReveal.value)!,
                ],
              ),
            ),
          ),
        ),

        // ── Pulsing orbs ────────────────────────────────────────────────────
        Positioned(top: -120, right: -80,
          child: PulsingOrb(size: 340,
            color: AppColors.primaryLight.withValues(alpha: 0.18), duration: const Duration(seconds: 5))),
        Positioned(bottom: -100, left: -60,
          child: PulsingOrb(size: 260,
            color: AppColors.accent.withValues(alpha: 0.07), duration: const Duration(seconds: 6))),
        Positioned(top: 220, left: -80,
          child: PulsingOrb(size: 180,
            color: AppColors.primaryMid.withValues(alpha: 0.25), duration: const Duration(seconds: 4))),

        // ── Center content ───────────────────────────────────────────────────
        Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Logo mark
            AnimatedBuilder(
              animation: _logoCtrl,
              builder: (_, __) => Opacity(
                opacity: _logoFade.value,
                child: Transform.scale(
                  scale: _logoScale.value,
                  child: Stack(alignment: Alignment.center, children: [
                    // Glow ring
                    Opacity(
                      opacity: _logoGlow.value * 0.4,
                      child: Container(
                        width: 130, height: 130,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(
                            color: AppColors.accent.withValues(alpha: 0.5),
                            blurRadius: 40, spreadRadius: 10)],
                        ),
                      ),
                    ),
                    Container(
                      width: 110, height: 110,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.15), width: 1.5),
                        boxShadow: [BoxShadow(
                          color: AppColors.accent.withValues(alpha: 0.25 * _logoGlow.value),
                          blurRadius: 30, spreadRadius: 0)],
                      ),
                      child: Center(
                        child: Text('M',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 58, fontWeight: FontWeight.w900,
                            color: AppColors.accent,
                            shadows: [Shadow(
                              color: AppColors.accent.withValues(alpha: 0.5 * _logoGlow.value),
                              blurRadius: 20)],
                          )),
                      ),
                    ),
                  ]),
                ),
              ),
            ),

            const SizedBox(height: 28),

            // Brand name
            AnimatedBuilder(
              animation: _logoCtrl,
              builder: (_, __) => FadeTransition(
                opacity: _titleFade,
                child: SlideTransition(
                  position: _titleSlide,
                  child: Text('MDSPro',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 38, fontWeight: FontWeight.w900,
                      color: Colors.white, letterSpacing: -1.5)),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Subtitle
            AnimatedBuilder(
              animation: _logoCtrl,
              builder: (_, __) => FadeTransition(
                opacity: _subtitleFade,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 20, height: 1.5,
                    color: AppColors.accent.withValues(alpha: 0.6)),
                  const SizedBox(width: 10),
                  Text('Shop Management System',
                    style: GoogleFonts.inter(
                      fontSize: 13, fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.5), letterSpacing: 1.0)),
                  const SizedBox(width: 10),
                  Container(width: 20, height: 1.5,
                    color: AppColors.accent.withValues(alpha: 0.6)),
                ]),
              ),
            ),
          ]),
        ),

        // ── Bottom tag ───────────────────────────────────────────────────────
        Positioned(bottom: 48, left: 0, right: 0,
          child: AnimatedBuilder(
            animation: _tagCtrl,
            builder: (_, __) => FadeTransition(
              opacity: _tagFade,
              child: Column(children: [
                // Progress bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 100),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      height: 2.5,
                      color: Colors.white.withValues(alpha: 0.1),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: _progressWidth.value,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [AppColors.accent, AppColors.accentLight]),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text('Owner Dashboard  •  v1.0',
                  style: GoogleFonts.inter(
                    fontSize: 11, fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.3), letterSpacing: 0.8)),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}
