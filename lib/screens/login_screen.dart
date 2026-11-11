import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../services/pin_service.dart';
import '../utils/responsive.dart';
import '../utils/l10n_ext.dart';
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
  final _formKey      = GlobalKey<FormState>();
  final _emailCtrl    = TextEditingController();
  final _passCtrl     = TextEditingController();
  final _emailFocus   = FocusNode();
  final _passFocus    = FocusNode();
  final _scrollCtrl   = ScrollController();
  final _emailKey     = GlobalKey();
  final _passKey      = GlobalKey();

  bool _obscure  = true;
  bool _loading  = false;
  String? _error;

  late AnimationController _entryCtrl;
  late AnimationController _shakeCtrl;
  late AnimationController _bgCtrl;
  late Animation<double> _shakeAnim;
  late Animation<double> _entryFade;
  late Animation<Offset> _cardSlide;

  @override
  void initState() {
    super.initState();

    _bgCtrl = AnimationController(
      vsync: this, duration: const Duration(seconds: 8))
      ..repeat(reverse: true);

    _entryCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 800));
    _entryFade  = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _cardSlide  = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));

    _shakeCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 500));
    _shakeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -12.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -12.0, end: 12.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 12.0, end: -8.0),  weight: 2),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0),   weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: 0.0),    weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.easeInOut));

    _entryCtrl.forward();

    // Auto-scroll when keyboard opens on a focused field
    _emailFocus.addListener(_onEmailFocus);
    _passFocus.addListener(_onPassFocus);
  }

  void _onEmailFocus() {
    if (_emailFocus.hasFocus) _scrollToKey(_emailKey);
  }

  void _onPassFocus() {
    if (_passFocus.hasFocus) _scrollToKey(_passKey);
  }

  void _scrollToKey(GlobalKey key) {
    Future.delayed(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      final ctx = key.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(ctx,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
          alignment: 0.5,
        );
      }
    });
  }

  @override
  void dispose() {
    _emailFocus.removeListener(_onEmailFocus);
    _passFocus.removeListener(_onPassFocus);
    _bgCtrl.dispose();
    _entryCtrl.dispose();
    _shakeCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _emailFocus.dispose();
    _passFocus.dispose();
    _scrollCtrl.dispose();
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
          if (!mounted) return;
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => _SubExpiredDialog(message: res['error']),
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
    final screenH = MediaQuery.of(context).size.height;

    return GestureDetector(
      onTap: _dismissKeyboard,
      child: Scaffold(
        backgroundColor: const Color(0xFF040C07),
        resizeToAvoidBottomInset: true,
        body: Stack(children: [
          // ── Animated mesh background (always full-screen height) ───────
          SizedBox(
            height: screenH,
            width: double.infinity,
            child: AnimatedBuilder(
              animation: _bgCtrl,
              builder: (_, __) => CustomPaint(
                painter: _MeshBgPainter(_bgCtrl.value)),
            ),
          ),

          // ── Floating orbs ──────────────────────────────────────────────
          Positioned(
            top: -60, right: -50,
            child: AnimatedBuilder(
              animation: _bgCtrl,
              builder: (_, __) => Container(
                width: 220, height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    const Color(0xFF2D6A4F).withValues(
                      alpha: 0.16 + 0.07 * math.sin(_bgCtrl.value * math.pi)),
                    Colors.transparent,
                  ]),
                ),
              ),
            ),
          ),
          Positioned(
            top: screenH * 0.32, left: -70,
            child: AnimatedBuilder(
              animation: _bgCtrl,
              builder: (_, __) => Container(
                width: 160, height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    const Color(0xFFF4A261).withValues(
                      alpha: 0.06 + 0.03 * math.cos(_bgCtrl.value * math.pi)),
                    Colors.transparent,
                  ]),
                ),
              ),
            ),
          ),

          // ── Scrollable content ─────────────────────────────────────────
          Builder(builder: (ctx) {
            final resp = Responsive.of(ctx);

            // ── Shared: form card body ─────────────────────────────────
            Widget formCard({bool forTablet = false}) => Container(
              margin: forTablet ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 40, offset: const Offset(0, 16)),
                ],
              ),
              child: AnimatedBuilder(
                animation: _shakeAnim,
                builder: (_, child) => Transform.translate(
                  offset: Offset(_shakeAnim.value, 0),
                  child: child),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Center(
                          child: Container(
                            width: 32, height: 4,
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F2D1A).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(2)))),
                        const SizedBox(height: 16),
                        Text(context.l10n.loginTitle,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 21, fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F2D1A),
                            letterSpacing: -0.4)),
                        const SizedBox(height: 2),
                        Text(context.l10n.loginSubtitle,
                          style: GoogleFonts.inter(
                            fontSize: 13, color: const Color(0xFF6B7280))),
                        const SizedBox(height: 18),
                        if (_error != null) ...[
                          _ErrorBanner(message: _error!),
                          const SizedBox(height: 14),
                        ],
                        _InputField(
                          key: _emailKey,
                          controller: _emailCtrl,
                          focusNode: _emailFocus,
                          label: context.l10n.email,
                          hint: context.l10n.emailHint,
                          icon: Icons.alternate_email_rounded,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          onSubmitted: (_) =>
                            FocusScope.of(context).requestFocus(_passFocus),
                          validator: (v) =>
                            (v?.trim().isEmpty ?? true)
                              ? context.l10n.email : null,
                        ),
                        const SizedBox(height: 12),
                        _InputField(
                          key: _passKey,
                          controller: _passCtrl,
                          focusNode: _passFocus,
                          label: context.l10n.password,
                          hint: '••••••••',
                          icon: Icons.lock_outline_rounded,
                          obscure: _obscure,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _submit(),
                          suffixIcon: GestureDetector(
                            onTap: () => setState(() => _obscure = !_obscure),
                            child: Padding(
                              padding: const EdgeInsets.only(right: 16),
                              child: Icon(
                                _obscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                                size: 20,
                                color: const Color(0xFF9CA3AF)),
                            ),
                          ),
                          validator: (v) =>
                            (v?.isEmpty ?? true)
                              ? context.l10n.password : null,
                        ),
                        const SizedBox(height: 20),
                        _SignInButton(
                          loading: _loading,
                          onTap: _loading ? null : _submit),
                        const SizedBox(height: 16),
                        Row(children: [
                          Expanded(child: Divider(
                            color: Colors.black.withValues(alpha: 0.07), height: 1)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text('or',
                              style: GoogleFonts.inter(
                                fontSize: 11, color: const Color(0xFF9CA3AF)))),
                          Expanded(child: Divider(
                            color: Colors.black.withValues(alpha: 0.07), height: 1)),
                        ]),
                        const SizedBox(height: 14),
                        _RegisterLink(onTap: () => Navigator.push(context,
                          MaterialPageRoute(
                            builder: (_) => const RegisterScreen()))),
                        const SizedBox(height: 14),
                        _TrustRow(),
                      ],
                    ),
                  ),
                ),
              ),
            );

            // ── Tablet: split-pane ─────────────────────────────────────
            if (resp.isTablet) {
              return SafeArea(
                child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  // Left brand pane
                  Expanded(
                    flex: 5,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(48, 48, 40, 48),
                      child: FadeTransition(
                        opacity: _entryFade,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [_LogoMark(), _VersionBadge()],
                            ),
                            const SizedBox(height: 36),
                            Stack(clipBehavior: Clip.none, children: [
                              Text('MDSPro',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 56, fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: -2.0, height: 1.0)),
                              Positioned(
                                bottom: -6, left: 2,
                                child: Container(
                                  width: 60, height: 3,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(colors: [
                                      Color(0xFFF4A261), Color(0xFFD97706)]),
                                    borderRadius: BorderRadius.circular(2)))),
                            ]),
                            const SizedBox(height: 14),
                            Text('Shop Management System',
                              style: GoogleFonts.inter(
                                fontSize: 14, fontWeight: FontWeight.w500,
                                color: Colors.white.withValues(alpha: 0.4),
                                letterSpacing: 0.8)),
                            const SizedBox(height: 36),
                            Wrap(spacing: 8, runSpacing: 10, children: [
                              _FeaturePill(Icons.point_of_sale_rounded, 'POS'),
                              _FeaturePill(Icons.inventory_2_outlined, 'Inventory'),
                              _FeaturePill(Icons.bar_chart_rounded, 'Reports'),
                              _FeaturePill(Icons.store_outlined, 'Multi-branch'),
                            ]),
                            const SizedBox(height: 48),
                            Text('Trusted by hardware stores,\nsupermarkets & retailers.',
                              style: GoogleFonts.inter(
                                fontSize: 13, fontWeight: FontWeight.w500,
                                color: Colors.white.withValues(alpha: 0.22),
                                height: 1.6)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Thin divider
                  Container(width: 1,
                    color: Colors.white.withValues(alpha: 0.06)),
                  // Right form pane
                  SizedBox(
                    width: resp.isMidTablet ? 380 : 440,
                    child: Center(
                      child: SingleChildScrollView(
                        controller: _scrollCtrl,
                        physics: const ClampingScrollPhysics(),
                        keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.symmetric(
                          vertical: 32, horizontal: 28),
                        child: FadeTransition(
                          opacity: _entryFade,
                          child: SlideTransition(
                            position: _cardSlide,
                            child: formCard(forTablet: true),
                          ),
                        ),
                      ),
                    ),
                  ),
                ]),
              );
            }

            // ── Phone: stacked layout ──────────────────────────────────
            return SafeArea(
              child: SingleChildScrollView(
                controller: _scrollCtrl,
                physics: const ClampingScrollPhysics(),
                keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Brand strip
                    FadeTransition(
                      opacity: _entryFade,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [_LogoMark(), _VersionBadge()],
                            ),
                            const SizedBox(height: 24),
                            Stack(clipBehavior: Clip.none, children: [
                              Text('MDSPro',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 40, fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: -1.5, height: 1.0)),
                              Positioned(
                                bottom: -5, left: 2,
                                child: Container(
                                  width: 46, height: 3,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(colors: [
                                      Color(0xFFF4A261), Color(0xFFD97706)]),
                                    borderRadius: BorderRadius.circular(2)))),
                            ]),
                            const SizedBox(height: 10),
                            Text('Shop Management System',
                              style: GoogleFonts.inter(
                                fontSize: 12, fontWeight: FontWeight.w500,
                                color: Colors.white.withValues(alpha: 0.35),
                                letterSpacing: 0.7)),
                            const SizedBox(height: 18),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(children: [
                                _FeaturePill(Icons.point_of_sale_rounded, 'POS'),
                                const SizedBox(width: 6),
                                _FeaturePill(Icons.inventory_2_outlined, 'Inventory'),
                                const SizedBox(width: 6),
                                _FeaturePill(Icons.bar_chart_rounded, 'Reports'),
                                const SizedBox(width: 6),
                                _FeaturePill(Icons.store_outlined, 'Multi-branch'),
                              ]),
                            ),
                            const SizedBox(height: 28),
                          ],
                        ),
                      ),
                    ),
                    // Form card
                    FadeTransition(
                      opacity: _entryFade,
                      child: SlideTransition(
                        position: _cardSlide,
                        child: formCard(),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ]),
      ),
    );
  }
}

