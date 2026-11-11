import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../services/pin_service.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import '../utils/l10n_ext.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class PinLockScreen extends StatefulWidget {
  final String? userName;
  final bool replaceWithHome;
  final VoidCallback? onUnlocked;

  const PinLockScreen({
    super.key,
    this.userName,
    this.replaceWithHome = false,
    this.onUnlocked,
  });

  @override
  State<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends State<PinLockScreen>
    with TickerProviderStateMixin {
  String _pin = '';
  String? _error;
  bool _verifying = false;
  int _attempts = 0;
  DateTime _now = DateTime.now();
  Timer? _clock;

  late AnimationController _entryCtrl;
  late AnimationController _shakeCtrl;
  late AnimationController _successCtrl;
  late Animation<double> _entryFade;
  late Animation<Offset> _entrySlide;
  late Animation<double> _shakeAnim;
  late Animation<double> _successScale;

  @override
  void initState() {
    super.initState();

    _entryCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _shakeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 480));
    _successCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));

    _entryFade  = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _entrySlide = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));
    _shakeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -16.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -16.0, end: 16.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 16.0, end: -10.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -10.0, end: 10.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.easeInOut));
    _successScale = Tween<double>(begin: 1.0, end: 1.08)
        .animate(CurvedAnimation(parent: _successCtrl, curve: Curves.elasticOut));

    _entryCtrl.forward();

    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    _entryCtrl.dispose();
    _shakeCtrl.dispose();
    _successCtrl.dispose();
    super.dispose();
  }

  void _onDigit(String d) {
    if (_pin.length >= 4 || _verifying) return;
    HapticFeedback.selectionClick();
    setState(() { _pin += d; _error = null; });
    if (_pin.length == 4) _verify();
  }

  void _onDelete() {
    if (_pin.isEmpty || _verifying) return;
    HapticFeedback.selectionClick();
    setState(() { _pin = _pin.substring(0, _pin.length - 1); _error = null; });
  }

  Future<void> _verify() async {
    setState(() => _verifying = true);
    await Future.delayed(const Duration(milliseconds: 140));
    final ok = await PinService.verifyPin(_pin);
    if (!mounted) return;
    if (ok) {
      HapticFeedback.mediumImpact();
      _successCtrl.forward();
      await Future.delayed(const Duration(milliseconds: 300));
      widget.onUnlocked?.call();
      if (!mounted) return;
      if (widget.replaceWithHome) {
        Navigator.of(context).pushAndRemoveUntil(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const HomeScreen(),
            transitionDuration: const Duration(milliseconds: 500),
            transitionsBuilder: (_, a, __, child) => FadeTransition(
              opacity: CurvedAnimation(parent: a, curve: Curves.easeOut),
              child: child),
          ), (_) => false,
        );
      } else {
        Navigator.of(context).pop();
      }
    } else {
      HapticFeedback.heavyImpact();
      _attempts++;
      setState(() {
        _pin = '';
        _verifying = false;
        _error = _attempts >= 3
            ? 'Incorrect PIN · $_attempts failed attempts'
            : 'Incorrect PIN. Try again.';
      });
      _shakeCtrl.forward(from: 0);
    }
  }

  void _signOut() {
    final resp = Responsive.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        final sheet = _LogoutConfirmSheet(
          onConfirm: () async {
            await ApiService.logout();
            if (!mounted) return;
            Navigator.of(context).pushAndRemoveUntil(
              PageRouteBuilder(
                pageBuilder: (_, __, ___) => const LoginScreen(),
                transitionDuration: const Duration(milliseconds: 500),
                transitionsBuilder: (_, a, __, child) => FadeTransition(
                  opacity: CurvedAnimation(parent: a, curve: Curves.easeOut),
                  child: child),
              ), (_) => false,
            );
          },
        );
        if (!resp.isTablet) return sheet;
        return Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: sheet,
          ),
        );
      },
    );
  }

  String get _timeStr {
    final h = _now.hour.toString().padLeft(2, '0');
    final m = _now.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String get _dateStr {
    const days   = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${days[_now.weekday - 1]}, ${months[_now.month - 1]} ${_now.day}';
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF030D08),
        body: Stack(children: [
          // ── Layered gradient background ─────────────────────────────────────
          Positioned.fill(
            child: CustomPaint(painter: _MeshPainter()),
          ),

          // ── Radial glow — top ───────────────────────────────────────────────
          Positioned(
            top: -120, left: size.width / 2 - 160,
            child: Container(
              width: 320, height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  const Color(0xFF1A5C32).withValues(alpha: 0.5),
                  Colors.transparent,
                ]),
              ),
            ),
          ),

          // ── Accent glow — bottom left ────────────────────────────────────────
          Positioned(
            bottom: -80, left: -60,
            child: Container(
              width: 260, height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  AppColors.accent.withValues(alpha: 0.08),
                  Colors.transparent,
                ]),
              ),
            ),
          ),

          // ── Main content ─────────────────────────────────────────────────────
          SafeArea(
            child: FadeTransition(
              opacity: _entryFade,
              child: SlideTransition(
                position: _entrySlide,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(height: size.height * 0.06),

                      // ── Live clock ───────────────────────────────────────────
                      Text(
                        _timeStr,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 56, fontWeight: FontWeight.w200,
                          color: Colors.white, letterSpacing: -2.0, height: 1.0),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _dateStr,
                        style: GoogleFonts.inter(
                          fontSize: 13, fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.35),
                          letterSpacing: 0.5),
                      ),

                      SizedBox(height: size.height * 0.045),

                      // ── Brand monogram with ring ──────────────────────────────
                      ScaleTransition(
                        scale: _successScale,
                        child: _BrandRing(),
                      ),

                      const SizedBox(height: 14),

                      // ── Greeting ─────────────────────────────────────────────
                      Text(
                        widget.userName != null
                            ? 'Welcome back, ${widget.userName}'
                            : 'MDSPro is locked',
                        style: GoogleFonts.inter(
                          fontSize: 14, fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.5)),
                      ),

                      SizedBox(height: size.height * 0.04),

                      // ── PIN indicator label ───────────────────────────────────
                      Text(
                        context.l10n.pinLockSubtitle.toUpperCase(),
                        style: GoogleFonts.inter(
                          fontSize: 10, fontWeight: FontWeight.w800,
                          color: Colors.white.withValues(alpha: 0.25),
                          letterSpacing: 2.0),
                      ),
                      const SizedBox(height: 14),

                      // ── PIN bars + error (shakes) ─────────────────────────────
                      AnimatedBuilder(
                        animation: _shakeCtrl,
                        builder: (_, child) => Transform.translate(
                          offset: Offset(_shakeAnim.value, 0),
                          child: child,
                        ),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          _PinBars(
                            count: _pin.length,
                            hasError: _error != null,
                            isVerifying: _verifying,
                          ),
                          AnimatedSize(
                            duration: const Duration(milliseconds: 200),
                            child: _error != null
                                ? Padding(
                                    padding: const EdgeInsets.only(top: 12),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 7),
                                      decoration: BoxDecoration(
                                        color: AppColors.danger.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: AppColors.danger.withValues(alpha: 0.25))),
                                      child: Text(
                                        _error!,
                                        style: GoogleFonts.inter(
                                          fontSize: 12, fontWeight: FontWeight.w700,
                                          color: AppColors.danger),
                                      ),
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ]),
                      ),

                      SizedBox(height: size.height * 0.045),

                      // ── Keypad ────────────────────────────────────────────────
                      _PinKeypad(
                        onDigit: _onDigit,
                        onDelete: _onDelete,
                        enabled: !_verifying,
                      ),

                      const SizedBox(height: 20),

                      // ── Sign out link ─────────────────────────────────────────
                      GestureDetector(
                        onTap: _signOut,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 9),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.08))),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.swap_horiz_rounded,
                              size: 13,
                              color: Colors.white.withValues(alpha: 0.3)),
                            const SizedBox(width: 6),
                            Text(
                              'Use a different account',
                              style: GoogleFonts.inter(
                                fontSize: 12, fontWeight: FontWeight.w600,
                                color: Colors.white.withValues(alpha: 0.3)),
                            ),
                          ]),
                        ),
                      ),

                      const SizedBox(height: 28),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
        ]),
      ),
    );
  }
}

