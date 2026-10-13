import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../services/pin_service.dart';
import '../theme/app_theme.dart';
import '../utils/animations.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class PinLockScreen extends StatefulWidget {
  final String? userName;
  /// If true, on success replaces entire nav stack with HomeScreen.
  /// If false, simply pops (caller manages stack).
  final bool replaceWithHome;
  /// Called after successful verification, before navigation.
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

  late AnimationController _entryCtrl;
  late AnimationController _shakeCtrl;
  late Animation<double> _entryFade;
  late Animation<Offset> _entrySlide;
  late Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();

    _entryCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _shakeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));

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

    _entryCtrl.forward();
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _shakeCtrl.dispose();
    super.dispose();
  }

  void _onDigit(String d) {
    if (_pin.length >= 4 || _verifying) return;
    HapticFeedback.selectionClick();
    setState(() {
      _pin += d;
      _error = null;
    });
    if (_pin.length == 4) _verify();
  }

  void _onDelete() {
    if (_pin.isEmpty || _verifying) return;
    HapticFeedback.selectionClick();
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _error = null;
    });
  }

  Future<void> _verify() async {
    setState(() => _verifying = true);
    await Future.delayed(const Duration(milliseconds: 120));
    final ok = await PinService.verifyPin(_pin);
    if (!mounted) return;
    if (ok) {
      HapticFeedback.mediumImpact();
      widget.onUnlocked?.call();
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
        Navigator.of(context).pop();
      }
    } else {
      HapticFeedback.heavyImpact();
      _attempts++;
      setState(() {
        _pin = '';
        _verifying = false;
        _error = _attempts >= 3
            ? 'Incorrect PIN ($_attempts attempts)'
            : 'Incorrect PIN. Try again.';
      });
      _shakeCtrl.forward(from: 0);
    }
  }

  void _signOut() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _LogoutConfirmSheet(
        onConfirm: () async {
          await ApiService.logout();
          if (mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              PageRouteBuilder(
                pageBuilder: (_, __, ___) => const LoginScreen(),
                transitionDuration: const Duration(milliseconds: 500),
                transitionsBuilder: (_, a, __, child) => FadeTransition(
                  opacity: CurvedAnimation(parent: a, curve: Curves.easeOut),
                  child: child,
                ),
              ),
              (_) => false,
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF061410),
        body: Stack(children: [
          // ── Dark gradient background ──────────────────────────────────────
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

          // ── Pulsing orbs ─────────────────────────────────────────────────
          Positioned(
            top: -110,
            right: -80,
            child: PulsingOrb(
              size: 300,
              color: AppColors.primaryLight.withValues(alpha: 0.14),
              duration: const Duration(seconds: 7),
            ),
          ),
          Positioned(
            bottom: -70,
            left: -60,
            child: PulsingOrb(
              size: 220,
              color: AppColors.accent.withValues(alpha: 0.05),
              duration: const Duration(seconds: 9),
            ),
          ),

          // ── Content ──────────────────────────────────────────────────────
          SafeArea(
            child: FadeTransition(
              opacity: _entryFade,
              child: SlideTransition(
                position: _entrySlide,
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: Column(
                    // mainAxisSize.min: Column is only as tall as its
                    // children, preventing unbounded vertical expansion
                    // inside SingleChildScrollView (which gives ∞ height).
                    mainAxisSize: MainAxisSize.min,
                    children: [
                        const SizedBox(height: 24),

                        // App logo
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.1),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.accent.withValues(alpha: 0.2),
                                blurRadius: 28,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              'M',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 36,
                                fontWeight: FontWeight.w900,
                                color: AppColors.accent,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 14),

                        Text(
                          'MDSPro',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -0.8,
                          ),
                        ),

                        const SizedBox(height: 4),

                        Text(
                          widget.userName != null
                              ? 'Welcome back, ${widget.userName}'
                              : 'App is locked',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.4),
                          ),
                        ),

                        const SizedBox(height: 24),

                        Text(
                          'Enter PIN to continue',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.55),
                          ),
                        ),

                        const SizedBox(height: 18),

                        // Dots + error message (with horizontal shake)
                        AnimatedBuilder(
                          animation: _shakeCtrl,
                          builder: (_, child) => Transform.translate(
                            offset: Offset(_shakeAnim.value, 0),
                            child: child,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _PinDots(count: _pin.length),
                              AnimatedSize(
                                duration: const Duration(milliseconds: 200),
                                child: _error != null
                                    ? Padding(
                                        padding:
                                            const EdgeInsets.only(top: 10),
                                        child: Text(
                                          _error!,
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.danger,
                                          ),
                                        ),
                                      )
                                    : const SizedBox.shrink(),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 22),

                        // Numpad
                        _NumPad(
                          onDigit: _onDigit,
                          onDelete: _onDelete,
                          enabled: !_verifying,
                        ),

                        const SizedBox(height: 10),

                        // Sign out
                        TextButton(
                          onPressed: _signOut,
                          child: Text(
                            'Use a different account',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.28),
                              decoration: TextDecoration.underline,
                              decorationColor:
                                  Colors.white.withValues(alpha: 0.15),
                            ),
                          ),
                        ),

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

// ── Dot indicators ─────────────────────────────────────────────────────────────
class _PinDots extends StatelessWidget {
  final int count;
  const _PinDots({required this.count});

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
            // easeOutCubic never overshoots t=1, preventing BoxShadow.scale
            // from receiving a negative factor when lerping from filled→empty.
            curve: Curves.easeOutCubic,
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
              // Empty list (not null) so BoxDecoration.lerp can interpolate
              // cleanly without producing an intermediate negative blur radius.
              boxShadow: filled
                  ? [
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.5),
                        blurRadius: 10,
                        spreadRadius: 0,
                      )
                    ]
                  : const [],
            ),
          ),
        );
      }),
    );
  }
}

// ── Numpad ─────────────────────────────────────────────────────────────────────
class _NumPad extends StatelessWidget {
  final ValueChanged<String> onDigit;
  final VoidCallback onDelete;
  final bool enabled;

  const _NumPad({
    required this.onDigit,
    required this.onDelete,
    this.enabled = true,
  });

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
                    if (k.isEmpty) return const SizedBox(width: 72, height: 72);
                    return _NumKey(
                      label: k,
                      isDelete: k == '⌫',
                      enabled: enabled,
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

class _NumKey extends StatefulWidget {
  final String label;
  final bool isDelete;
  final bool enabled;
  final VoidCallback onTap;

  const _NumKey({
    required this.label,
    required this.onTap,
    this.isDelete = false,
    this.enabled = true,
  });

  @override
  State<_NumKey> createState() => _NumKeyState();
}

class _NumKeyState extends State<_NumKey>
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
      onTapDown: widget.enabled ? (_) => _ctrl.forward() : null,
      onTapUp: widget.enabled
          ? (_) {
              _ctrl.reverse();
              widget.onTap();
            }
          : null,
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
              color: Colors.white.withValues(
                  alpha: widget.isDelete ? 0.06 : 0.12),
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

// ── Logout confirm sheet ───────────────────────────────────────────────────────
class _LogoutConfirmSheet extends StatelessWidget {
  final VoidCallback onConfirm;
  const _LogoutConfirmSheet({required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      decoration: BoxDecoration(
        color: const Color(0xFF0F2A1A),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.logout_rounded,
                color: AppColors.danger, size: 24),
          ),
          const SizedBox(height: 16),
          Text(
            'Sign Out?',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You will need to log in again to access the app.',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.5),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.15)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  onConfirm();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.danger,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  'Sign Out',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}
