import 'dart:io';
import 'package:flutter/material.dart';
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
import '../utils/responsive.dart';
import '../utils/l10n_ext.dart';
import '../providers/locale_provider.dart';
import 'login_screen.dart';
import 'pin_setup_screen.dart';
import 'users_screen.dart';
import 'branches_screen.dart';
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
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
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
            _fcmStatus = 'Token ready — tap to register';
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
    final isManager = user.role == 'owner' || user.role == 'manager';
    final canViewFinance = isManager || user.role == 'accountant';

    final resp = Responsive.of(context);
    final isTablet = MediaQuery.of(context).size.width >= 600;
    if (isTablet) return _buildTabletLayout(context);
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: resp.isLargeTablet ? 720 : double.infinity),
          child: CustomScrollView(
            slivers: [
              // ── Profile hero ──────────────────────────────────────────────
              SliverToBoxAdapter(
                child: _buildHero(initials, roleLabel, user),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 28)),

              // ── Team Management (owner/manager only) ──────────────────────
              if (isManager) ...[
                SliverToBoxAdapter(
                  child: StaggeredItem(
                    index: 0, controller: _ctrl,
                    child: _Section(
                      title: 'Team Management',
                      accentColor: const Color(0xFF7C3AED),
                      items: [
                        _ActionTile(
                          Icons.manage_accounts_rounded,
                          'Users & Permissions',
                          subtitle: 'Manage staff, roles and access controls',
                          const Color(0xFF7C3AED),
                          const Color(0xFFF3F0FF),
                          onTap: () => Navigator.push(context, MaterialPageRoute(
                            builder: (_) => UsersScreen(currentRole: user.role)))),
                        _ActionTile(
                          Icons.store_rounded,
                          'Branch Management',
                          subtitle: 'Add and configure store locations',
                          AppColors.primary,
                          AppColors.primary.withValues(alpha: 0.08),
                          onTap: () => Navigator.push(context, MaterialPageRoute(
                            builder: (_) => const BranchesScreen()))),
                      ],
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 12)),
              ],

              // ── Finance (owner/manager/accountant) ────────────────────────
              if (canViewFinance) ...[
                SliverToBoxAdapter(
                  child: StaggeredItem(
                    index: isManager ? 1 : 0, controller: _ctrl,
                    child: _Section(
                      title: 'Finance',
                      accentColor: const Color(0xFFD97706),
                      items: [
                        _ActionTile(
                          Icons.receipt_long_rounded,
                          'Expenses',
                          subtitle: 'Track and categorize business costs',
                          const Color(0xFFD97706),
                          const Color(0xFFFFFBEB),
                          onTap: () => Navigator.push(context, MaterialPageRoute(
                            builder: (_) => const ExpensesScreen()))),
                      ],
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 12)),
              ],

              // ── Language ──────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: StaggeredItem(
                  index: 2, controller: _ctrl,
                  child: _Section(
                    title: 'Language',
                    accentColor: const Color(0xFF0EA5E9),
                    items: [_LanguageTile()],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 12)),

              // ── Security ──────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: StaggeredItem(
                  index: 3, controller: _ctrl,
                  child: _Section(
                    title: 'Security',
                    accentColor: AppColors.primary,
                    items: [
                      _PinTile(
                        hasPin: _hasPin,
                        onTap: () => _onPinTileTap(context),
                      ),
                      _ActionTile(
                        Icons.lock_outline_rounded,
                        'Change Password',
                        subtitle: 'Update your account password',
                        AppColors.primary,
                        AppColors.primary.withValues(alpha: 0.08),
                        onTap: () => _showChangePassword(context)),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 12)),

              // ── Notifications ─────────────────────────────────────────────
              SliverToBoxAdapter(
                child: StaggeredItem(
                  index: 4, controller: _ctrl,
                  child: _Section(
                    title: 'Notifications',
                    accentColor: const Color(0xFF2563EB),
                    items: [
                      _NotificationTile(
                        token: _fcmToken,
                        status: _fcmStatus,
                        isRegistering: _isRegistering,
                        onToggle: _onNotificationToggle,
                      ),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 12)),

              // ── Links & Support ───────────────────────────────────────────
              SliverToBoxAdapter(
                child: StaggeredItem(
                  index: 4, controller: _ctrl,
                  child: _Section(
                    title: 'Links & Support',
                    accentColor: AppColors.textSecondary,
                    items: [
                      _ActionTile(
                        Icons.open_in_browser_rounded,
                        'Web Dashboard',
                        subtitle: 'Open full interface at mdspro.co.tz',
                        AppColors.info,
                        AppColors.infoBg,
                        onTap: () => _launchUrl('https://mdspro.co.tz')),
                      _ActionTile(
                        Icons.payment_rounded,
                        'How to Pay',
                        subtitle: 'Send payment via M-Pesa or Bank',
                        const Color(0xFF059669),
                        const Color(0xFFF0FDF4),
                        onTap: () => Navigator.push(context, MaterialPageRoute(
                          builder: (_) => const HowToPayScreen()))),
                      _ActionTile(
                        Icons.headset_mic_rounded,
                        'Help & Support',
                        subtitle: 'Call or chat with our support team',
                        const Color(0xFF16A34A),
                        const Color(0xFFECFDF5),
                        onTap: () => _openSupport(context)),
                      _ActionTile(
                        Icons.info_outline_rounded,
                        'About MDSPro',
                        subtitle: 'Version 1.0.15 · mdspro.co.tz',
                        AppColors.textMuted,
                        AppColors.bg,
                        onTap: () => _showAbout(context)),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 20)),

              // ── Sign Out ──────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: StaggeredItem(
                  index: 5, controller: _ctrl,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: PressScale(
                      onTap: () => _confirmLogout(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                        decoration: BoxDecoration(
                          color: AppColors.dangerBg,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppColors.danger.withValues(alpha: 0.25)),
                        ),
                        child: Row(children: [
                          Container(
                            width: 42, height: 42,
                            decoration: BoxDecoration(
                              color: AppColors.danger.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12)),
                            child: const Icon(Icons.logout_rounded,
                              color: AppColors.danger, size: 19),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('Sign Out',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14, fontWeight: FontWeight.w800,
                                  color: AppColors.danger)),
                              const SizedBox(height: 1),
                              Text('You will need to log in again',
                                style: GoogleFonts.inter(
                                  fontSize: 11, fontWeight: FontWeight.w500,
                                  color: AppColors.danger.withValues(alpha: 0.55))),
                            ]),
                          ),
                          Icon(Icons.chevron_right_rounded,
                            color: AppColors.danger.withValues(alpha: 0.5), size: 18),
                        ]),
                      ),
                    ),
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 28, bottom: 36),
                  child: Center(
                    child: Text('MDSPro  ·  v1.0.15  ·  mdspro.co.tz',
                      style: GoogleFonts.inter(
                        fontSize: 11, fontWeight: FontWeight.w500,
                        color: AppColors.textMuted)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Tablet layout ─────────────────────────────────────────────────────────────
  Widget _buildTabletLayout(BuildContext context) {
    final user = widget.user;
    final initials = user.name.isNotEmpty ? user.name[0].toUpperCase() : 'O';
    final roleLabel = user.role[0].toUpperCase() + user.role.substring(1);
    final isManager = user.role == 'owner' || user.role == 'manager';
    final canViewFinance = isManager || user.role == 'accountant';
    final resp = Responsive.of(context);

    Widget leftCol = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (isManager) ...[
        StaggeredItem(index: 0, controller: _ctrl,
          child: _Section(
            title: 'Team Management',
            accentColor: const Color(0xFF7C3AED),
            items: [
              _ActionTile(Icons.manage_accounts_rounded, 'Users & Permissions',
                subtitle: 'Manage staff, roles and access controls',
                const Color(0xFF7C3AED), const Color(0xFFF3F0FF),
                onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => UsersScreen(currentRole: user.role)))),
              _ActionTile(Icons.store_rounded, 'Branch Management',
                subtitle: 'Add and configure store locations',
                AppColors.primary, AppColors.primary.withValues(alpha: 0.08),
                onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => const BranchesScreen()))),
            ],
          )),
        const SizedBox(height: 14),
      ],
      StaggeredItem(index: isManager ? 2 : 0, controller: _ctrl,
        child: _Section(
          title: 'Security',
          accentColor: AppColors.primary,
          items: [
            _PinTile(hasPin: _hasPin, onTap: () => _onPinTileTap(context)),
            _ActionTile(Icons.lock_outline_rounded, 'Change Password',
              subtitle: 'Update your account password',
              AppColors.primary, AppColors.primary.withValues(alpha: 0.08),
              onTap: () => _showChangePassword(context)),
          ],
        )),
      const SizedBox(height: 14),
      StaggeredItem(index: isManager ? 3 : 1, controller: _ctrl,
        child: _Section(
          title: 'Notifications',
          accentColor: const Color(0xFF2563EB),
          items: [
            _NotificationTile(
              token: _fcmToken, status: _fcmStatus,
              isRegistering: _isRegistering, onToggle: _onNotificationToggle),
          ],
        )),
    ]);

    Widget rightCol = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (canViewFinance) ...[
        StaggeredItem(index: isManager ? 1 : 0, controller: _ctrl,
          child: _Section(
            title: 'Finance',
            accentColor: const Color(0xFFD97706),
            items: [
              _ActionTile(Icons.receipt_long_rounded, 'Expenses',
                subtitle: 'Track and categorize business costs',
                const Color(0xFFD97706), const Color(0xFFFFFBEB),
                onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => const ExpensesScreen()))),
            ],
          )),
        const SizedBox(height: 14),
      ],
      StaggeredItem(index: 4, controller: _ctrl,
        child: _Section(
          title: 'Links & Support',
          accentColor: AppColors.textSecondary,
          items: [
            _ActionTile(Icons.open_in_browser_rounded, 'Web Dashboard',
              subtitle: 'Open full interface at mdspro.co.tz',
              AppColors.info, AppColors.infoBg,
              onTap: () => _launchUrl('https://mdspro.co.tz')),
            _ActionTile(Icons.payment_rounded, 'How to Pay',
              subtitle: 'Send payment via M-Pesa or Bank',
              const Color(0xFF059669), const Color(0xFFF0FDF4),
              onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => const HowToPayScreen()))),
            _ActionTile(Icons.headset_mic_rounded, 'Help & Support',
              subtitle: 'Call or chat with our support team',
              const Color(0xFF16A34A), const Color(0xFFECFDF5),
              onTap: () => _openSupport(context)),
            _ActionTile(Icons.info_outline_rounded, 'About MDSPro',
              subtitle: 'Version 1.0.15 · mdspro.co.tz',
              AppColors.textMuted, AppColors.bg,
              onTap: () => _showAbout(context)),
          ],
        )),
      const SizedBox(height: 14),
      StaggeredItem(index: 5, controller: _ctrl,
        child: PressScale(
          onTap: () => _confirmLogout(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.dangerBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.danger.withValues(alpha: 0.25))),
            child: Row(children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.logout_rounded, color: AppColors.danger, size: 19)),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Sign Out',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.danger)),
                const SizedBox(height: 1),
                Text('You will need to log in again',
                  style: GoogleFonts.inter(
                    fontSize: 11, fontWeight: FontWeight.w500,
                    color: AppColors.danger.withValues(alpha: 0.55))),
              ])),
              Icon(Icons.chevron_right_rounded,
                color: AppColors.danger.withValues(alpha: 0.5), size: 18),
            ]),
          ),
        )),
    ]);

    final hPad = resp.isLargeTablet ? 28.0 : 20.0;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _buildTabletHero(initials, roleLabel, user)),
          SliverToBoxAdapter(child: const SizedBox(height: 24)),
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: hPad),
            sliver: SliverToBoxAdapter(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: leftCol),
                  const SizedBox(width: 16),
                  Expanded(child: rightCol),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 28, bottom: 36),
              child: Center(
                child: Text('MDSPro  ·  v1.0.15  ·  mdspro.co.tz',
                  style: GoogleFonts.inter(
                    fontSize: 11, fontWeight: FontWeight.w500,
                    color: AppColors.textMuted))),
            ),
          ),
        ],
      ),
    );
  }

  // ── Tablet hero ───────────────────────────────────────────────────────────────
  Widget _buildTabletHero(String initials, String roleLabel, AuthUser user) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF050f09), Color(0xFF0F2D1A), Color(0xFF1a5c32)],
          begin: Alignment.topLeft, end: Alignment.bottomRight)),
      child: Stack(children: [
        Positioned(top: -60, right: -20,
          child: PulsingOrb(size: 280,
            color: AppColors.accent.withValues(alpha: 0.07),
            duration: const Duration(seconds: 6))),
        Positioned(bottom: 20, left: -40,
          child: PulsingOrb(size: 200,
            color: AppColors.primaryLight.withValues(alpha: 0.15),
            duration: const Duration(seconds: 9))),

        SafeArea(
          bottom: false,
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 36, 32, 28),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Larger avatar
                  FadeTransition(
                    opacity: _ctrl,
                    child: Stack(alignment: Alignment.center, children: [
                      Container(
                        width: 134, height: 134,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.accent.withValues(alpha: 0.2), width: 7))),
                      Container(
                        width: 118, height: 118,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [AppColors.accent, AppColors.accentDark],
                            begin: Alignment.topLeft, end: Alignment.bottomRight),
                          boxShadow: [BoxShadow(
                            color: AppColors.accent.withValues(alpha: 0.45),
                            blurRadius: 36, spreadRadius: 4, offset: const Offset(0, 12))]),
                        child: Center(
                          child: Text(initials,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 48, fontWeight: FontWeight.w900,
                              color: Colors.white)))),
                      Positioned(
                        bottom: 6, right: 6,
                        child: Container(
                          width: 20, height: 20,
                          decoration: BoxDecoration(
                            color: const Color(0xFF22C55E),
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFF0F2D1A), width: 2.5)))),
                    ]),
                  ),

                  const SizedBox(width: 28),

                  // Name / info (horizontal)
                  Expanded(
                    child: SlideTransition(
                      position: Tween<Offset>(begin: const Offset(0.15, 0), end: Offset.zero)
                          .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic)),
                      child: FadeTransition(
                        opacity: CurvedAnimation(parent: _ctrl, curve: const Interval(0.2, 1.0)),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(user.name,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 28, fontWeight: FontWeight.w900,
                              color: Colors.white, letterSpacing: -0.5)),
                          const SizedBox(height: 5),
                          Text(user.email,
                            style: GoogleFonts.inter(
                              fontSize: 13, fontWeight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.42))),
                          const SizedBox(height: 14),
                          Wrap(spacing: 8, runSpacing: 8, children: [
                            _Chip(roleLabel,
                              AppColors.accent.withValues(alpha: 0.2), AppColors.accent,
                              iconData: Icons.verified_rounded),
                            _Chip(user.shopName,
                              Colors.white.withValues(alpha: 0.1), Colors.white,
                              iconData: Icons.storefront_rounded),
                            _Chip(user.currency,
                              Colors.white.withValues(alpha: 0.1),
                              Colors.white.withValues(alpha: 0.7)),
                          ]),
                        ]),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Stats bar
            Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.22),
                border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08)))),
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(children: [
                _HeroStat(label: 'Role', value: roleLabel, icon: Icons.badge_outlined),
                const _HeroStatDivider(),
                _HeroStat(label: 'Shop', value: user.shopName, icon: Icons.storefront_outlined),
                const _HeroStatDivider(),
                _HeroStat(label: 'Currency', value: user.currency, icon: Icons.payments_outlined),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }

  // ── Hero builder ─────────────────────────────────────────────────────────────
  Widget _buildHero(String initials, String roleLabel, AuthUser user) {
    return Container(
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
        Positioned(bottom: 40, left: -30,
          child: PulsingOrb(size: 140,
            color: AppColors.primaryLight.withValues(alpha: 0.15),
            duration: const Duration(seconds: 9))),

        SafeArea(
          bottom: false,
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
              child: Column(children: [
                // Avatar with amber glow ring
                FadeTransition(
                  opacity: _ctrl,
                  child: Stack(alignment: Alignment.center, children: [
                    Container(
                      width: 110, height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.accent.withValues(alpha: 0.2), width: 6)),
                    ),
                    Container(
                      width: 96, height: 96,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [AppColors.accent, AppColors.accentDark],
                          begin: Alignment.topLeft, end: Alignment.bottomRight),
                        boxShadow: [BoxShadow(
                          color: AppColors.accent.withValues(alpha: 0.45),
                          blurRadius: 28, spreadRadius: 2, offset: const Offset(0, 8))],
                      ),
                      child: Center(
                        child: Text(initials,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 40, fontWeight: FontWeight.w900,
                            color: Colors.white))),
                    ),
                    // Active indicator dot
                    Positioned(
                      bottom: 4, right: 4,
                      child: Container(
                        width: 16, height: 16,
                        decoration: BoxDecoration(
                          color: const Color(0xFF22C55E),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF0F2D1A), width: 2.5),
                        ),
                      ),
                    ),
                  ]),
                ),

                const SizedBox(height: 16),

                // Name + email
                SlideTransition(
                  position: Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero)
                      .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic)),
                  child: FadeTransition(
                    opacity: CurvedAnimation(parent: _ctrl, curve: const Interval(0.3, 1.0)),
                    child: Column(children: [
                      Text(user.name,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 22, fontWeight: FontWeight.w900,
                          color: Colors.white, letterSpacing: -0.5)),
                      const SizedBox(height: 4),
                      Text(user.email,
                        style: GoogleFonts.inter(
                          fontSize: 12, fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.4))),
                    ]),
                  ),
                ),

                const SizedBox(height: 16),

                // Chips
                FadeTransition(
                  opacity: CurvedAnimation(parent: _ctrl, curve: const Interval(0.4, 1.0)),
                  child: Wrap(
                    spacing: 7, runSpacing: 7,
                    alignment: WrapAlignment.center,
                    children: [
                      _Chip(roleLabel,
                        AppColors.accent.withValues(alpha: 0.2), AppColors.accent,
                        iconData: Icons.verified_rounded),
                      _Chip(user.shopName,
                        Colors.white.withValues(alpha: 0.1), Colors.white,
                        iconData: Icons.storefront_rounded),
                      _Chip(user.currency,
                        Colors.white.withValues(alpha: 0.1),
                        Colors.white.withValues(alpha: 0.7)),
                    ],
                  ),
                ),
              ]),
            ),

            // Stats bar at hero bottom
            Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.22),
                border: Border(
                  top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                ),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                children: [
                  _HeroStat(label: 'Role', value: roleLabel, icon: Icons.badge_outlined),
                  const _HeroStatDivider(),
                  _HeroStat(label: 'Shop', value: user.shopName, icon: Icons.storefront_outlined),
                  const _HeroStatDivider(),
                  _HeroStat(label: 'Currency', value: user.currency, icon: Icons.payments_outlined),
                ],
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────
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
                icon: Icons.call_rounded, label: 'Call',
                color: AppColors.success,
                onTap: () { Navigator.pop(context); _launchUrl('tel:$phone'); },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SupportBtn(
                icon: Icons.chat_rounded, label: 'WhatsApp',
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

  void _showChangePassword(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const _ChangePasswordSheet(),
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
          .then((set) { if (set == true) _loadPinStatus(); });
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
              child: const Icon(Icons.pin_outlined, color: AppColors.primary, size: 20)),
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
            icon: Icons.edit_outlined, label: 'Change PIN',
            color: AppColors.primary, bg: AppColors.primary.withValues(alpha: 0.08),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context)
                  .push(MaterialPageRoute(
                      builder: (_) => const PinSetupScreen(canDismiss: true, isChanging: true)))
                  .then((set) { if (set == true) _loadPinStatus(); });
            },
          ),
          const SizedBox(height: 10),
          _PinOptionBtn(
            icon: Icons.lock_open_outlined, label: 'Remove PIN',
            color: AppColors.danger, bg: AppColors.dangerBg,
            onTap: () { Navigator.pop(context); _confirmRemovePin(context); },
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
            decoration: const BoxDecoration(color: AppColors.dangerBg, shape: BoxShape.circle),
            child: const Icon(Icons.lock_open_rounded, color: AppColors.danger, size: 24)),
          const SizedBox(height: 16),
          Text('Remove PIN?', style: AppTextStyles.headingMedium),
          const SizedBox(height: 8),
          Text('The app will no longer require a PIN when opened.',
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
          Text('Version 1.0.15',
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

// ── Hero stat widget ──────────────────────────────────────────────────────────
class _HeroStat extends StatelessWidget {
  final String label, value;
  final IconData icon;
  const _HeroStat({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 15, color: Colors.white.withValues(alpha: 0.35)),
      const SizedBox(height: 4),
      Text(label.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 9, fontWeight: FontWeight.w700,
          color: Colors.white.withValues(alpha: 0.35), letterSpacing: 0.8)),
      const SizedBox(height: 3),
      Text(value,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white),
        overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, maxLines: 1),
    ]),
  );
}

