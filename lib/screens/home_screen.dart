import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../services/update_service.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import 'dashboard_screen.dart';
import 'sales_screen.dart';
import 'stock_screen.dart';
import 'stock_adjustments_screen.dart';
import 'reports_screen.dart';
import 'profile_screen.dart';
import 'pos_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  int _tab = 0;
  AuthUser? _user;
  late AnimationController _navCtrl;
  final _tabNotifier = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    _navCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _loadUser();
  }

  Future<void> _loadUser() async {
    final u = await ApiService.getCachedUser();
    if (mounted) {
      setState(() => _user = u);
      _navCtrl.forward();
      NotificationService.startPolling();
      NotificationService.uploadToken();
      UpdateService.checkUpdate(context); // fire-and-forget, never throws
    }
  }

  @override
  void dispose() {
    NotificationService.stopPolling();
    _navCtrl.dispose();
    _tabNotifier.dispose();
    super.dispose();
  }

  bool get _isCashier => _user?.role == 'cashier';

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: AppColors.primary,
      statusBarIconBrightness: Brightness.light,
    ));

    final user = _user;
    if (user == null) {
      return const Scaffold(
        backgroundColor: AppColors.primary,
        body: Center(child: CircularProgressIndicator(color: AppColors.accent)),
      );
    }

    // Cashier: POS → Sales → Stock → Adjustments → Profile (filtered by permissions)
    // Owner/Manager/StockManager: Dashboard → Sales → POS → Stock → Reports → Profile (filtered by permissions)
    final List<Widget> screens;
    final List<_NavItem> navItems;

    if (_isCashier) {
      // All candidate tabs for cashier role with their module gate keys.
      // null key = always visible (Profile).
      final List<Widget> allScreens = [
        PosScreen(user: user, tabNotifier: _tabNotifier),
        SalesScreen(tabNotifier: _tabNotifier),
        StockScreen(tabNotifier: _tabNotifier),
        const StockAdjustmentsScreen(),
        ProfileScreen(user: user),
      ];
      const List<_NavItem> allNav = [
        _NavItem(Icons.point_of_sale_rounded, Icons.point_of_sale_outlined, 'POS'),
        _NavItem(Icons.receipt_rounded,       Icons.receipt_outlined,       'Sales'),
        _NavItem(Icons.inventory_2_rounded,   Icons.inventory_2_outlined,   'Products'),
        _NavItem(Icons.history_rounded,       Icons.history_outlined,       'Adjustments'),
        _NavItem(Icons.person_rounded,        Icons.person_outlined,        'Profile'),
      ];
      const List<String?> allKeys = [
        'pos', 'sales_history', 'stock', 'stock', null,
      ];
      final allowed = List.generate(allScreens.length, (i) => i)
          .where((i) => allKeys[i] == null || user.canAccess(allKeys[i]!))
          .toList();
      screens  = allowed.map((i) => allScreens[i]).toList();
      navItems = allowed.map((i) => allNav[i]).toList();
    } else {
      // All candidate tabs for owner/manager/stock_manager with their module gate keys.
      // null key = always visible (Dashboard home, Profile).
      final List<Widget> allScreens = [
        DashboardScreen(user: user, onTabSwitch: (i) => setState(() => _tab = i), tabNotifier: _tabNotifier),
        SalesScreen(tabNotifier: _tabNotifier),
        PosScreen(user: user, tabNotifier: _tabNotifier),
        StockScreen(tabNotifier: _tabNotifier),
        ReportsScreen(user: user),
        ProfileScreen(user: user),
      ];
      const List<_NavItem> allNav = [
        _NavItem(Icons.dashboard_rounded,     Icons.dashboard_outlined,     'Dashboard'),
        _NavItem(Icons.receipt_rounded,       Icons.receipt_outlined,       'Sales'),
        _NavItem(Icons.point_of_sale_rounded, Icons.point_of_sale_outlined, 'POS'),
        _NavItem(Icons.inventory_2_rounded,   Icons.inventory_2_outlined,   'Stock'),
        _NavItem(Icons.bar_chart_rounded,     Icons.bar_chart_outlined,     'Reports'),
        _NavItem(Icons.person_rounded,        Icons.person_outlined,        'Profile'),
      ];
      const List<String?> allKeys = [
        null, 'sales_history', 'pos', 'stock', 'report_sales', null,
      ];
      final allowed = List.generate(allScreens.length, (i) => i)
          .where((i) => allKeys[i] == null || user.canAccess(allKeys[i]!))
          .toList();
      screens  = allowed.map((i) => allScreens[i]).toList();
      navItems = allowed.map((i) => allNav[i]).toList();
    }

    // Guard tab index in case it's stale after role change
    final safeTab = _tab.clamp(0, screens.length - 1);
    final resp = Responsive.of(context);

    void onTabTap(int i) {
      setState(() => _tab = i);
      _tabNotifier.value = i;
    }

    if (resp.isTablet) {
      return Scaffold(
        body: FadeTransition(
          opacity: _navCtrl,
          child: Row(children: [
            _TabletNavRail(
              currentIndex: safeTab,
              items: navItems,
              onTap: onTabTap,
              user: user,
              extended: resp.isLargeTablet,
            ),
            Expanded(child: IndexedStack(index: safeTab, children: screens)),
          ]),
        ),
      );
    }

    return Scaffold(
      body: IndexedStack(index: safeTab, children: screens),
      bottomNavigationBar: FadeTransition(
        opacity: _navCtrl,
        child: _PremiumBottomNav(
          currentIndex: safeTab,
          items: navItems,
          onTap: onTabTap,
        ),
      ),
    );
  }
}

