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
  final _formKey    = GlobalKey<FormState>();
  final _emailCtrl  = TextEditingController();
  final _passCtrl   = TextEditingController();
  final _emailFocus = FocusNode();
  final _passFocus  = FocusNode();
  bool _obscure  = true;
  bool _loading  = false;
  String? _error;

  late AnimationController _entryCtrl;
  late AnimationController _shakeCtrl;
  late Animation<double>   _headerSlide;
  late Animation<double>   _headerFade;
  late Animation<double>   _formSlide;
  late Animation<double>   _formFade;
  late Animation<double>   _shakeAnim;

  @override
  void initState() {
    super.initState();

    _entryCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1100));
    _headerFade = CurvedAnimation(parent: _entryCtrl,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut));
    _headerSlide = Tween<double>(begin: 30, end: 0).animate(
        CurvedAnimation(parent: _entryCtrl,
            curve: const Interval(0.0, 0.55, curve: Curves.easeOutCubic)));
    _formFade = CurvedAnimation(parent: _entryCtrl,
        curve: const Interval(0.35, 0.85, curve: Curves.easeOut));
    _formSlide = Tween<double>(begin: 40, end: 0).animate(
        CurvedAnimation(parent: _entryCtrl,
            curve: const Interval(0.35, 1.0, curve: Curves.easeOutCubic)));
    _shakeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 480));
    _shakeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -10.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -10.0, end: 10.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10.0, end: -7.0),  weight: 2),
      TweenSequenceItem(tween: Tween(begin: -7.0, end: 7.0),   weight: 2),
      TweenSequenceItem(tween: Tween(begin: 7.0, end: 0.0),    weight: 1),
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
              : const PinSetupScreen(canDismiss: false, replaceWithHome: true),
          transitionDuration: const Duration(milliseconds: 500),
          transitionsBuilder: (_, a, __, child) => FadeTransition(
              opacity: CurvedAnimation(parent: a, curve: Curves.easeOut),
              child: child),
        ));
      } else {
        HapticFeedback.heavyImpact();
        final code = res['code']?.toString() ?? '';
        if (code == 'subscription_expired') {
          // Show a non-dismissable dialog for subscription expiry
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(children: [
                const Icon(Icons.warning_amber_rounded, color: Color(0xFFF4A261), size: 28),
                const SizedBox(width: 10),
                const Expanded(child: Text('Subscription Expired',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
              ]),
              content: Text(res['error'] ?? 'Your subscription has expired. Please renew to continue.',
                  style: const TextStyle(fontSize: 14, height: 1.5)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK', style: TextStyle(color: Color(0xFF0F2D1A), fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          );
        } else {
          setState(() => _error = res['error'] ?? 'Invalid email or password.');
          _shakeCtrl.forward(from: 0);
        }
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
    final short = MediaQuery.of(context).size.height < 680;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _dismissKeyboard,
      child: Scaffold(
        backgroundColor: const Color(0xFF060E09),
        resizeToAvoidBottomInset: true,
        body: Stack(children: [
          // Full-screen geometric background
          Positioned.fill(child: CustomPaint(painter: _CorporateBgPainter())),

          SafeArea(
            child: CustomScrollView(
              physics: const ClampingScrollPhysics(),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [
                // ── Header brand area ──────────────────────────────────────
                SliverToBoxAdapter(
                  child: AnimatedBuilder(
                    animation: _entryCtrl,
                    builder: (_, child) => Opacity(
                      opacity: _headerFade.value.clamp(0.0, 1.0),
                      child: Transform.translate(
                        offset: Offset(0, _headerSlide.value),
                        child: child),
                    ),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(28, short ? 24 : 36, 28, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                width: 48, height: 48,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF2D6A4F), Color(0xFF1B4332)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: const Color(0xFF40916C).withValues(alpha: 0.5),
                                    width: 1),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF2D6A4F).withValues(alpha: 0.4),
                                      blurRadius: 20, offset: const Offset(0, 6)),
                                  ],
                                ),
                                child: Center(
                                  child: Text('M',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 22, fontWeight: FontWeight.w900,
                                      color: Colors.white)),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.1)),
                                ),
                                child: Text('Enterprise Edition',
                                  style: GoogleFonts.inter(
                                    fontSize: 10, fontWeight: FontWeight.w700,
                                    color: Colors.white.withValues(alpha: 0.5),
                                    letterSpacing: 0.8)),
                              ),
                            ],
                          ),

                          SizedBox(height: short ? 28 : 44),

                          Text('MDSPro',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: short ? 32 : 40,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: -1.5,
                              height: 1.0)),
                          const SizedBox(height: 6),
                          Row(children: [
                            Container(
                              width: 24, height: 2,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFF4A261), Color(0xFFD97706)]),
                                borderRadius: BorderRadius.circular(1)),
                            ),
                            const SizedBox(width: 10),
                            Text('Shop Management System',
                              style: GoogleFonts.inter(
                                fontSize: 12, fontWeight: FontWeight.w500,
                                color: Colors.white.withValues(alpha: 0.4),
                                letterSpacing: 0.5)),
                          ]),

                          SizedBox(height: short ? 20 : 32),

                          Text('Sign in to your account',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: short ? 20 : 24,
                              fontWeight: FontWeight.w800,
                              color: Colors.white.withValues(alpha: 0.92),
                              letterSpacing: -0.5)),
                          const SizedBox(height: 6),
                          Text('Enter your credentials to continue',
                            style: GoogleFonts.inter(
                              fontSize: 13, fontWeight: FontWeight.w400,
                              color: Colors.white.withValues(alpha: 0.35))),

                          SizedBox(height: short ? 16 : 24),
                        ],
                      ),
                    ),
                  ),
                ),

                // ── Form card — fills remaining viewport height ─────────────
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: AnimatedBuilder(
                    animation: _entryCtrl,
                    builder: (_, child) => Opacity(
                      opacity: _formFade.value.clamp(0.0, 1.0),
                      child: Transform.translate(
                        offset: Offset(0, _formSlide.value),
                        child: child),
                    ),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFAFAFC),
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(28)),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x28000000),
                            blurRadius: 40,
                            offset: Offset(0, -12)),
                        ],
                      ),
                      child: AnimatedBuilder(
                        animation: _shakeAnim,
                        builder: (_, child) => Transform.translate(
                          offset: Offset(_shakeAnim.value, 0),
                          child: child),
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            32, short ? 24 : 32, 32, 28),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Pill handle
                                Center(
                                  child: Container(
                                    width: 40, height: 4,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1B4332).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(2))),
                                ),
                                SizedBox(height: short ? 20 : 28),

                                // Error banner
                                if (_error != null) ...[
                                  _ErrorBanner(message: _error!),
                                  const SizedBox(height: 16),
                                ],

                                // Email field
                                _Field(
                                  controller: _emailCtrl,
                                  focusNode: _emailFocus,
                                  label: 'Email Address',
                                  hint: 'Enter your email',
                                  icon: Icons.alternate_email_rounded,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  onFieldSubmitted: (_) =>
                                      FocusScope.of(context).requestFocus(_passFocus),
                                  validator: (v) =>
                                      (v?.trim().isEmpty ?? true) ? 'Email is required' : null,
                                ),
                                SizedBox(height: short ? 12 : 16),

                                // Password field
                                _Field(
                                  controller: _passCtrl,
                                  focusNode: _passFocus,
                                  label: 'Password',
                                  hint: '••••••••',
                                  icon: Icons.lock_outline_rounded,
                                  obscureText: _obscure,
                                  textInputAction: TextInputAction.done,
                                  onFieldSubmitted: (_) => _submit(),
                                  suffix: GestureDetector(
                                    onTap: () => setState(() => _obscure = !_obscure),
                                    child: Padding(
                                      padding: const EdgeInsets.only(right: 16),
                                      child: Icon(
                                        _obscure
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                        size: 19,
                                        color: const Color(0xFF6B7280)),
                                    ),
                                  ),
                                  validator: (v) =>
                                      (v?.isEmpty ?? true) ? 'Password is required' : null,
                                ),

                                SizedBox(height: short ? 20 : 28),

                                // Sign in CTA
                                _SignInButton(loading: _loading, onTap: _loading ? null : _submit),

                                SizedBox(height: short ? 14 : 18),

                                // Register link
                                GestureDetector(
                                  onTap: () => Navigator.push(context,
                                      MaterialPageRoute(
                                          builder: (_) => const RegisterScreen())),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    child: Center(
                                      child: RichText(
                                        text: TextSpan(
                                          style: GoogleFonts.inter(
                                            fontSize: 13, color: const Color(0xFF9CA3AF)),
                                          children: [
                                            const TextSpan(text: 'New here? '),
                                            TextSpan(
                                              text: 'Create account',
                                              style: GoogleFonts.inter(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.primary)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                                SizedBox(height: short ? 12 : 20),

                                // Trust row
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _Trust(Icons.verified_outlined,
                                      'Secure', const Color(0xFF2D6A4F)),
                                    _Separator(),
                                    _Trust(Icons.business_outlined,
                                      'Multi-branch', const Color(0xFF1E40AF)),
                                    _Separator(),
                                    _Trust(Icons.language_outlined,
                                      'mdspro.co.tz', const Color(0xFF9CA3AF)),
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
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Premium input field ───────────────────────────────────────────────────────
class _Field extends StatefulWidget {
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

  const _Field({
    required this.controller, required this.focusNode,
    required this.label, required this.hint, required this.icon,
    this.obscureText = false, this.keyboardType,
    this.textInputAction, this.onFieldSubmitted,
    this.suffix, this.validator,
  });

  @override
  State<_Field> createState() => _FieldState();
}

class _FieldState extends State<_Field> with SingleTickerProviderStateMixin {
  bool _focused = false;
  late AnimationController _ac;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(vsync: this, duration: const Duration(milliseconds: 180));
    widget.focusNode.addListener(() {
      final f = widget.focusNode.hasFocus;
      setState(() => _focused = f);
      f ? _ac.forward() : _ac.reverse();
    });
  }

  @override
  void dispose() { _ac.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final accent   = const Color(0xFF1B4332);
    final bdColor  = _focused ? accent : const Color(0xFFE5E7EB);
    final iconClr  = _focused ? accent : const Color(0xFF9CA3AF);
    final bgColor  = _focused ? accent.withValues(alpha: 0.02) : Colors.white;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(widget.label,
          style: GoogleFonts.inter(
            fontSize: 11, fontWeight: FontWeight.w700,
            color: _focused ? accent : const Color(0xFF6B7280),
            letterSpacing: 0.3)),
        const Spacer(),
      ]),
      const SizedBox(height: 8),
      AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: bdColor, width: _focused ? 1.8 : 1.2),
          boxShadow: _focused ? [BoxShadow(
            color: accent.withValues(alpha: 0.06),
            blurRadius: 10, offset: const Offset(0, 3))] : [],
        ),
        child: Row(children: [
          const SizedBox(width: 14),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            child: Icon(widget.icon, size: 18, color: iconClr),
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
                color: const Color(0xFF111827)),
              decoration: InputDecoration(
                hintText: widget.hint,
                hintStyle: GoogleFonts.inter(
                  fontSize: 14, fontWeight: FontWeight.w400,
                  color: const Color(0xFFD1D5DB)),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                filled: true,
                fillColor: Colors.transparent,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                isDense: false,
                errorStyle: const TextStyle(height: 0.01, fontSize: 0),
              ),
            ),
          ),
          if (widget.suffix != null) widget.suffix!,
        ]),
      ),
    ]);
  }
}