class _HeroStatDivider extends StatelessWidget {
  const _HeroStatDivider();

  @override
  Widget build(BuildContext context) => Container(
    width: 1, height: 28,
    color: Colors.white.withValues(alpha: 0.1),
  );
}

// ── Section ────────────────────────────────────────────────────────────────────
class _Section extends StatelessWidget {
  final String title;
  final Color accentColor;
  final List<Widget> items;
  const _Section({required this.title, required this.accentColor, required this.items});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(left: 2, bottom: 9),
        child: Row(children: [
          Container(
            width: 6, height: 6,
            decoration: BoxDecoration(color: accentColor, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(title.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 10, fontWeight: FontWeight.w800,
              color: AppColors.textMuted, letterSpacing: 0.9)),
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
              if (!isLast) const Divider(height: 1, indent: 62, color: AppColors.borderLight),
            ]);
          }).toList(),
        ),
      ),
    ]),
  );
}

// ── Action tile (with optional subtitle) ──────────────────────────────────────
class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final Color color, bg;
  final VoidCallback onTap;
  const _ActionTile(this.icon, this.label, this.color, this.bg, {
    required this.onTap, this.subtitle,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(18),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: color, size: 19),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
              style: GoogleFonts.inter(
                fontSize: 14, fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
            if (subtitle != null) ...[
              const SizedBox(height: 1),
              Text(subtitle!,
                style: GoogleFonts.inter(
                  fontSize: 11, fontWeight: FontWeight.w500,
                  color: AppColors.textMuted),
                overflow: TextOverflow.ellipsis),
            ],
          ]),
        ),
        Icon(Icons.chevron_right_rounded,
          size: 17, color: AppColors.textMuted.withValues(alpha: 0.7)),
      ]),
    ),
  );
}

