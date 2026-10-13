import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _formKey     = GlobalKey<FormState>();
  final _shopCtrl    = TextEditingController();
  final _nameCtrl    = TextEditingController();
  final _emailCtrl   = TextEditingController();
  final _phoneCtrl   = TextEditingController();
  final _passCtrl    = TextEditingController();

  final _shopFocus   = FocusNode();
  final _nameFocus   = FocusNode();
  final _emailFocus  = FocusNode();
  final _phoneFocus  = FocusNode();
  final _passFocus   = FocusNode();

  String _currency   = 'TZS';
  String _country    = 'Tanzania';
  bool   _obscure    = true;
  bool   _loading    = false;
  String? _error;

  late AnimationController _fadeCtrl;
  late Animation<double>   _fadeAnim;

  static const _currencies = ['TZS', 'KES', 'UGX', 'USD', 'EUR', 'GBP', 'ZAR'];
  static const _countries  = [
    'Tanzania', 'Kenya', 'Uganda', 'Rwanda', 'Burundi',
    'Ethiopia', 'Zambia', 'Zimbabwe', 'South Africa', 'Other'
  ];

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    for (final c in [_shopCtrl, _nameCtrl, _emailCtrl, _phoneCtrl, _passCtrl]) c.dispose();
    for (final f in [_shopFocus, _nameFocus, _emailFocus, _phoneFocus, _passFocus]) f.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ApiService.registerOwner(
        shopName:  _shopCtrl.text.trim(),
        ownerName: _nameCtrl.text.trim(),
        email:     _emailCtrl.text.trim().toLowerCase(),
        phone:     _phoneCtrl.text.trim(),
        password:  _passCtrl.text,
        currency:  _currency,
        country:   _country,
      );
      if (!mounted) return;
      if (res['ok'] == true) {
        _showSuccess(res['message'] ?? 'Registration successful!');
      } else {
        setState(() => _error = res['error'] ?? 'Registration failed.');
      }
    } catch (e) {
      setState(() => _error = 'Connection error. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSuccess(String msg) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(28),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.12),
              shape: BoxShape.circle),
            child: Icon(Icons.check_circle_rounded,
                color: AppColors.success, size: 36)),
          const SizedBox(height: 20),
          Text('Shop Created!',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20, fontWeight: FontWeight.w900,
              color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Text(msg,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // close dialog
                Navigator.pop(context); // back to login
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 14)),
              child: Text('Sign In Now',
                style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800, fontSize: 15)),
            ),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.primary,
        body: Stack(children: [
          // Background gradient
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0A1F10), Color(0xFF0F2D1A), Color(0xFF1a4730)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),

          // Decorative circles
          Positioned(
            top: -60, right: -40,
            child: Container(
              width: 180, height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.04)),
            ),
          ),
          Positioned(
            top: 60, right: 40,
            child: Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accent.withValues(alpha: 0.15)),
            ),
          ),

          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: Column(children: [
                // Top bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: Row(children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.arrow_back_rounded,
                            color: Colors.white, size: 20),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Create Shop',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18, fontWeight: FontWeight.w900,
                          color: Colors.white, letterSpacing: -0.3)),
                      Text('Start your free trial today',
                        style: GoogleFonts.inter(
                          fontSize: 12, color: Colors.white.withValues(alpha: 0.6))),
                    ]),
                    const Spacer(),
                    // Trial badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: AppColors.accent.withValues(alpha: 0.4))),
                      child: Text('Free Trial',
                        style: GoogleFonts.inter(
                          fontSize: 11, fontWeight: FontWeight.w700,
                          color: AppColors.accent)),
                    ),
                  ]),
                ),

                const SizedBox(height: 16),

                // Card
                Expanded(
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
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                      child: SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                            24, 20, 24, mq.viewInsets.bottom + 32),
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
                                    color: Colors.black.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(2))),
                              ),
                              const SizedBox(height: 20),

                              // Section: Shop Info
                              _SectionLabel('Your Shop'),
                              const SizedBox(height: 12),

                              _Field(
                                ctrl: _shopCtrl,
                                focus: _shopFocus,
                                label: 'Shop / Business Name',
                                hint: 'e.g. Kariakoo Electronics',
                                icon: Icons.store_rounded,
                                next: _nameFocus,
                                validator: (v) =>
                                    (v?.trim().isEmpty ?? true) ? 'Shop name is required' : null,
                              ),
                              const SizedBox(height: 14),

                              // Currency + Country row
                              Row(children: [
                                Expanded(
                                  child: _DropField<String>(
                                    label: 'Currency',
                                    icon: Icons.currency_exchange_rounded,
                                    value: _currency,
                                    items: _currencies,
                                    onChanged: (v) => setState(() => _currency = v!),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _DropField<String>(
                                    label: 'Country',
                                    icon: Icons.flag_rounded,
                                    value: _country,
                                    items: _countries,
                                    onChanged: (v) => setState(() => _country = v!),
                                  ),
                                ),
                              ]),

                              const SizedBox(height: 24),

                              // Section: Your Account
                              _SectionLabel('Your Account'),
                              const SizedBox(height: 12),

                              _Field(
                                ctrl: _nameCtrl,
                                focus: _nameFocus,
                                label: 'Your Full Name',
                                hint: 'e.g. Amani Juma',
                                icon: Icons.person_rounded,
                                next: _emailFocus,
                                validator: (v) =>
                                    (v?.trim().isEmpty ?? true) ? 'Name is required' : null,
                              ),
                              const SizedBox(height: 14),

                              _Field(
                                ctrl: _emailCtrl,
                                focus: _emailFocus,
                                label: 'Email Address',
                                hint: 'your@email.com',
                                icon: Icons.alternate_email_rounded,
                                next: _phoneFocus,
                                keyboard: TextInputType.emailAddress,
                                validator: (v) {
                                  if (v?.trim().isEmpty ?? true) return 'Email is required';
                                  if (!RegExp(r'^[\w.-]+@[\w.-]+\.\w+$').hasMatch(v!.trim())) {
                                    return 'Enter a valid email';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),

                              _Field(
                                ctrl: _phoneCtrl,
                                focus: _phoneFocus,
                                label: 'Phone Number',
                                hint: '+255 7XX XXX XXX',
                                icon: Icons.phone_rounded,
                                next: _passFocus,
                                keyboard: TextInputType.phone,
                              ),
                              const SizedBox(height: 14),

                              // Password field (with show/hide)
                              _Field(
                                ctrl: _passCtrl,
                                focus: _passFocus,
                                label: 'Password',
                                hint: 'Min 6 characters',
                                icon: Icons.lock_outline_rounded,
                                obscure: _obscure,
                                isLast: true,
                                onSubmit: (_) => _submit(),
                                suffix: GestureDetector(
                                  onTap: () => setState(() => _obscure = !_obscure),
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 16),
                                    child: Icon(
                                      _obscure
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      size: 20, color: AppColors.textMuted),
                                  ),
                                ),
                                validator: (v) =>
                                    (v?.length ?? 0) < 6 ? 'Minimum 6 characters' : null,
                              ),

                              const SizedBox(height: 24),

                              // Error
                              if (_error != null) ...[
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: AppColors.danger.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: AppColors.danger.withValues(alpha: 0.25))),
                                  child: Row(children: [
                                    Icon(Icons.error_outline_rounded,
                                        size: 18, color: AppColors.danger),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(_error!,
                                        style: GoogleFonts.inter(
                                          fontSize: 13, color: AppColors.danger,
                                          fontWeight: FontWeight.w500)),
                                    ),
                                  ]),
                                ),
                                const SizedBox(height: 16),
                              ],

                              // Submit
                              _SubmitButton(loading: _loading, onTap: _loading ? null : _submit),

                              const SizedBox(height: 20),

                              // Terms note
                              Center(
                                child: Text(
                                  'By creating an account, you agree to our\nTerms of Service and Privacy Policy.',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(
                                    fontSize: 11, color: AppColors.textMuted,
                                    height: 1.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 3, height: 16,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(2)),
      ),
      const SizedBox(width: 8),
      Text(text,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 13, fontWeight: FontWeight.w800,
          color: AppColors.textPrimary, letterSpacing: 0.1)),
    ]);
  }
}