// ── Logo mark ─────────────────────────────────────────────────────────────────
class _LogoMark extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: 46, height: 46,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF2D6A4F), Color(0xFF0F2D1A)],
        begin: Alignment.topLeft, end: Alignment.bottomRight),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: const Color(0xFF40916C).withValues(alpha: 0.4), width: 1),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF2D6A4F).withValues(alpha: 0.45),
          blurRadius: 18, offset: const Offset(0, 6)),
      ],
    ),
    child: Stack(children: [
      Positioned.fill(
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            gradient: LinearGradient(colors: [
              Colors.white.withValues(alpha: 0.1),
              Colors.transparent,
            ], begin: Alignment.topLeft, end: Alignment.bottomRight)))),
      Center(
        child: Text('M',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 22, fontWeight: FontWeight.w900,
            color: Colors.white))),
    ]),
  );
}

// ── Version badge ─────────────────────────────────────────────────────────────
class _VersionBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white.withValues(alpha: 0.08))),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 5, height: 5,
        decoration: const BoxDecoration(
          color: Color(0xFF4ADE80), shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Text('v2.0 Enterprise',
        style: GoogleFonts.inter(
          fontSize: 10, fontWeight: FontWeight.w600,
          color: Colors.white.withValues(alpha: 0.4), letterSpacing: 0.4)),
    ]),
  );
}