// ── PIN tile ──────────────────────────────────────────────────────────────────
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
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: (hasPin ? AppColors.success : AppColors.primary).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12)),
          child: Icon(
            hasPin ? Icons.lock_rounded : Icons.lock_open_rounded,
            color: hasPin ? AppColors.success : AppColors.primary,
            size: 19),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('App PIN Lock',
              style: GoogleFonts.inter(
                fontSize: 14, fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
            const SizedBox(height: 1),
            Text(
              hasPin ? 'Enabled — locks after 10 min idle' : 'Not set — tap to create a PIN',
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
          Icon(Icons.chevron_right_rounded,
            size: 17, color: AppColors.textMuted.withValues(alpha: 0.7)),
      ]),
    ),
  );
}

// ── Notification tile (inline toggle) ────────────────────────────────────────
class _NotificationTile extends StatelessWidget {
  final String? token;
  final String status;
  final bool isRegistering;
  final VoidCallback onToggle;

  const _NotificationTile({
    required this.token,
    required this.status,
    required this.isRegistering,
    required this.onToggle,
  });

  bool get _isActive => token != null && status.contains('uploaded');

  @override
  Widget build(BuildContext context) {
    final active = _isActive;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: active
                  ? [const Color(0xFF0F2D1A), const Color(0xFF1a4a2e)]
                  : [Colors.grey.shade200, Colors.grey.shade100],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            active ? Icons.notifications_active_rounded : Icons.notifications_off_rounded,
            color: active ? AppColors.accent : Colors.grey.shade400,
            size: 19,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Sale Notifications',
              style: GoogleFonts.inter(
                fontSize: 14, fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
            const SizedBox(height: 1),
            Text(status,
              style: GoogleFonts.inter(
                fontSize: 11, fontWeight: FontWeight.w500,
                color: active ? const Color(0xFF16A34A) : AppColors.textMuted),
              overflow: TextOverflow.ellipsis),
          ]),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: isRegistering ? null : onToggle,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 48, height: 26,
            padding: const EdgeInsets.all(2.5),
            decoration: BoxDecoration(
              color: active ? AppColors.primary : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(13),
              boxShadow: active ? [BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.25),
                blurRadius: 6, offset: const Offset(0, 2))] : [],
            ),
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              alignment: active ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 21, height: 21,
                decoration: BoxDecoration(
                  color: Colors.white, shape: BoxShape.circle,
                  boxShadow: [BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 3, offset: const Offset(0, 1))],
                ),
                child: isRegistering
                    ? Padding(
                        padding: const EdgeInsets.all(4.5),
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: active ? AppColors.primary : Colors.grey))
                    : null,
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

