import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/pin_service.dart';
import '../theme/app_theme.dart';
import '../utils/animations.dart';
import 'home_screen.dart';

class PinSetupScreen extends StatefulWidget {
  /// If false, back button is blocked — user must complete setup.
  final bool canDismiss;
  /// If true, on completion replaces entire nav stack with HomeScreen.
  final bool replaceWithHome;
  /// If true, shows "Change PIN" copy instead of "Create PIN".
  final bool isChanging;

  const PinSetupScreen({
    super.key,
    this.canDismiss = true,
    this.replaceWithHome = false,
    this.isChanging = false,
  });

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen>
    with TickerProviderStateMixin {
  int _step = 1; // 1 = enter, 2 = confirm
  String _pin = '';
  String _firstPin = '';
  String? _error;

  late AnimationController _entryCtrl;
  late AnimationController _shakeCtrl;
  late AnimationController _stepCtrl;

  late Animation<double> _entryFade;
  late Animation<Offset> _entrySlide;
  late Animation<double> _shakeAnim;
  late Animation<double> _stepFade;
  late Animation<Offset> _stepSlide;

  @override
  void initState() {
    super.initState();

    _entryCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _shakeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _stepCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));

    _entryFade =
        CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _entrySlide =
        Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(
            CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));
    _shakeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -14.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -14.0, end: 14.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 14.0, end: -10.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -10.0, end: 10.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10.0, end: 0.0), weight: 1),
    ]).animate(
        CurvedAnimation(parent: _shakeCtrl, curve: Curves.easeInOut));
    _stepFade =
        CurvedAnimation(parent: _stepCtrl, curve: Curves.easeOut);
    _stepSlide =
        Tween<Offset>(begin: const Offset(0.2, 0), end: Offset.zero).animate(
            CurvedAnimation(parent: _stepCtrl, curve: Curves.easeOutCubic));

    _entryCtrl.forward();
    _stepCtrl.forward();
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _shakeCtrl.dispose();
    _stepCtrl.dispose();
    super.dispose();
  }

  void _onDigit(String d) {
    if (_pin.length >= 4) return;
    HapticFeedback.selectionClick();
    setState(() {
      _pin += d;
      _error = null;
    });
    if (_pin.length == 4) {
      Future.delayed(const Duration(milliseconds: 120), _advance);
    }
  }

  void _onDelete() {
    if (_pin.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _error = null;
    });
  }

  void _advance() {
    if (_step == 1) {
      setState(() {
        _firstPin = _pin;
        _pin = '';
        _step = 2;
      });
      _stepCtrl.forward(from: 0);
    } else {
      _confirm();
    }
  }

  Future<void> _confirm() async {
    if (_pin == _firstPin) {
      HapticFeedback.mediumImpact();
      await PinService.savePin(_pin);
      if (!mounted) return;
      if (widget.replaceWithHome) {
        Navigator.of(context).pushAndRemoveUntil(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const HomeScreen(),
            transitionDuration: const Duration(milliseconds: 500),
            transitionsBuilder: (_, a, __, child) => FadeTransition(
              opacity: CurvedAnimation(parent: a, curve: Curves.easeOut),
              child: child,
            ),
          ),
          (_) => false,
        );
      } else {
        Navigator.of(context).pop(true);
      }
    } else {
      HapticFeedback.heavyImpact();
      setState(() {
        _pin = '';
        _firstPin = '';
        _step = 1;
        _error = 'PINs did not match. Please try again.';
      });
      _shakeCtrl.forward(from: 0);
      _stepCtrl.forward(from: 0);
    }
  }

  String get _title {
    if (_step == 1) {
      return widget.isChanging ? 'New PIN' : 'Create PIN';
    }
    return 'Confirm PIN';
  }

  String get _subtitle {
    if (_step == 1) {
      return widget.isChanging
          ? 'Enter your new 4-digit PIN'
          : 'Choose a 4-digit PIN to secure your app';
    }
    return 'Re-enter the same PIN to confirm';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: widget.canDismiss,
      child: Scaffold(
        backgroundColor: const Color(0xFF061410),
        body: Stack(children: [
          // ── Background ──────────────────────────────────────────────────────
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF0B2418),
                    Color(0xFF061410),
                    Color(0xFF030D08),
                  ],
                ),
              ),
            ),
          ),

          // ── Pulsing orbs ────────────────────────────────────────────────────
          Positioned(
            top: -100,
            right: -70,
            child: PulsingOrb(
              size: 280,
              color: AppColors.primaryLight.withValues(alpha: 0.13),
              duration: const Duration(seconds: 7),
            ),
          ),
          Positioned(
            bottom: -60,
            left: -50,
            child: PulsingOrb(
              size: 200,
              color: AppColors.accent.withValues(alpha: 0.05),
              duration: const Duration(seconds: 9),
            ),
          ),

          // ── Content ──────────────────────────────────────────────────────────
          SafeArea(
            child: FadeTransition(
              opacity: _entryFade,
              child: SlideTransition(
                position: _entrySlide,
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: Column(
                    children: [
                      // Header with optional close button
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                        child: Row(
                          children: [
                            if (widget.canDismiss)
                              IconButton(
                                icon: const Icon(Icons.close_rounded,
                                    color: Colors.white54, size: 22),
                                onPressed: () => Navigator.of(context).pop(),
                              )
                            else
                              const SizedBox(width: 48),
                            const Spacer(),
                            // Step indicator
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.07),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.1),
                                ),
                              ),
                              child: Text(
                                'Step $_step of 2',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white.withValues(alpha: 0.55),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Lock icon
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.accent.withValues(alpha: 0.25),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.accent.withValues(alpha: 0.15),
                              blurRadius: 20,
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(Icons.lock_outline_rounded,
                              color: AppColors.accent, size: 28),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Step title (animated)
                      FadeTransition(
                        opacity: _stepFade,
                        child: SlideTransition(
                          position: _stepSlide,
                          child: Column(
                            children: [
                              Text(
                                _title,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 40),
                                child: Text(
                                  _subtitle,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white.withValues(alpha: 0.45),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Step progress bar
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 80),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Container(
                            height: 3,
                            color: Colors.white.withValues(alpha: 0.08),
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: _step == 1 ? 0.5 : 1.0,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 350),
                                curve: Curves.easeOutCubic,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      AppColors.accent,
                                      AppColors.accentLight,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 28),

                      // Dots + error (with shake)
                      AnimatedBuilder(
                        animation: _shakeCtrl,
                        builder: (_, child) => Transform.translate(
                          offset: Offset(_shakeAnim.value, 0),
                          child: child,
                        ),
                        child: Column(
                          children: [
                            _SetupDots(count: _pin.length),
                            AnimatedSize(
                              duration: const Duration(milliseconds: 200),
                              child: _error != null
                                  ? Padding(
                                      padding: const EdgeInsets.only(top: 12),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: AppColors.danger
                                              .withValues(alpha: 0.1),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          border: Border.all(
                                            color: AppColors.danger
                                                .withValues(alpha: 0.3),
                                          ),
                                        ),
                                        child: Text(
                                          _error!,
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.danger,
                                          ),
                                        ),
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 28),

                      // Numpad
                      _SetupNumPad(
                        onDigit: _onDigit,
                        onDelete: _onDelete,
                      ),

                      const SizedBox(height: 12),

                      // Back to step 1 (only on step 2)
                      if (_step == 2)
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _step = 1;
                              _pin = '';
                              _firstPin = '';
                              _error = null;
                            });
                            _stepCtrl.forward(from: 0);
                          },
                          child: Text(
                            'Back — re-enter first PIN',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.28),
                            ),
                          ),
                        )
                      else
                        const SizedBox(height: 36),

                      const SizedBox(height: 12),
                    ],
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

// ── Setup dot indicators ───────────────────────────────────────────────────────
class _SetupDots extends StatelessWidget {
  final int count;
  const _SetupDots({required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (i) {
        final filled = i < count;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutBack,
            width: filled ? 18 : 16,
            height: filled ? 18 : 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: filled ? AppColors.accent : Colors.transparent,
              border: Border.all(
                color: filled
                    ? AppColors.accent
                    : Colors.white.withValues(alpha: 0.25),
                width: 2,
              ),
              boxShadow: filled
                  ? [
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.5),
                        blurRadius: 10,
                      )
                    ]
                  : null,
            ),
          ),
        );
      }),
    );
  }
}