// ── Feature pill ──────────────────────────────────────────────────────────────
class _FeaturePill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _FeaturePill(this.icon, this.label);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white.withValues(alpha: 0.09))),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: const Color(0xFFF4A261)),
      const SizedBox(width: 5),
      Text(label, style: GoogleFonts.inter(
        fontSize: 10, fontWeight: FontWeight.w600,
        color: Colors.white.withValues(alpha: 0.6))),
    ]),
  );
}

// ── Input field ───────────────────────────────────────────────────────────────
class _InputField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String label, hint;
  final IconData icon;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;

  const _InputField({
    super.key,
    required this.controller, required this.focusNode,
    required this.label, required this.hint, required this.icon,
    this.obscure = false, this.keyboardType,
    this.textInputAction, this.onSubmitted,
    this.suffixIcon, this.validator,
  });

  @override
  State<_InputField> createState() => _InputFieldState();
}

class _InputFieldState extends State<_InputField> {
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    super.dispose();
  }

  void _onFocusChange() {
    if (mounted) setState(() => _focused = widget.focusNode.hasFocus);
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF0F2D1A);
    const green   = Color(0xFF2D6A4F);
    final border  = _focused ? green : const Color(0xFFE5E7EB);
    final iconClr = _focused ? green : const Color(0xFFADB5BD);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: _focused ? green.withValues(alpha: 0.03) : Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: border, width: _focused ? 2.0 : 1.2),
        boxShadow: _focused
          ? [BoxShadow(
              color: green.withValues(alpha: 0.1),
              blurRadius: 10, offset: const Offset(0, 3))]
          : [BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(children: [
        const SizedBox(width: 14),
        Icon(widget.icon, size: 18, color: iconClr),
        const SizedBox(width: 10),
        Expanded(
          child: TextFormField(
            controller: widget.controller,
            focusNode: widget.focusNode,
            obscureText: widget.obscure,
            keyboardType: widget.keyboardType,
            textInputAction: widget.textInputAction,
            onFieldSubmitted: widget.onSubmitted,
            validator: widget.validator,
            style: GoogleFonts.inter(
              fontSize: 14, fontWeight: FontWeight.w500, color: primary),
            decoration: InputDecoration(
              labelText: widget.label,
              labelStyle: GoogleFonts.inter(
                fontSize: 13, fontWeight: FontWeight.w500,
                color: _focused ? green : const Color(0xFF9CA3AF)),
              floatingLabelStyle: GoogleFonts.inter(
                fontSize: 10, fontWeight: FontWeight.w700, color: green),
              hintText: widget.hint,
              hintStyle: GoogleFonts.inter(
                fontSize: 13, color: const Color(0xFFCED4DA)),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              filled: true,
              fillColor: Colors.transparent,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              errorStyle: const TextStyle(height: 0.01, fontSize: 0),
            ),
          ),
        ),
        if (widget.suffixIcon != null) widget.suffixIcon!,
      ]),
    );
  }
}