// ── Header chip ───────────────────────────────────────────────────────────────
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

// ── PIN option button ─────────────────────────────────────────────────────────
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
        color: bg, borderRadius: BorderRadius.circular(14),
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
        color: color, borderRadius: BorderRadius.circular(14),
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

// ── Logout confirmation sheet ─────────────────────────────────────────────────
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
        decoration: const BoxDecoration(color: AppColors.dangerBg, shape: BoxShape.circle),
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
                color: AppColors.bg, borderRadius: BorderRadius.circular(14),
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
            onTap: () { Navigator.pop(context); onConfirm(); },
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

// ── Change Password sheet ─────────────────────────────────────────────────────
class _ChangePasswordSheet extends StatefulWidget {
  const _ChangePasswordSheet();
  @override
  State<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<_ChangePasswordSheet> {
  final _currentCtrl = TextEditingController();
  final _newCtrl     = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _saving   = false;
  bool _showCurr = false;
  bool _showNew  = false;
  bool _showConf = false;
  String? _error;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final curr   = _currentCtrl.text.trim();
    final newPw  = _newCtrl.text.trim();
    final confPw = _confirmCtrl.text.trim();
    if (curr.isEmpty || newPw.isEmpty || confPw.isEmpty) {
      setState(() => _error = 'All fields are required.');
      return;
    }
    if (newPw.length < 8) {
      setState(() => _error = 'New password must be at least 8 characters.');
      return;
    }
    if (newPw != confPw) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      final res = await ApiService.changePassword(
        currentPassword: curr, newPassword: newPw, confirmPassword: confPw,
      );
      if (!mounted) return;
      if (res['ok'] == true) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password updated successfully'),
            backgroundColor: AppColors.success));
      } else {
        setState(() { _error = res['error'] ?? 'Failed to update password.'; _saving = false; });
      }
    } catch (_) {
      if (mounted) setState(() { _error = 'Network error. Please try again.'; _saving = false; });
    }
  }

  Widget _field(String label, TextEditingController ctrl, bool show, VoidCallback toggleShow) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
        style: GoogleFonts.inter(
          fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
      const SizedBox(height: 6),
      TextField(
        controller: ctrl, obscureText: !show,
        style: GoogleFonts.inter(fontSize: 15, color: AppColors.textPrimary),
        decoration: InputDecoration(
          filled: true, fillColor: AppColors.surface,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
          suffixIcon: GestureDetector(
            onTap: toggleShow,
            child: Icon(
              show ? Icons.visibility_off_rounded : Icons.visibility_rounded,
              size: 20, color: AppColors.textMuted)),
        ),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
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
          Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(13)),
              child: const Icon(Icons.lock_outline_rounded, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Text('Change Password',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18, fontWeight: FontWeight.w900,
                color: AppColors.textPrimary)),
          ]),
          const SizedBox(height: 24),
          _field('Current Password', _currentCtrl, _showCurr,
            () => setState(() => _showCurr = !_showCurr)),
          const SizedBox(height: 14),
          _field('New Password', _newCtrl, _showNew,
            () => setState(() => _showNew = !_showNew)),
          const SizedBox(height: 14),
          _field('Confirm New Password', _confirmCtrl, _showConf,
            () => setState(() => _showConf = !_showConf)),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.dangerBg, borderRadius: BorderRadius.circular(10)),
              child: Row(children: [
                const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_error!,
                    style: GoogleFonts.inter(
                      fontSize: 12, fontWeight: FontWeight.w500,
                      color: AppColors.danger))),
              ]),
            ),
          ],
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text('Update Password',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15, fontWeight: FontWeight.w800)),
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ]),
      ),
    );
  }
}

