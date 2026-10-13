import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../services/pin_service.dart';
import '../theme/app_theme.dart';
import '../utils/animations.dart';
import 'login_screen.dart';
import 'pin_setup_screen.dart';
import 'users_screen.dart';
import 'expenses_screen.dart';

class ProfileScreen extends StatefulWidget {
  final AuthUser user;
  const ProfileScreen({super.key, required this.user});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  String? _fcmToken;
  String _fcmStatus = 'Checking…';
  bool _isRegistering = false;
  bool _hasPin = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _ctrl.forward();
    _loadFcmToken();
    _loadPinStatus();
  }

  Future<void> _loadPinStatus() async {
    final has = await PinService.hasPin();
    if (mounted) setState(() => _hasPin = has);
  }

  Future<void> _loadFcmToken() async {
    try {
      // On iOS physical devices, Firebase handles APNS internally.
      // Simulator has no APNS — show informational message and bail out.
      if (Platform.isIOS) {
        final apns = await FirebaseMessaging.instance.getAPNSToken()
            .timeout(const Duration(seconds: 3), onTimeout: () => null);
        if (apns == null) {
          if (mounted) {
            setState(() {
              _fcmToken = null;
              _fcmStatus = 'Push notifications require a real device';
            });
          }
          return;
        }
      }
      final token = await FirebaseMessaging.instance
          .getToken()
          .timeout(const Duration(seconds: 8), onTimeout: () => null);
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('fcm_token');
      if (mounted) {
        setState(() {
          _fcmToken = token;
          if (token == null) {
            _fcmStatus = 'Allow notifications in device Settings';
          } else if (saved == token) {
            _fcmStatus = 'Device registered — notifications active';
          } else {
            _fcmStatus = 'Token ready — tap toggle to register';
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => _fcmStatus = 'Could not load token');
    }
  }

  Future<void> _onNotificationToggle() async {
    if (_isRegistering) return;
    setState(() { _isRegistering = true; _fcmStatus = 'Registering…'; });
    await NotificationService.uploadToken();
    await _loadFcmToken();
    if (mounted) setState(() => _isRegistering = false);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final initials = user.name.isNotEmpty ? user.name[0].toUpperCase() : 'O';
    final roleLabel = user.role[0].toUpperCase() + user.role.substring(1);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        slivers: [
          // ── Profile hero ──────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF050f09), Color(0xFF0F2D1A), Color(0xFF1a5c32)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
              ),
              child: Stack(children: [
                Positioned(top: -50, right: -20,
                  child: PulsingOrb(size: 200,
                    color: AppColors.accent.withValues(alpha: 0.07),
                    duration: const Duration(seconds: 6))),
                Positioned(bottom: -10, left: -30,
                  child: PulsingOrb(size: 140,
                    color: AppColors.primaryLight.withValues(alpha: 0.15),
                    duration: const Duration(seconds: 9))),

                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 36),
                    child: Column(children: [
                      // Avatar with gold ring
                      FadeTransition(
                        opacity: _ctrl,
                        child: Container(
                          width: 100, height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [AppColors.accent, AppColors.accentDark],
                              begin: Alignment.topLeft, end: Alignment.bottomRight),
                            boxShadow: [BoxShadow(
                              color: AppColors.accent.withValues(alpha: 0.4),
                              blurRadius: 24, spreadRadius: 2, offset: const Offset(0, 6))],
                          ),
                          child: Center(
                            child: Text(initials,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 42, fontWeight: FontWeight.w900,
                                color: Colors.white))),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SlideTransition(
                        position: Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero)
                            .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic)),
                        child: FadeTransition(
                          opacity: CurvedAnimation(parent: _ctrl,
                            curve: const Interval(0.3, 1.0)),
                          child: Column(children: [
                            Text(user.name,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 24, fontWeight: FontWeight.w900,
                                color: Colors.white, letterSpacing: -0.6)),
                            const SizedBox(height: 5),
                            Text(user.email,
                              style: GoogleFonts.inter(
                                fontSize: 13, fontWeight: FontWeight.w500,
                                color: Colors.white.withValues(alpha: 0.45))),
                            const SizedBox(height: 14),
                            Wrap(spacing: 7, runSpacing: 7,
                              alignment: WrapAlignment.center,
                              children: [
                                _Chip(roleLabel, AppColors.accent.withValues(alpha: 0.2),
                                  AppColors.accent, iconData: Icons.verified_rounded),
                                _Chip(user.shopName,
                                  Colors.white.withValues(alpha: 0.1), Colors.white,
                                  iconData: Icons.storefront_rounded),
                                _Chip(user.currency,
                                  Colors.white.withValues(alpha: 0.1),
                                  Colors.white.withValues(alpha: 0.75)),
                              ],
                            ),
                          ]),
                        ),
                      ),
                    ]),
                  ),
                ),
              ]),
            ),
          ),

          SliverToBoxAdapter(child: const SizedBox(height: 20)),

          // ── Account info ──────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: StaggeredItem(
              index: 0, controller: _ctrl,
              child: _Section(
                title: 'Account',
                icon: Icons.account_circle_outlined,
                items: [
                  _InfoTile(Icons.badge_outlined, 'Role', roleLabel, AppColors.primary),
                  _InfoTile(Icons.email_outlined, 'Email', user.email, AppColors.info),
                  _InfoTile(Icons.storefront_outlined, 'Shop', user.shopName, AppColors.success),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(child: const SizedBox(height: 12)),

          // ── Quick links ───────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: StaggeredItem(
              index: 1, controller: _ctrl,
              child: _Section(
                title: 'Quick Links',
                icon: Icons.link_rounded,
                items: [
                  if (widget.user.role == 'owner' || widget.user.role == 'manager')
                    _ActionTile(
                      Icons.manage_accounts_rounded, 'Users & Permissions',
                      const Color(0xFF7C3AED), const Color(0xFFF3F0FF),
                      onTap: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => UsersScreen(currentRole: widget.user.role)))),
                  if (widget.user.role == 'owner' || widget.user.role == 'manager' || widget.user.role == 'accountant')
                    _ActionTile(
                      Icons.receipt_long_rounded, 'Expenses',
                      const Color(0xFFD97706), const Color(0xFFFFFBEB),
                      onTap: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => const ExpensesScreen()))),
                  _ActionTile(
                    Icons.open_in_browser_rounded, 'Open Web Dashboard',
                    AppColors.info, AppColors.infoBg,
                    onTap: () => _launchUrl('https://mdspro.co.tz')),
                  _ActionTile(
                    Icons.help_outline_rounded, 'Help & Support',
                    AppColors.textSecondary, AppColors.bg,
                    onTap: () => _openSupport(context)),
                  _ActionTile(
                    Icons.info_outline_rounded, 'About MDSPro v1.0',
                    AppColors.textMuted, AppColors.bg,
                    onTap: () => _showAbout(context)),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(child: const SizedBox(height: 12)),

          // ── Security ──────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: StaggeredItem(
              index: 2, controller: _ctrl,
              child: _Section(
                title: 'Security',
                icon: Icons.shield_outlined,
                items: [
                  _PinTile(
                    hasPin: _hasPin,
                    onTap: () => _onPinTileTap(context),
                  ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(child: const SizedBox(height: 12)),

          // ── Notifications ─────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: StaggeredItem(
              index: 2, controller: _ctrl,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _NotificationCard(
                  token: _fcmToken,
                  status: _fcmStatus,
                  isRegistering: _isRegistering,
                  onToggle: _onNotificationToggle,
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(child: const SizedBox(height: 12)),

          // ── Danger zone ───────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: StaggeredItem(
              index: 2, controller: _ctrl,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: PressScale(
                  onTap: () => _confirmLogout(context),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColors.dangerBg,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                    ),
                    child: Row(children: [
                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.danger.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(13)),
                        child: const Icon(Icons.logout_rounded,
                          color: AppColors.danger, size: 20),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Sign Out',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15, fontWeight: FontWeight.w800,
                              color: AppColors.danger)),
                          Text('You will need to log in again',
                            style: GoogleFonts.inter(
                              fontSize: 11, fontWeight: FontWeight.w500,
                              color: AppColors.danger.withValues(alpha: 0.6))),
                        ]),
                      ),
                      const Icon(Icons.chevron_right_rounded,
                        color: AppColors.danger, size: 20),
                    ]),
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 28, bottom: 32),
              child: Center(
                child: Text('MDSPro  ·  v1.0.0  ·  mdspro.co.tz',
                  style: GoogleFonts.inter(
                    fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textMuted)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open link')));
      }
    }
  }

  void _openSupport(BuildContext context) {
    const phone = '+255765131788';
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: AppColors.border, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          Text('Help & Support',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18, fontWeight: FontWeight.w900,
              color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          Text(phone,
            style: GoogleFonts.inter(
              fontSize: 14, fontWeight: FontWeight.w600,
              color: AppColors.textSecondary)),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(
              child: _SupportBtn(
                icon: Icons.call_rounded,
                label: 'Call',
                color: AppColors.success,
                onTap: () {
                  Navigator.pop(context);
                  _launchUrl('tel:$phone');
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SupportBtn(
                icon: Icons.chat_rounded,
                label: 'WhatsApp',
                color: const Color(0xFF25D366),
                onTap: () {
                  Navigator.pop(context);
                  _launchUrl('https://wa.me/${phone.replaceAll('+', '')}');
                },
              ),
            ),
          ]),
        ]),
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _LogoutSheet(onConfirm: () async {
        await ApiService.logout();
        if (context.mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => const LoginScreen(),
              transitionDuration: const Duration(milliseconds: 500),
              transitionsBuilder: (_, a, __, child) => FadeTransition(
                opacity: CurvedAnimation(parent: a, curve: Curves.easeOut),
                child: child),
            ), (_) => false,
          );
        }
      }),
    );
  }

  void _onPinTileTap(BuildContext context) {
    if (!_hasPin) {
      Navigator.of(context)
          .push(MaterialPageRoute(
              builder: (_) => const PinSetupScreen(canDismiss: true)))
          .then((set) {
        if (set == true) _loadPinStatus();
      });
    } else {
      _showPinOptions(context);
    }
  }

  void _showPinOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: AppColors.border)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: AppColors.border, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(13)),
              child: const Icon(Icons.pin_outlined,
                color: AppColors.primary, size: 20)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('PIN Lock',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16, fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary)),
              Text('Manage your app PIN',
                style: GoogleFonts.inter(
                  fontSize: 12, fontWeight: FontWeight.w500,
                  color: AppColors.textMuted)),
            ])),
          ]),
          const SizedBox(height: 20),
          _PinOptionBtn(
            icon: Icons.edit_outlined,
            label: 'Change PIN',
            color: AppColors.primary,
            bg: AppColors.primary.withValues(alpha: 0.08),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context)
                  .push(MaterialPageRoute(
                      builder: (_) =>
                          const PinSetupScreen(canDismiss: true, isChanging: true)))
                  .then((set) {
                if (set == true) _loadPinStatus();
              });
            },
          ),
          const SizedBox(height: 10),
          _PinOptionBtn(
            icon: Icons.lock_open_outlined,
            label: 'Remove PIN',
            color: AppColors.danger,
            bg: AppColors.dangerBg,
            onTap: () {
              Navigator.pop(context);
              _confirmRemovePin(context);
            },
          ),
        ]),
      ),
    );
  }

  void _confirmRemovePin(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: AppColors.dangerBg, shape: BoxShape.circle),
            child: const Icon(Icons.lock_open_rounded,
              color: AppColors.danger, size: 24)),
          const SizedBox(height: 16),
          Text('Remove PIN?', style: AppTextStyles.headingMedium),
          const SizedBox(height: 8),
          Text(
            'The app will no longer require a PIN when opened.',
            style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted),
            textAlign: TextAlign.center),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800)))),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await PinService.clearPin();
                  _loadPinStatus();
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
                child: Text('Remove',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800, color: Colors.white)))),
          ]),
        ]),
      ),
    );
  }

  void _showAbout(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(18)),
            child: Center(
              child: Text('M', style: GoogleFonts.plusJakartaSans(
                fontSize: 32, fontWeight: FontWeight.w900, color: AppColors.accent))),
          ),
          const SizedBox(height: 16),
          Text('MDSPro Owner', style: AppTextStyles.headingMedium),
          const SizedBox(height: 4),
          Text('Version 1.0.0',
            style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
          const SizedBox(height: 12),
          Text('© 2026 MDSPro. All rights reserved.',
            style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
            textAlign: TextAlign.center),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: Text('Close',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800, color: Colors.white))),
          ),
        ]),
      ),
    );
  }
}