// ── Sign-in button ────────────────────────────────────────────────────────────
class _SignInButton extends StatefulWidget {
  final bool loading;
  final VoidCallback? onTap;
  const _SignInButton({required this.loading, this.onTap});
  @override
  State<_SignInButton> createState() => _SignInButtonState();
}

class _SignInButtonState extends State<_SignInButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTapDown: (_) => setState(() => _pressed = true),
    onTapUp:   (_) => setState(() => _pressed = false),
    onTapCancel: ()  => setState(() => _pressed = false),
    onTap: widget.onTap,
    child: AnimatedScale(
      scale: _pressed ? 0.97 : 1.0,
      duration: const Duration(milliseconds: 100),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 52,
        decoration: BoxDecoration(
          gradient: widget.loading ? null : const LinearGradient(
            colors: [Color(0xFF2D6A4F), Color(0xFF0F2D1A), Color(0xFF1B4332)],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
          color: widget.loading ? const Color(0xFF1B4332) : null,
          borderRadius: BorderRadius.circular(14),
          boxShadow: widget.loading ? [] : [
            BoxShadow(
              color: const Color(0xFF0F2D1A).withValues(alpha: 0.4),
              blurRadius: 18, offset: const Offset(0, 8)),
          ],
        ),
        child: Stack(alignment: Alignment.center, children: [
          if (!widget.loading)
            Positioned(
              top: 0, left: 0, right: 0,
              child: Container(
                height: 24,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                  gradient: LinearGradient(colors: [
                    Colors.white.withValues(alpha: 0.07),
                    Colors.transparent])))),
          if (widget.loading)
            const SizedBox(width: 22, height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5, color: Colors.white))
          else
            Row(mainAxisSize: MainAxisSize.min, children: [
              Text(context.l10n.signIn,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15, fontWeight: FontWeight.w800,
                  color: Colors.white, letterSpacing: 0.3)),
              const SizedBox(width: 10),
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.arrow_forward_rounded,
                  color: Colors.white, size: 15)),
            ]),
        ]),
      ),
    ),
  );
}

// ── Register link ─────────────────────────────────────────────────────────────
class _RegisterLink extends StatelessWidget {
  final VoidCallback onTap;
  const _RegisterLink({required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F2D1A).withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF0F2D1A).withValues(alpha: 0.08))),
      child: Center(
        child: RichText(
          text: TextSpan(
            style: GoogleFonts.inter(
              fontSize: 12, color: const Color(0xFF6B7280)),
            children: [
              const TextSpan(text: 'New to MDSPro?  '),
              TextSpan(
                text: 'Create an account',
                style: GoogleFonts.inter(
                  fontSize: 12, fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F2D1A))),
            ],
          ),
        ),
      ),
    ),
  );
}