// ── Corporate sign-in button ─────────────────────────────────────────────────
class _SignInButton extends StatelessWidget {
  final bool loading;
  final VoidCallback? onTap;
  const _SignInButton({required this.loading, this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 54,
      decoration: BoxDecoration(
        gradient: loading ? null : const LinearGradient(
          colors: [Color(0xFF1B4332), Color(0xFF0F2D1A), Color(0xFF2D6A4F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight),
        color: loading ? const Color(0xFF1B4332) : null,
        borderRadius: BorderRadius.circular(14),
        boxShadow: loading ? [] : [
          BoxShadow(
            color: const Color(0xFF1B4332).withValues(alpha: 0.45),
            blurRadius: 20, offset: const Offset(0, 8)),
          BoxShadow(
            color: const Color(0xFF1B4332).withValues(alpha: 0.15),
            blurRadius: 40, spreadRadius: 2, offset: const Offset(0, 4)),
        ],
      ),
      child: Center(
        child: loading
            ? const SizedBox(width: 22, height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5, color: Colors.white))
            : Row(mainAxisSize: MainAxisSize.min, children: [
                Text('Sign In',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16, fontWeight: FontWeight.w800,
                    color: Colors.white, letterSpacing: 0.2)),
                const SizedBox(width: 12),
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.arrow_forward_rounded,
                    color: Colors.white, size: 15),
                ),
              ]),
      ),
    ),
  );
}