// ── How to Pay Screen ─────────────────────────────────────────────────────────
class HowToPayScreen extends StatelessWidget {
  const HowToPayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F2),
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text('How to Pay',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 17)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
        children: [
          // Header info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F2D1A), Color(0xFF1B4332)],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(
                color: const Color(0xFF0F2D1A).withValues(alpha: 0.3),
                blurRadius: 16, offset: const Offset(0, 6))]),
            child: Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  shape: BoxShape.circle),
                child: const Icon(Icons.payments_rounded,
                  color: Colors.white, size: 22)),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Send Payment To',
                  style: GoogleFonts.inter(
                    fontSize: 11, fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.5), letterSpacing: 0.5)),
                const SizedBox(height: 2),
                Text('SAID SAID',
                  style: GoogleFonts.inter(
                    fontSize: 18, fontWeight: FontWeight.w900,
                    color: Colors.white)),
                Text('MDSPro Subscription Payment',
                  style: GoogleFonts.inter(
                    fontSize: 11, color: Colors.white.withValues(alpha: 0.5))),
              ])),
            ]),
          ),

          const SizedBox(height: 20),

          // M-Pesa card
          _PayMethodCard(
            logo: _MpesaLogo(),
            networkName: 'M-Pesa',
            networkColor: const Color(0xFF00A651),
            bgColor: const Color(0xFFF0FDF4),
            borderColor: const Color(0xFF00A651),
            number: '0765 131 788',
            accountName: 'SAID SAID',
            steps: const [
              'Open M-Pesa on your Vodacom line',
              'Select "Lipa na M-Pesa" → "Send Money"',
              'Enter number: 0765131788',
              'Enter amount and confirm',
            ],
          ),

          const SizedBox(height: 16),

          // Selcom / Bank card
          _PayMethodCard(
            logo: _SelcomLogo(),
            networkName: 'Selcom / Bank',
            networkColor: const Color(0xFF005BAA),
            bgColor: const Color(0xFFEFF6FF),
            borderColor: const Color(0xFF005BAA),
            number: '0765 131 788',
            accountName: 'SAID SAID',
            steps: const [
              'Open Selcom or your bank app',
              'Select "Send Money" or "Mobile Transfer"',
              'Enter number: 0765131788',
              'Enter amount and confirm',
            ],
          ),

          const SizedBox(height: 24),

          // Note
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFDE68A))),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.info_outline_rounded,
                size: 18, color: Color(0xFFD97706)),
              const SizedBox(width: 10),
              Expanded(child: Text(
                'After payment, send your receipt to our support team via WhatsApp or call us to activate your subscription.',
                style: GoogleFonts.inter(
                  fontSize: 12, color: const Color(0xFF92400E), height: 1.5))),
            ]),
          ),
        ],
      ),
    );
  }
}