// ── Tablet side navigation rail ──────────────────────────────────────────────
class _TabletNavRail extends StatelessWidget {
  final int currentIndex;
  final List<_NavItem> items;
  final ValueChanged<int> onTap;
  final AuthUser user;
  final bool extended;

  const _TabletNavRail({
    required this.currentIndex, required this.items,
    required this.onTap, required this.user, this.extended = false,
  });

  @override
  Widget build(BuildContext context) {
    final railWidth = extended ? 200.0 : 76.0;
    return Container(
      width: railWidth,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF061410), Color(0xFF0F2D1A)],
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
        ),
        boxShadow: [BoxShadow(
          color: Color(0x22000000), blurRadius: 16, offset: Offset(4, 0))],
      ),
      child: SafeArea(
        child: Column(children: [
          // Brand logo / app name
          Padding(
            padding: EdgeInsets.symmetric(
              vertical: 20, horizontal: extended ? 16 : 10),
            child: extended
                ? Row(children: [
                    Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(
                          color: AppColors.accent.withValues(alpha: 0.3))),
                      child: const Icon(Icons.store_rounded,
                        color: AppColors.accent, size: 20)),
                    const SizedBox(width: 10),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('MDSPro',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13, fontWeight: FontWeight.w900,
                            color: Colors.white, letterSpacing: -0.3)),
                        Text(user.shopName,
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: Colors.white.withValues(alpha: 0.45),
                            fontWeight: FontWeight.w500)),
                      ],
                    )),
                  ])
                : Center(child: Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(
                        color: AppColors.accent.withValues(alpha: 0.3))),
                    child: const Icon(Icons.store_rounded,
                      color: AppColors.accent, size: 20))),
          ),
          Container(height: 1,
            color: Colors.white.withValues(alpha: 0.08),
            margin: const EdgeInsets.symmetric(horizontal: 12)),
          const SizedBox(height: 8),
          // Nav items
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: items.length,
              itemBuilder: (_, i) {
                final sel = i == currentIndex;
                final isPOS = items[i].label == 'POS';
                final activeColor = isPOS ? AppColors.accent : AppColors.accent;
                return Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: extended ? 10 : 8, vertical: 3),
                  child: GestureDetector(
                    onTap: () => onTap(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: EdgeInsets.symmetric(
                        horizontal: extended ? 12 : 10, vertical: 10),
                      decoration: BoxDecoration(
                        color: sel
                            ? activeColor.withValues(alpha: 0.15)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: sel
                            ? Border.all(
                                color: activeColor.withValues(alpha: 0.3),
                                width: 1)
                            : null,
                      ),
                      child: extended
                          ? Row(children: [
                              Icon(
                                sel ? items[i].activeIcon : items[i].icon,
                                size: 20,
                                color: sel
                                    ? activeColor
                                    : Colors.white.withValues(alpha: 0.5)),
                              const SizedBox(width: 12),
                              Text(items[i].label,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: sel
                                      ? FontWeight.w700 : FontWeight.w500,
                                  color: sel
                                      ? activeColor
                                      : Colors.white.withValues(alpha: 0.5))),
                            ])
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  sel ? items[i].activeIcon : items[i].icon,
                                  size: 20,
                                  color: sel
                                      ? activeColor
                                      : Colors.white.withValues(alpha: 0.5)),
                                const SizedBox(height: 4),
                                Text(items[i].label,
                                  style: GoogleFonts.inter(
                                    fontSize: 9,
                                    fontWeight: sel
                                        ? FontWeight.w700 : FontWeight.w500,
                                    color: sel
                                        ? activeColor
                                        : Colors.white.withValues(alpha: 0.45))),
                              ],
                            ),
                    ),
                  ),
                );
              },
            ),
          ),
          // User info at bottom
          Container(height: 1,
            color: Colors.white.withValues(alpha: 0.08),
            margin: const EdgeInsets.symmetric(horizontal: 12)),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: extended ? 14 : 8, vertical: 14),
            child: extended
                ? Row(children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: AppColors.accent.withValues(alpha: 0.2),
                      child: Text(user.name.isNotEmpty
                          ? user.name[0].toUpperCase() : 'U',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13, fontWeight: FontWeight.w800,
                          color: AppColors.accent))),
                    const SizedBox(width: 10),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user.name,
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 11, fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.85))),
                        Text(user.role,
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            color: Colors.white.withValues(alpha: 0.4),
                            fontWeight: FontWeight.w500)),
                      ],
                    )),
                  ])
                : Column(mainAxisSize: MainAxisSize.min, children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: AppColors.accent.withValues(alpha: 0.2),
                      child: Text(user.name.isNotEmpty
                          ? user.name[0].toUpperCase() : 'U',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12, fontWeight: FontWeight.w800,
                          color: AppColors.accent))),
                  ]),
          ),
        ]),
      ),
    );
  }
}