// ── Trust badge ───────────────────────────────────────────────────────────────
class _Trust extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _Trust(this.icon, this.label, this.color);

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, size: 11, color: color.withValues(alpha: 0.6)),
    const SizedBox(width: 4),
    Text(label, style: GoogleFonts.inter(
      fontSize: 10, fontWeight: FontWeight.w600,
      color: color.withValues(alpha: 0.6))),
  ]);
}

class _Separator extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: 1, height: 11,
    margin: const EdgeInsets.symmetric(horizontal: 10),
    color: const Color(0xFFE5E7EB));
}

// ── Error banner ──────────────────────────────────────────────────────────────
class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF1F2),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFFECACA)),
    ),
    child: Row(children: [
      const Icon(Icons.error_outline_rounded,
        color: Color(0xFFDC2626), size: 16),
      const SizedBox(width: 10),
      Expanded(
        child: Text(message, style: GoogleFonts.inter(
          fontSize: 13, fontWeight: FontWeight.w500,
          color: const Color(0xFFDC2626)))),
    ]),
  );
}

// ── Corporate background painter ──────────────────────────────────────────────
class _CorporateBgPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();

    // Deep dark background
    paint.shader = const LinearGradient(
      colors: [Color(0xFF060E09), Color(0xFF0B1D12), Color(0xFF071510)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Offset.zero & size, paint);

    // Accent glow — top right
    paint.shader = RadialGradient(
      colors: [
        const Color(0xFF2D6A4F).withValues(alpha: 0.28),
        Colors.transparent,
      ],
    ).createShader(Rect.fromCircle(
      center: Offset(size.width * 0.95, -size.height * 0.02),
      radius: size.width * 0.65));
    canvas.drawCircle(
      Offset(size.width * 0.95, -size.height * 0.02),
      size.width * 0.65, paint);

    // Accent glow — bottom left
    paint.shader = RadialGradient(
      colors: [
        const Color(0xFF1B4332).withValues(alpha: 0.20),
        Colors.transparent,
      ],
    ).createShader(Rect.fromCircle(
      center: Offset(-size.width * 0.15, size.height * 0.42),
      radius: size.width * 0.55));
    canvas.drawCircle(
      Offset(-size.width * 0.15, size.height * 0.42),
      size.width * 0.55, paint);

    // Horizontal rule lines — corporate structure feel
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.03)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    for (var i = 1; i <= 6; i++) {
      final y = size.height * 0.05 * i;
      canvas.drawLine(
        Offset(size.width * 0.05, y),
        Offset(size.width * 0.55, y),
        linePaint);
    }

    // Fine dot grid — upper portion only
    final dotPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.03)
      ..style = PaintingStyle.fill;
    const spacing = 26.0;
    for (var x = spacing; x < size.width; x += spacing) {
      for (var y = spacing; y < size.height * 0.50; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.0, dotPaint);
      }
    }

    // Amber accent streak
    final streakPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Colors.transparent, Color(0x28F4A261), Colors.transparent],
      ).createShader(Rect.fromLTWH(0, size.height * 0.22, size.width, 1))
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(size.width * 0.0, size.height * 0.22),
      Offset(size.width * 1.0, size.height * 0.22),
      streakPaint);
  }

  @override
  bool shouldRepaint(_) => false;
}