// ── Subtle diagonal mesh background ────────────────────────────────────────────
class _MeshPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF0B2418), Color(0xFF061410), Color(0xFF020B06)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bg);

    final linePaint = Paint()
      ..color = const Color(0xFF1A4A2E).withValues(alpha: 0.25)
      ..strokeWidth = 0.5;

    const spacing = 36.0;
    for (double i = -size.height; i < size.width + size.height; i += spacing) {
      canvas.drawLine(Offset(i, 0), Offset(i + size.height, size.height), linePaint);
    }
  }

  @override
  bool shouldRepaint(_MeshPainter old) => false;
}

// ── Brand ring ──────────────────────────────────────────────────────────────────
class _BrandRing extends StatefulWidget {
  @override
  State<_BrandRing> createState() => _BrandRingState();
}

class _BrandRingState extends State<_BrandRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _rotate;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 8))
      ..repeat();
    _rotate = Tween<double>(begin: 0, end: 2 * math.pi).animate(_ctrl);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 80, height: 80,
    child: Stack(alignment: Alignment.center, children: [
      // Rotating gradient ring
      AnimatedBuilder(
        animation: _rotate,
        builder: (_, __) => Transform.rotate(
          angle: _rotate.value,
          child: Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: SweepGradient(colors: [
                AppColors.accent.withValues(alpha: 0.0),
                AppColors.accent.withValues(alpha: 0.6),
                AppColors.accent.withValues(alpha: 0.0),
              ]),
            ),
          ),
        ),
      ),
      // Static inner circle (masks ring to border-only)
      Container(
        width: 70, height: 70,
        decoration: const BoxDecoration(
          color: Color(0xFF061410), shape: BoxShape.circle),
      ),
      // Logo container
      Container(
        width: 62, height: 62,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.04),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08), width: 1),
        ),
        child: Center(
          child: RichText(
            text: TextSpan(children: [
              TextSpan(
                text: 'M',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 26, fontWeight: FontWeight.w900,
                  color: Colors.white)),
              TextSpan(
                text: '.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 28, fontWeight: FontWeight.w900,
                  color: AppColors.accent)),
            ]),
          ),
        ),
      ),
    ]),
  );
}