class _PayMethodCard extends StatelessWidget {
  final Widget logo;
  final String networkName;
  final Color networkColor, bgColor, borderColor;
  final String number, accountName;
  final List<String> steps;

  const _PayMethodCard({
    required this.logo, required this.networkName,
    required this.networkColor, required this.bgColor,
    required this.borderColor, required this.number,
    required this.accountName, required this.steps,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor.withValues(alpha: 0.2)),
        boxShadow: [BoxShadow(
          color: networkColor.withValues(alpha: 0.06),
          blurRadius: 12, offset: const Offset(0, 4))]),
      child: Column(children: [
        // Header band
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            border: Border(bottom: BorderSide(color: borderColor.withValues(alpha: 0.1)))),
          child: Row(children: [
            logo,
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(networkName,
                style: GoogleFonts.inter(
                  fontSize: 16, fontWeight: FontWeight.w800,
                  color: networkColor)),
              Text('Mobile Money', style: GoogleFonts.inter(
                fontSize: 11, color: networkColor.withValues(alpha: 0.6))),
            ]),
            const Spacer(),
            // Number chip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: networkColor,
                borderRadius: BorderRadius.circular(20)),
              child: Text(number,
                style: GoogleFonts.inter(
                  fontSize: 13, fontWeight: FontWeight.w800,
                  color: Colors.white, letterSpacing: 0.5)),
            ),
          ]),
        ),
        // Account name
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(children: [
            const Icon(Icons.person_outline_rounded, size: 15, color: Color(0xFF6B7280)),
            const SizedBox(width: 6),
            Text('Account Name:',
              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF6B7280))),
            const SizedBox(width: 6),
            Text(accountName,
              style: GoogleFonts.inter(
                fontSize: 13, fontWeight: FontWeight.w800,
                color: const Color(0xFF111827))),
          ]),
        ),
        // Steps
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(children: steps.asMap().entries.map((e) =>
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 20, height: 20,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: networkColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle),
                  child: Text('${e.key + 1}',
                    style: GoogleFonts.inter(
                      fontSize: 10, fontWeight: FontWeight.w800,
                      color: networkColor))),
                const SizedBox(width: 10),
                Expanded(child: Text(e.value,
                  style: GoogleFonts.inter(
                    fontSize: 12, color: const Color(0xFF374151), height: 1.4))),
              ]),
            ),
          ).toList()),
        ),
      ]),
    );
  }
}