// ── PIN tile ───────────────────────────────────────────────────────────────────
class _PinTile extends StatelessWidget {
  final bool hasPin;
  final VoidCallback onTap;
  const _PinTile({required this.hasPin, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(18),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: (hasPin ? AppColors.success : AppColors.primary)
                .withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10)),
          child: Icon(
            hasPin ? Icons.lock_rounded : Icons.lock_open_rounded,
            color: hasPin ? AppColors.success : AppColors.primary,
            size: 17),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('App PIN Lock',
              style: GoogleFonts.inter(
                fontSize: 14, fontWeight: FontWeight.w600,
                color: AppColors.textPrimary)),
            Text(
              hasPin ? 'Enabled — app locks after 10 min idle' : 'Not set — tap to create a PIN',
              style: GoogleFonts.inter(
                fontSize: 11, fontWeight: FontWeight.w500,
                color: hasPin ? AppColors.success : AppColors.textMuted)),
          ]),
        ),
        if (hasPin)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8)),
            child: Text('ON',
              style: GoogleFonts.inter(
                fontSize: 10, fontWeight: FontWeight.w800,
                color: AppColors.success)))
        else
          const Icon(Icons.chevron_right_rounded,
            size: 18, color: AppColors.textMuted),
      ]),
    ),
  );
}