// ── Setup numpad ───────────────────────────────────────────────────────────────
class _SetupNumPad extends StatelessWidget {
  final ValueChanged<String> onDigit;
  final VoidCallback onDelete;

  const _SetupNumPad({required this.onDigit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    const rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', '⌫'],
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 44),
      child: Column(
        children: rows
            .map(
              (row) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: row.map((k) {
                    if (k.isEmpty) {
                      return const SizedBox(width: 72, height: 72);
                    }
                    return _SetupKey(
                      label: k,
                      isDelete: k == '⌫',
                      onTap: () {
                        if (k == '⌫') {
                          onDelete();
                        } else {
                          onDigit(k);
                        }
                      },
                    );
                  }).toList(),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _SetupKey extends StatefulWidget {
  final String label;
  final bool isDelete;
  final VoidCallback onTap;

  const _SetupKey({
    required this.label,
    required this.onTap,
    this.isDelete = false,
  });

  @override
  State<_SetupKey> createState() => _SetupKeyState();
}

class _SetupKeyState extends State<_SetupKey>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 100));
    _scale = Tween<double>(begin: 1.0, end: 0.88)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, child) =>
            Transform.scale(scale: _scale.value, child: child),
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.isDelete
                ? Colors.white.withValues(alpha: 0.04)
                : Colors.white.withValues(alpha: 0.09),
            border: Border.all(
              color: Colors.white
                  .withValues(alpha: widget.isDelete ? 0.06 : 0.12),
              width: 1,
            ),
          ),
          child: Center(
            child: widget.isDelete
                ? Icon(
                    Icons.backspace_outlined,
                    color: Colors.white.withValues(alpha: 0.55),
                    size: 22,
                  )
                : Text(
                    widget.label,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