class _MpesaLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: 40, height: 40,
    decoration: BoxDecoration(
      color: const Color(0xFF00A651),
      borderRadius: BorderRadius.circular(10)),
    alignment: Alignment.center,
    child: Text('M', style: GoogleFonts.inter(
      fontSize: 20, fontWeight: FontWeight.w900,
      color: Colors.white)),
  );
}

class _SelcomLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: 40, height: 40,
    decoration: BoxDecoration(
      color: const Color(0xFF005BAA),
      borderRadius: BorderRadius.circular(10)),
    alignment: Alignment.center,
    child: Text('S', style: GoogleFonts.inter(
      fontSize: 20, fontWeight: FontWeight.w900,
      color: Colors.white)),
  );
}

// ── Language tile ─────────────────────────────────────────────────────────────
class _LanguageTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = context.localeProviderWatch;
    final isSwahili = provider.isSwahili;

    return InkWell(
      onTap: () => _showLanguagePicker(context, provider),
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF0EA5E9).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.language_rounded,
              color: Color(0xFF0EA5E9), size: 19),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('App Language',
                style: GoogleFonts.inter(
                  fontSize: 14, fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
              const SizedBox(height: 1),
              Text(isSwahili ? 'Kiswahili' : 'English',
                style: GoogleFonts.inter(
                  fontSize: 11, fontWeight: FontWeight.w500,
                  color: AppColors.textMuted)),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF0EA5E9).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8)),
            child: Text(isSwahili ? 'SW' : 'EN',
              style: GoogleFonts.inter(
                fontSize: 11, fontWeight: FontWeight.w900,
                color: const Color(0xFF0EA5E9))),
          ),
          const SizedBox(width: 6),
          Icon(Icons.chevron_right_rounded,
            color: AppColors.textMuted, size: 18),
        ]),
      ),
    );
  }

  void _showLanguagePicker(BuildContext context, LocaleProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _LanguagePickerSheet(provider: provider),
    );
  }
}