// ── PIN option button (used in manage sheet) ───────────────────────────────────
class _PinOptionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color, bg;
  final VoidCallback onTap;
  const _PinOptionBtn({
    required this.icon, required this.label,
    required this.color, required this.bg, required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(14),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2))),
      child: Row(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Text(label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14, fontWeight: FontWeight.w800, color: color)),
        const Spacer(),
        Icon(Icons.chevron_right_rounded, color: color.withValues(alpha: 0.5), size: 18),
      ]),
    ),
  );
}

// ── Section ────────────────────────────────────────────────────────────────────
class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> items;
  const _Section({required this.title, required this.icon, required this.items});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(left: 2, bottom: 10),
        child: Row(children: [
          Icon(icon, size: 14, color: AppColors.textMuted),
          const SizedBox(width: 6),
          Text(title.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 10, fontWeight: FontWeight.w800,
              color: AppColors.textMuted, letterSpacing: 0.8)),
        ]),
      ),
      Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
          boxShadow: AppShadows.sm,
        ),
        child: Column(
          children: items.asMap().entries.map((e) {
            final isLast = e.key == items.length - 1;
            return Column(children: [
              e.value,
              if (!isLast) const Divider(height: 1, indent: 60, color: AppColors.borderLight),
            ]);
          }).toList(),
        ),
      ),
    ]),
  );
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;
  const _InfoTile(this.icon, this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    child: Row(children: [
      Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: color, size: 17),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Text(label,
          style: GoogleFonts.inter(
            fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
      Text(value,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
        overflow: TextOverflow.ellipsis),
    ]),
  );
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color, bg;
  final VoidCallback onTap;
  const _ActionTile(this.icon, this.label, this.color, this.bg, {required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(18),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: bg, borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 17),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label,
            style: GoogleFonts.inter(
              fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
        const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textMuted),
      ]),
    ),
  );
}

