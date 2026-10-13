import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../services/pin_service.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';
import 'pin_setup_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey   = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  final _emailFocus = FocusNode();
  final _passFocus  = FocusNode();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  late AnimationController _entryCtrl;
  late AnimationController _shakeCtrl;
  late Animation<double>   _logoScale;
  late Animation<double>   _logoFade;
  late Animation<Offset>   _cardSlide;
  late Animation<double>   _cardFade;
  late Animation<double>   _shakeAnim;

  @override
  void initState() {
    super.initState();

    _entryCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _logoScale = Tween<double>(begin: 0.7, end: 1.0).animate(
        CurvedAnimation(parent: _entryCtrl,
            curve: const Interval(0.0, 0.55, curve: Curves.elasticOut)));
    _logoFade = CurvedAnimation(parent: _entryCtrl,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut));
    _cardSlide = Tween<Offset>(begin: const Offset(0, 1.0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entryCtrl,
            curve: const Interval(0.25, 1.0, curve: Curves.easeOutCubic)));
    _cardFade = CurvedAnimation(parent: _entryCtrl,
        curve: const Interval(0.25, 0.75, curve: Curves.easeOut));

    _shakeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _shakeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -8.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: -6.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -6.0, end: 6.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 6.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.easeInOut));

    _entryCtrl.forward();
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _shakeCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _emailFocus.dispose();
    _passFocus.dispose();
    super.dispose();
  }

  void _dismissKeyboard() => FocusScope.of(context).unfocus();

  Future<void> _submit() async {
    _dismissKeyboard();
    if (!_formKey.currentState!.validate()) {
      _shakeCtrl.forward(from: 0);
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ApiService.login(
          _emailCtrl.text.trim(), _passCtrl.text);
      if (!mounted) return;
      if (res['ok'] == true) {
        HapticFeedback.mediumImpact();
        final hasPin = await PinService.hasPin();
        if (!mounted) return;
        Navigator.of(context).pushReplacement(PageRouteBuilder(
          pageBuilder: (_, __, ___) => hasPin
              ? const HomeScreen()
              : const PinSetupScreen(
                  canDismiss: false, replaceWithHome: true),
          transitionDuration: const Duration(milliseconds: 500),
          transitionsBuilder: (_, a, __, child) => FadeTransition(
              opacity: CurvedAnimation(parent: a, curve: Curves.easeOut),
              child: child),
        ));
      } else {
        HapticFeedback.heavyImpact();
        setState(() => _error = res['error'] ?? 'Invalid email or password.');
        _shakeCtrl.forward(from: 0);
      }
    } catch (_) {
      setState(() => _error = 'Connection error. Check your network.');
      _shakeCtrl.forward(from: 0);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final short = size.height < 700;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _dismissKeyboard,
      child: Scaffold(
        backgroundColor: const Color(0xFF061410),
        resizeToAvoidBottomInset: true,
        body: Stack(children: [
          // ── Background ───────────────────────────────────────────────────
          Positioned.fill(child: CustomPaint(painter: _BgPainter())),

          SafeArea(
            child: Column(children: [
              // ── Brand ────────────────────────────────────────────────────
              Flexible(
                flex: short ? 2 : 3,
                child: FadeTransition(
                  opacity: _logoFade,
                  child: ScaleTransition(
                    scale: _logoScale,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: short ? 60 : 76,
                            height: short ? 60 : 76,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [Color(0xFFF4A261), Color(0xFFD97706)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.accent.withValues(alpha: 0.5),
                                  blurRadius: 32,
                                  spreadRadius: 2,
                                  offset: const Offset(0, 8)),
                              ],
                            ),
                            child: Center(
                              child: Text('M',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: short ? 28 : 34,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white)),
                            ),
                          ),
                          SizedBox(height: short ? 10 : 16),
                          Text('MDSPro',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: short ? 22 : 28,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: -0.8)),
                          const SizedBox(height: 4),
                          Text('Shop Management System',
                            style: GoogleFonts.inter(
                              fontSize: 12, fontWeight: FontWeight.w400,
                              color: Colors.white.withValues(alpha: 0.35),
                              letterSpacing: 0.3)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // ── Form card ─────────────────────────────────────────────────
              Flexible(
                flex: short ? 5 : 6,
                child: SlideTransition(
                  position: _cardSlide,
                  child: FadeTransition(
                    opacity: _cardFade,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x33000000),
                            blurRadius: 40,
                            offset: Offset(0, -8)),
                        ],
                      ),
                      child: SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: EdgeInsets.fromLTRB(
                            28, short ? 20 : 28, 28, 24),
                        child: AnimatedBuilder(
                          animation: _shakeAnim,
                          builder: (_, child) => Transform.translate(
                            offset: Offset(_shakeAnim.value, 0),
                            child: child,
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Drag handle
                                Center(
                                  child: Container(
                                    width: 36, height: 4,
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(2))),
                                ),
                                SizedBox(height: short ? 16 : 24),

                                Text('Welcome back',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: short ? 22 : 26,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.textPrimary,
                                    letterSpacing: -0.6, height: 1.1)),
                                const SizedBox(height: 4),
                                Text('Sign in to your MDSPro account',
                                  style: GoogleFonts.inter(
                                    fontSize: 13, fontWeight: FontWeight.w400,
                                    color: AppColors.textMuted)),

                                SizedBox(height: short ? 20 : 28),

                                // Error banner
                                if (_error != null) ...[
                                  _ErrorBanner(message: _error!),
                                  const SizedBox(height: 16),
                                ],

                                // Email field
                                _CardField(
                                  controller: _emailCtrl,
                                  focusNode: _emailFocus,
                                  label: 'Email address',
                                  hint: 'your@email.com',
                                  icon: Icons.alternate_email_rounded,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  onFieldSubmitted: (_) =>
                                      FocusScope.of(context).requestFocus(_passFocus),
                                  validator: (v) =>
                                      (v?.trim().isEmpty ?? true)
                                          ? 'Email is required'
                                          : null,
                                ),
                                SizedBox(height: short ? 12 : 16),

                                // Password field
                                _CardField(
                                  controller: _passCtrl,
                                  focusNode: _passFocus,
                                  label: 'Password',
                                  hint: '••••••••',
                                  icon: Icons.lock_outline_rounded,
                                  obscureText: _obscure,
                                  textInputAction: TextInputAction.done,
                                  onFieldSubmitted: (_) => _submit(),
                                  suffix: GestureDetector(
                                    onTap: () =>
                                        setState(() => _obscure = !_obscure),
                                    child: Padding(
                                      padding: const EdgeInsets.only(right: 16),
                                      child: Icon(
                                        _obscure
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                        size: 20,
                                        color: AppColors.textMuted),
                                    ),
                                  ),
                                  validator: (v) =>
                                      (v?.isEmpty ?? true)
                                          ? 'Password is required'
                                          : null,
                                ),

                                SizedBox(height: short ? 24 : 32),

                                // Sign in button
                                _SignInButton(
                                  loading: _loading,
                                  onTap: _loading ? null : _submit,
                                ),

                                SizedBox(height: short ? 16 : 20),

                                // Register CTA
                                GestureDetector(
                                  onTap: () => Navigator.push(context,
                                      MaterialPageRoute(
                                          builder: (_) => const RegisterScreen())),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    alignment: Alignment.center,
                                    child: RichText(
                                      text: TextSpan(
                                        style: GoogleFonts.inter(
                                            fontSize: 13, fontWeight: FontWeight.w400,
                                            color: AppColors.textMuted),
                                        children: [
                                          const TextSpan(text: "New to MDSPro? "),
                                          TextSpan(
                                            text: 'Create your shop →',
                                            style: GoogleFonts.inter(
                                                fontSize: 13, fontWeight: FontWeight.w700,
                                                color: AppColors.primary)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),

                                SizedBox(height: short ? 8 : 16),

                                // Footer row
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _TrustBadge(Icons.shield_outlined,
                                        'Encrypted', AppColors.success),
                                    Container(
                                      width: 1, height: 12,
                                      margin: const EdgeInsets.symmetric(horizontal: 12),
                                      color: Colors.black.withValues(alpha: 0.1)),
                                    _TrustBadge(Icons.store_outlined,
                                        'Multi-tenant', AppColors.info),
                                    Container(
                                      width: 1, height: 12,
                                      margin: const EdgeInsets.symmetric(horizontal: 12),
                                      color: Colors.black.withValues(alpha: 0.1)),
                                    _TrustBadge(Icons.language_outlined,
                                        'mdspro.co.tz', AppColors.textMuted),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ── Card-style input field ────────────────────────────────────────────────────
class _CardField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String label, hint;
  final IconData icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;
  final Widget? suffix;
  final String? Function(String?)? validator;

  const _CardField({
    required this.controller,
    required this.focusNode,
    required this.label,
    required this.hint,
    required this.icon,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.onFieldSubmitted,
    this.suffix,
    this.validator,
  });

  @override
  State<_CardField> createState() => _CardFieldState();
}

class _CardFieldState extends State<_CardField>
    with SingleTickerProviderStateMixin {
  bool _focused = false;
  late AnimationController _borderCtrl;
  late Animation<double> _borderAnim;

  @override
  void initState() {
    super.initState();
    _borderCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 200));
    _borderAnim = CurvedAnimation(parent: _borderCtrl, curve: Curves.easeOut);
    widget.focusNode.addListener(() {
      final f = widget.focusNode.hasFocus;
      setState(() => _focused = f);
      f ? _borderCtrl.forward() : _borderCtrl.reverse();
    });
  }

  @override
  void dispose() {
    _borderCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = _focused
        ? AppColors.primary
        : const Color(0xFFE5E7EB);
    final iconColor = _focused
        ? AppColors.primary
        : const Color(0xFF9CA3AF);
    final bgColor = _focused
        ? AppColors.primary.withValues(alpha: 0.03)
        : const Color(0xFFF9FAFB);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(widget.label,
        style: GoogleFonts.inter(
          fontSize: 12, fontWeight: FontWeight.w700,
          color: _focused ? AppColors.primary : AppColors.textMuted,
          letterSpacing: 0.1)),
      const SizedBox(height: 8),
      AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: borderColor,
            width: _focused ? 1.8 : 1.2,
          ),
          boxShadow: _focused ? [BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )] : [],
        ),
        child: Row(children: [
          const SizedBox(width: 14),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            child: Icon(widget.icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextFormField(
              controller: widget.controller,
              focusNode: widget.focusNode,
              obscureText: widget.obscureText,
              keyboardType: widget.keyboardType,
              textInputAction: widget.textInputAction,
              onFieldSubmitted: widget.onFieldSubmitted,
              validator: widget.validator,
              style: GoogleFonts.inter(
                fontSize: 15, fontWeight: FontWeight.w500,
                color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: widget.hint,
                hintStyle: GoogleFonts.inter(
                  fontSize: 14, fontWeight: FontWeight.w400,
                  color: const Color(0xFFB4BAC5)),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                filled: true,
                fillColor: Colors.transparent,
                contentPadding: const EdgeInsets.symmetric(
                    vertical: 14, horizontal: 0),
                isDense: false,
                errorStyle: const TextStyle(height: 0.01, fontSize: 0),
              ),
            ),
          ),
          if (widget.suffix != null) widget.suffix!,
        ]),
      ),
      // Inline validation error
      Builder(builder: (ctx) {
        final form = Form.of(ctx);
        return const SizedBox.shrink();
      }),
    ]);
  }
}

// ── Sign in button ────────────────────────────────────────────────────────────
class _SignInButton extends StatelessWidget {
  final bool loading;
  final VoidCallback? onTap;
  const _SignInButton({required this.loading, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 56,
        decoration: BoxDecoration(
          gradient: loading
              ? null
              : const LinearGradient(
                  colors: [Color(0xFF0D2818), Color(0xFF0F2D1A), Color(0xFF1a4730)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
          color: loading ? const Color(0xFF1a3325) : null,
          borderRadius: BorderRadius.circular(16),
          boxShadow: loading
              ? []
              : [BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.40),
                  blurRadius: 18,
                  offset: const Offset(0, 7))],
        ),
        child: Center(
          child: loading
              ? const SizedBox(
                  width: 22, height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: Colors.white))
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Sign In',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16, fontWeight: FontWeight.w800,
                        color: Colors.white, letterSpacing: 0.3)),
                    const SizedBox(width: 10),
                    Container(
                      width: 26, height: 26,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.arrow_forward_rounded,
                        color: Colors.white, size: 15),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// ── Trust badge ───────────────────────────────────────────────────────────────
class _TrustBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _TrustBadge(this.icon, this.label, this.color);

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 12, color: color.withValues(alpha: 0.65)),
      const SizedBox(width: 4),
      Text(label,
        style: GoogleFonts.inter(
          fontSize: 10, fontWeight: FontWeight.w600,
          color: color.withValues(alpha: 0.65))),
    ],
  );
}