// ── PIN bar indicators (horizontal capsules) ────────────────────────────────────
class _PinBars extends StatelessWidget {
  final int count;
  final bool hasError;
  final bool isVerifying;
  const _PinBars({required this.count, this.hasError = false, this.isVerifying = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (i) {
        final filled = i < count;
        final barColor = hasError
            ? AppColors.danger
            : isVerifying
                ? AppColors.accent.withValues(alpha: 0.6)
                : AppColors.accent;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 7),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            width: filled ? 44 : 36,
            height: 6,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              color: filled ? barColor : Colors.transparent,
              border: Border.all(
                color: filled ? barColor : Colors.white.withValues(alpha: 0.2),
                width: 1.5),
              boxShadow: filled
                  ? [BoxShadow(
                      color: barColor.withValues(alpha: 0.5),
                      blurRadius: 10, spreadRadius: 0)]
                  : const [],
            ),
          ),
        );
      }),
    );
  }
}

// ── PIN keypad (squircle keys with letter hints) ────────────────────────────────
class _PinKeypad extends StatelessWidget {
  final ValueChanged<String> onDigit;
  final VoidCallback onDelete;
  final bool enabled;

  const _PinKeypad({
    required this.onDigit,
    required this.onDelete,
    this.enabled = true,
  });

  static const _letters = {
    '1': '',
    '2': 'ABC',
    '3': 'DEF',
    '4': 'GHI',
    '5': 'JKL',
    '6': 'MNO',
    '7': 'PQRS',
    '8': 'TUV',
    '9': 'WXYZ',
    '0': '+',
  };