// ── Premium floating bottom nav ───────────────────────────────────────────────
class _PremiumBottomNav extends StatelessWidget {
  final int currentIndex;
  final List<_NavItem> items;
  final ValueChanged<int> onTap;

  const _PremiumBottomNav({
    required this.currentIndex,
    required this.items,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20, offset: const Offset(0, -4)),
          BoxShadow(color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6, offset: const Offset(0, -1)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: List.generate(items.length, (i) {
              final sel = i == currentIndex;
              // Highlight POS tab with accent colour
              final isPOS = items[i].label == 'POS';
              return Expanded(
                child: _NavTile(
                  item: items[i],
                  selected: sel,
                  isPOS: isPOS,
                  onTap: () => onTap(i),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavTile extends StatefulWidget {
  final _NavItem item;
  final bool selected;
  final bool isPOS;
  final VoidCallback onTap;
  const _NavTile({
    required this.item, required this.selected,
    required this.isPOS, required this.onTap,
  });

  @override
  State<_NavTile> createState() => _NavTileState();
}

class _NavTileState extends State<_NavTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 250));
    _scale = Tween<double>(begin: 1.0, end: 1.12)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
    if (widget.selected) _ctrl.forward();
  }

  @override
  void didUpdateWidget(_NavTile old) {
    super.didUpdateWidget(old);
    if (widget.selected != old.selected) {
      widget.selected ? _ctrl.forward() : _ctrl.reverse();
    }
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final activeColor = widget.isPOS ? AppColors.accent : AppColors.primary;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.scale(
              scale: _scale.value,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                decoration: BoxDecoration(
                  color: widget.selected
                      ? activeColor.withValues(alpha: 0.12) : Colors.transparent,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(
                  widget.selected ? widget.item.activeIcon : widget.item.icon,
                  size: 23,
                  color: widget.selected ? activeColor : AppColors.textMuted,
                ),
              ),
            ),
            const SizedBox(height: 2),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: widget.selected ? FontWeight.w800 : FontWeight.w500,
                color: widget.selected ? activeColor : AppColors.textMuted,
                letterSpacing: widget.selected ? -0.2 : 0,
              ),
              child: Text(widget.item.label),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData activeIcon;
  final IconData icon;
  final String label;
  const _NavItem(this.activeIcon, this.icon, this.label);
}