// ── Trust row ─────────────────────────────────────────────────────────────────
class _TrustRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFF3F4F6))),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _TrustItem(Icons.shield_outlined, 'Secure', const Color(0xFF059669)),
        _TrustDivider(),
        _TrustItem(Icons.store_mall_directory_outlined, 'Multi-tenant', const Color(0xFF2563EB)),
        _TrustDivider(),
        _TrustItem(Icons.language_outlined, 'mdspro.co.tz', const Color(0xFF9CA3AF)),
      ],
    ),
  );
}

class _TrustItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _TrustItem(this.icon, this.label, this.color);

  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, size: 16, color: color),
    const SizedBox(height: 3),
    Text(label, style: GoogleFonts.inter(
      fontSize: 9, fontWeight: FontWeight.w600,
      color: color.withValues(alpha: 0.8))),
  ]);
}

class _TrustDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: 1, height: 24,
    color: const Color(0xFFF3F4F6));
}

// ── Error banner ──────────────────────────────────────────────────────────────
class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFFFFF1F2), Color(0xFFFEE2E2)],
        begin: Alignment.topLeft, end: Alignment.bottomRight),
      borderRadius: BorderRadius.circular(11),
      border: Border.all(color: const Color(0xFFFCA5A5))),
    child: Row(children: [
      const Icon(Icons.error_outline_rounded,
        color: Color(0xFFDC2626), size: 18),
      const SizedBox(width: 10),
      Expanded(
        child: Text(message, style: GoogleFonts.inter(
          fontSize: 12, fontWeight: FontWeight.w500,
          color: const Color(0xFFB91C1C), height: 1.4))),
    ]),
  );
}

// ── Subscription expired dialog ───────────────────────────────────────────────
class _SubExpiredDialog extends StatelessWidget {
  final String? message;
  const _SubExpiredDialog({this.message});

  @override
  Widget build(BuildContext context) => Dialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 60, height: 60,
          decoration: BoxDecoration(
            color: const Color(0xFFFEF3C7),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3))),
          child: const Icon(Icons.warning_amber_rounded,
            color: Color(0xFFF59E0B), size: 30)),
        const SizedBox(height: 14),
        Text(context.l10n.subscriptionExpired,
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 17, fontWeight: FontWeight.w800,
            color: const Color(0xFF0F2D1A))),
        const SizedBox(height: 8),
        Text(
          message ?? context.l10n.subscriptionExpiredDesc,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 13, color: const Color(0xFF6B7280), height: 1.5)),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F2D1A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12))),
            child: Text(context.l10n.ok,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700, fontSize: 14))),
        ),
      ]),
    ),
  );
}

// ── Animated mesh background painter ─────────────────────────────────────────
class _MeshBgPainter extends CustomPainter {
  final double t;
  const _MeshBgPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint();

    p.shader = const LinearGradient(
      colors: [Color(0xFF040C07), Color(0xFF081510), Color(0xFF050E08)],
      begin: Alignment.topRight, end: Alignment.bottomLeft,
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Offset.zero & size, p);

    final cx = size.width * (0.85 + 0.10 * math.sin(t * math.pi * 2));
    final cy = size.height * (0.05 + 0.04 * math.cos(t * math.pi * 2));
    p.shader = RadialGradient(colors: [
      const Color(0xFF2D6A4F).withValues(alpha: 0.22),
      Colors.transparent,
    ]).createShader(Rect.fromCircle(
      center: Offset(cx, cy), radius: size.width * 0.7));
    canvas.drawCircle(Offset(cx, cy), size.width * 0.7, p);

    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.025)
      ..strokeWidth = 1.0;
    for (var i = 1; i <= 8; i++) {
      final y = size.height * 0.045 * i;
      canvas.drawLine(
        Offset(size.width * 0.04, y),
        Offset(size.width * 0.6, y), linePaint);
    }

    final dotPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.028)
      ..style = PaintingStyle.fill;
    const gap = 24.0;
    for (var x = gap; x < size.width; x += gap) {
      for (var y = gap; y < size.height * 0.52; y += gap) {
        canvas.drawCircle(Offset(x, y), 1.1, dotPaint);
      }
    }

    final streakPaint = Paint()
      ..shader = LinearGradient(colors: [
        Colors.transparent,
        const Color(0xFFF4A261).withValues(alpha: 0.18),
        Colors.transparent,
      ]).createShader(Rect.fromLTWH(0, size.height * 0.21, size.width, 1))
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(0, size.height * 0.21),
      Offset(size.width, size.height * 0.21), streakPaint);
  }

  @override
  bool shouldRepaint(_MeshBgPainter old) => old.t != t;
}