class _Chip extends StatelessWidget {
  final String label;
  final Color bg, fg;
  final IconData? iconData;
  const _Chip(this.label, this.bg, this.fg, {this.iconData});

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(horizontal: iconData != null ? 8 : 12, vertical: 5),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      if (iconData != null) ...[
        Icon(iconData, color: fg, size: 12),
        const SizedBox(width: 4),
      ],
      Text(label,
        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
    ]),
  );
}

// ── Notification settings card ────────────────────────────────────────────────
class _NotificationCard extends StatelessWidget {
  final String? token;
  final String status;
  final bool isRegistering;
  final VoidCallback onToggle;

  const _NotificationCard({
    required this.token,
    required this.status,
    required this.isRegistering,
    required this.onToggle,
  });

  bool get _isActive => token != null && status.contains('uploaded');

  @override
  Widget build(BuildContext context) {
    final active = _isActive;
    final statusColor = active
        ? const Color(0xFF16A34A)
        : status.contains('Error')
            ? AppColors.danger
            : AppColors.textMuted;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(children: [
        // ── Header row ──────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
          child: Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: active
                      ? [const Color(0xFF0F2D1A), const Color(0xFF1a4a2e)]
                      : [Colors.grey.shade300, Colors.grey.shade200],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                active ? Icons.notifications_active_rounded : Icons.notifications_off_rounded,
                color: active ? AppColors.accent : Colors.grey.shade500,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Sale Notifications',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15, fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text(
                  active ? 'Active — alerts for new sales' : 'Tap to enable',
                  style: GoogleFonts.inter(
                    fontSize: 12, fontWeight: FontWeight.w500,
                    color: AppColors.textMuted),
                ),
              ]),
            ),
            // Toggle switch
            GestureDetector(
              onTap: isRegistering ? null : onToggle,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 52, height: 30,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: active ? AppColors.primary : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: active ? [BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 8, offset: const Offset(0, 2))] : [],
                ),
                child: AnimatedAlign(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  alignment: active ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    width: 24, height: 24,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 4, offset: const Offset(0, 1))],
                    ),
                    child: isRegistering
                        ? Padding(
                            padding: const EdgeInsets.all(5),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: active ? AppColors.primary : Colors.grey,
                            ),
                          )
                        : null,
                  ),
                ),
              ),
            ),
          ]),
        ),

        // ── Status bar ──────────────────────────────────────────────────────
        Container(
          margin: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: active
                ? const Color(0xFF16A34A).withValues(alpha: 0.06)
                : AppColors.bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: active
                  ? const Color(0xFF16A34A).withValues(alpha: 0.2)
                  : Colors.grey.withValues(alpha: 0.15),
            ),
          ),
          child: Row(children: [
            Container(
              width: 7, height: 7,
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
                boxShadow: active ? [BoxShadow(
                  color: statusColor.withValues(alpha: 0.5),
                  blurRadius: 4, spreadRadius: 1)] : [],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(status,
                style: GoogleFonts.inter(
                  fontSize: 12, fontWeight: FontWeight.w500,
                  color: statusColor)),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ── Support button ────────────────────────────────────────────────────────────
class _SupportBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _SupportBtn({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 52,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(
          color: color.withValues(alpha: 0.3),
          blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(width: 8),
        Text(label, style: GoogleFonts.plusJakartaSans(
          fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
      ]),
    ),
  );
}

// ── Logout confirmation sheet ──────────────────────────────────────────────────
class _LogoutSheet extends StatelessWidget {
  final VoidCallback onConfirm;
  const _LogoutSheet({required this.onConfirm});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(28),
    decoration: const BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 40, height: 4,
        decoration: BoxDecoration(
          color: AppColors.border, borderRadius: BorderRadius.circular(2))),
      const SizedBox(height: 24),
      Container(
        width: 64, height: 64,
        decoration: BoxDecoration(
          color: AppColors.dangerBg, shape: BoxShape.circle),
        child: const Icon(Icons.logout_rounded, color: AppColors.danger, size: 28),
      ),
      const SizedBox(height: 16),
      Text('Sign Out?',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
      const SizedBox(height: 8),
      Text('You will be signed out and redirected to the login screen.',
        style: GoogleFonts.inter(
          fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
        textAlign: TextAlign.center),
      const SizedBox(height: 28),
      Row(children: [
        Expanded(
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border)),
              child: Center(
                child: Text('Cancel',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15, fontWeight: FontWeight.w800,
                    color: AppColors.textSecondary))),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: PressScale(
            onTap: () {
              Navigator.pop(context);
              onConfirm();
            },
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFDC2626), Color(0xFFEF4444)]),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(
                  color: AppColors.danger.withValues(alpha: 0.3),
                  blurRadius: 12, offset: const Offset(0, 4))],
              ),
              child: Center(
                child: Text('Sign Out',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white))),
            ),
          ),
        ),
      ]),
      SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
    ]),
  );
}