// ── Background painter ────────────────────────────────────────────────────────
class _BgPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();

    // Base gradient
    paint.shader = const LinearGradient(
      colors: [Color(0xFF061410), Color(0xFF0F2D1A), Color(0xFF0a2016)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Offset.zero & size, paint);

    // Orb top-right
    paint.shader = RadialGradient(
      colors: [
        const Color(0xFF1E6B3F).withValues(alpha: 0.5),
        Colors.transparent,
      ],
    ).createShader(Rect.fromCircle(
        center: Offset(size.width * 0.88, size.height * 0.04),
        radius: size.width * 0.45));
    canvas.drawCircle(
        Offset(size.width * 0.88, size.height * 0.04),
        size.width * 0.45, paint);

    // Orb bottom-left
    paint.shader = RadialGradient(
      colors: [
        const Color(0xFF0D4025).withValues(alpha: 0.6),
        Colors.transparent,
      ],
    ).createShader(Rect.fromCircle(
        center: Offset(-size.width * 0.1, size.height * 0.35),
        radius: size.width * 0.5));
    canvas.drawCircle(
        Offset(-size.width * 0.1, size.height * 0.35),
        size.width * 0.5, paint);

    // Subtle grid dots
    final dotPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.025)
      ..style = PaintingStyle.fill;
    const spacing = 28.0;
    for (var x = spacing; x < size.width; x += spacing) {
      for (var y = spacing; y < size.height * 0.55; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.2, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

// ── Error banner ──────────────────────────────────────────────────────────────
class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: AppColors.dangerBg,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.danger.withValues(alpha: 0.25)),
    ),
    child: Row(children: [
      const Icon(Icons.error_outline_rounded,
          color: AppColors.danger, size: 16),
      const SizedBox(width: 10),
      Expanded(
        child: Text(message,
          style: GoogleFonts.inter(
            fontSize: 13, fontWeight: FontWeight.w500,
            color: AppColors.danger))),
    ]),
  );
}