  @override
  Widget build(BuildContext context) {
    const rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', '⌫'],
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: rows.map((row) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: row.map((k) {
              if (k.isEmpty) {
                return const SizedBox(width: 76, height: 76);
              }
              return _PinKey(
                digit: k,
                letters: _letters[k] ?? '',
                isDelete: k == '⌫',
                enabled: enabled,
                onTap: () => k == '⌫' ? onDelete() : onDigit(k),
              );
            }).toList(),
          ),
        )).toList(),
      ),
    );
  }
}

class _PinKey extends StatefulWidget {
  final String digit;
  final String letters;
  final bool isDelete;
  final bool enabled;
  final VoidCallback onTap;

  const _PinKey({
    required this.digit,
    required this.letters,
    required this.onTap,
    this.isDelete = false,
    this.enabled = true,
  });

  @override
  State<_PinKey> createState() => _PinKeyState();
}

class _PinKeyState extends State<_PinKey>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 90));
    _scale = Tween<double>(begin: 1.0, end: 0.90)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.enabled ? (_) {
        _ctrl.forward();
        setState(() => _pressed = true);
      } : null,
      onTapUp: widget.enabled ? (_) {
        _ctrl.reverse();
        setState(() => _pressed = false);
        widget.onTap();
      } : null,
      onTapCancel: () {
        _ctrl.reverse();
        setState(() => _pressed = false);
      },
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, child) => Transform.scale(scale: _scale.value, child: child),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: _pressed
                  ? [
                      AppColors.accent.withValues(alpha: 0.22),
                      AppColors.accent.withValues(alpha: 0.08),
                    ]
                  : widget.isDelete
                      ? [
                          Colors.white.withValues(alpha: 0.04),
                          Colors.white.withValues(alpha: 0.02),
                        ]
                      : [
                          Colors.white.withValues(alpha: 0.10),
                          Colors.white.withValues(alpha: 0.05),
                        ],
            ),
            border: Border.all(
              color: _pressed
                  ? AppColors.accent.withValues(alpha: 0.4)
                  : Colors.white.withValues(alpha: widget.isDelete ? 0.07 : 0.11),
              width: 1,
            ),
            boxShadow: _pressed
                ? [BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.2),
                    blurRadius: 20, spreadRadius: -2)]
                : [BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 8, offset: const Offset(0, 4))],
          ),
          child: Center(
            child: widget.isDelete
                ? Icon(Icons.backspace_rounded,
                    color: Colors.white.withValues(alpha: 0.5), size: 22)
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.digit,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 28, fontWeight: FontWeight.w500,
                          color: Colors.white, height: 1.0),
                      ),
                      if (widget.letters.isNotEmpty)
                        Text(
                          widget.letters,
                          style: GoogleFonts.inter(
                            fontSize: 7.5, fontWeight: FontWeight.w700,
                            color: Colors.white.withValues(alpha: 0.3),
                            letterSpacing: 1.0),
                        ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

// ── Logout confirm sheet ───────────────────────────────────────────────────────
class _LogoutConfirmSheet extends StatelessWidget {
  final VoidCallback onConfirm;
  const _LogoutConfirmSheet({required this.onConfirm});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
    decoration: BoxDecoration(
      color: const Color(0xFF0F2A1A),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
    ),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 40, height: 4,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(2))),
      const SizedBox(height: 24),
      Container(
        width: 54, height: 54,
        decoration: BoxDecoration(
          color: AppColors.danger.withValues(alpha: 0.12),
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.danger.withValues(alpha: 0.2))),
        child: const Icon(Icons.logout_rounded, color: AppColors.danger, size: 24)),
      const SizedBox(height: 16),
      Text(context.l10n.logoutConfirm,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
      const SizedBox(height: 8),
      Text(context.l10n.logoutConfirmDesc,
        style: GoogleFonts.inter(
          fontSize: 13, fontWeight: FontWeight.w500,
          color: Colors.white.withValues(alpha: 0.5)),
        textAlign: TextAlign.center),
      const SizedBox(height: 28),
      Row(children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14))),
            child: Text(context.l10n.cancel,
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800,
                color: Colors.white.withValues(alpha: 0.7))),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: () { Navigator.pop(context); onConfirm(); },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14))),
            child: Text(context.l10n.logout,
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800, color: Colors.white)),
          ),
        ),
      ]),
    ]),
  );
}