// ── Language picker sheet ─────────────────────────────────────────────────────
class _LanguagePickerSheet extends StatelessWidget {
  final LocaleProvider provider;
  const _LanguagePickerSheet({required this.provider});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
    decoration: const BoxDecoration(
      color: AppColors.bg,
      borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 36, height: 4,
        decoration: BoxDecoration(
          color: AppColors.border,
          borderRadius: BorderRadius.circular(2))),
      const SizedBox(height: 20),
      Text('App Language',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 18, fontWeight: FontWeight.w900,
          color: AppColors.textPrimary)),
      const SizedBox(height: 6),
      Text('Lugha ya Programu',
        style: GoogleFonts.inter(
          fontSize: 12, color: AppColors.textMuted)),
      const SizedBox(height: 24),
      _LangOption(
        flag: '🇬🇧',
        name: 'English',
        subtitle: 'English',
        code: 'en',
        selected: !provider.isSwahili,
        onTap: () async {
          await provider.setLocale(const Locale('en'));
          if (context.mounted) Navigator.pop(context);
        },
      ),
      const SizedBox(height: 10),
      _LangOption(
        flag: '🇹🇿',
        name: 'Kiswahili',
        subtitle: 'Swahili',
        code: 'sw',
        selected: provider.isSwahili,
        onTap: () async {
          await provider.setLocale(const Locale('sw'));
          if (context.mounted) Navigator.pop(context);
        },
      ),
    ]),
  );
}

class _LangOption extends StatelessWidget {
  final String flag, name, subtitle, code;
  final bool selected;
  final VoidCallback onTap;
  const _LangOption({
    required this.flag, required this.name, required this.subtitle,
    required this.code, required this.selected, required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: selected
          ? AppColors.primary.withValues(alpha: 0.08)
          : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected ? AppColors.primary : AppColors.border,
          width: selected ? 1.5 : 1)),
      child: Row(children: [
        Text(flag, style: const TextStyle(fontSize: 24)),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15, fontWeight: FontWeight.w800,
                color: selected ? AppColors.primary : AppColors.textPrimary)),
            Text(subtitle,
              style: GoogleFonts.inter(
                fontSize: 11, color: AppColors.textMuted)),
          ]),
        ),
        if (selected)
          Container(
            width: 22, height: 22,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle),
            child: const Icon(Icons.check_rounded,
              color: Colors.white, size: 14)),
      ]),
    ),
  );
}