// ── Input field ───────────────────────────────────────────────────────────────
class _Field extends StatefulWidget {
  final TextEditingController ctrl;
  final FocusNode focus;
  final String label, hint;
  final IconData icon;
  final FocusNode? next;
  final TextInputType? keyboard;
  final bool obscure;
  final bool isLast;
  final Widget? suffix;
  final ValueChanged<String>? onSubmit;
  final String? Function(String?)? validator;

  const _Field({
    required this.ctrl,
    required this.focus,
    required this.label,
    required this.hint,
    required this.icon,
    this.next,
    this.keyboard,
    this.obscure = false,
    this.isLast  = false,
    this.suffix,
    this.onSubmit,
    this.validator,
  });

  @override
  State<_Field> createState() => _FieldState();
}

class _FieldState extends State<_Field> {
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    widget.focus.addListener(() {
      if (mounted) setState(() => _focused = widget.focus.hasFocus);
    });
  }

  @override
  Widget build(BuildContext context) {
    final bc = _focused ? AppColors.primary : const Color(0xFFE5E7EB);
    final ic = _focused ? AppColors.primary : const Color(0xFF9CA3AF);
    final bg = _focused
        ? AppColors.primary.withValues(alpha: 0.03)
        : const Color(0xFFF9FAFB);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(widget.label,
        style: GoogleFonts.inter(
          fontSize: 11, fontWeight: FontWeight.w700,
          color: _focused ? AppColors.primary : AppColors.textMuted,
          letterSpacing: 0.2)),
      const SizedBox(height: 7),
      AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: bc, width: _focused ? 1.8 : 1.2),
          boxShadow: _focused ? [BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 8, offset: const Offset(0, 2))] : [],
        ),
        child: Row(children: [
          const SizedBox(width: 14),
          Icon(widget.icon, size: 18, color: ic),
          const SizedBox(width: 10),
          Expanded(
            child: TextFormField(
              controller: widget.ctrl,
              focusNode: widget.focus,
              obscureText: widget.obscure,
              keyboardType: widget.keyboard,
              textInputAction: widget.isLast ? TextInputAction.done : TextInputAction.next,
              onFieldSubmitted: widget.onSubmit ?? (_) {
                if (widget.next != null) FocusScope.of(context).requestFocus(widget.next);
              },
              validator: widget.validator,
              style: GoogleFonts.inter(
                fontSize: 15, fontWeight: FontWeight.w500,
                color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: widget.hint,
                hintStyle: GoogleFonts.inter(
                  fontSize: 14, color: const Color(0xFFB4BAC5)),
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
          if (widget.suffix != null) widget.suffix!,
        ]),
      ),
    ]);
  }
}

// ── Dropdown field ────────────────────────────────────────────────────────────
class _DropField<T> extends StatelessWidget {
  final String label;
  final IconData icon;
  final T value;
  final List<T> items;
  final ValueChanged<T?> onChanged;

  const _DropField({
    required this.label,
    required this.icon,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
        style: GoogleFonts.inter(
          fontSize: 11, fontWeight: FontWeight.w700,
          color: AppColors.textMuted, letterSpacing: 0.2)),
      const SizedBox(height: 7),
      Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB), width: 1.2)),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: value,
            isExpanded: true,
            icon: const Icon(Icons.keyboard_arrow_down_rounded,
                size: 18, color: Color(0xFF9CA3AF)),
            style: GoogleFonts.inter(
                fontSize: 14, fontWeight: FontWeight.w500,
                color: AppColors.textPrimary),
            items: items.map((i) => DropdownMenuItem(
              value: i,
              child: Row(children: [
                Icon(icon, size: 15, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(i.toString(),
                  style: GoogleFonts.inter(fontSize: 13)),
              ]),
            )).toList(),
            onChanged: onChanged,
          ),
        ),
      ),
    ]);
  }
}

// ── Submit button ─────────────────────────────────────────────────────────────
class _SubmitButton extends StatelessWidget {
  final bool loading;
  final VoidCallback? onTap;
  const _SubmitButton({required this.loading, this.onTap});

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
                  blurRadius: 18, offset: const Offset(0, 7))],
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
                    Text('Create My Shop',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16, fontWeight: FontWeight.w800,
                        color: Colors.white, letterSpacing: 0.3)),
                    const SizedBox(width: 10),
                    Container(
                      width: 26, height: 26,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.store_rounded,
                          color: Colors.white, size: 14),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
