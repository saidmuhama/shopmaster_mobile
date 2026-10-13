import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import 'dashboard_screen.dart';
import 'sales_screen.dart';
import 'stock_screen.dart';
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

    // Cashier: POS → Stock → Profile (3 tabs, branch-locked)
    // Owner/Manager/StockManager: Dashboard → Sales → POS → Stock → Reports → Profile (6 tabs)
    final List<Widget> screens;
    final List<_NavItem> navItems;

    if (_isCashier) {
      screens = [
        PosScreen(user: user),
        StockScreen(tabNotifier: _tabNotifier),
        ProfileScreen(user: user),
      ];
      navItems = const [
        _NavItem(Icons.point_of_sale_rounded,  Icons.point_of_sale_outlined,  'POS'),
        _NavItem(Icons.inventory_2_rounded,    Icons.inventory_2_outlined,    'Products'),
        _NavItem(Icons.person_rounded,         Icons.person_outlined,         'Profile'),
      ];
    } else {
      screens = [
        DashboardScreen(user: user, onTabSwitch: (i) => setState(() => _tab = i), tabNotifier: _tabNotifier),
        SalesScreen(tabNotifier: _tabNotifier),
        PosScreen(user: user),
        StockScreen(tabNotifier: _tabNotifier),
        ReportsScreen(user: user),
        ProfileScreen(user: user),
      ];
      navItems = const [
        _NavItem(Icons.dashboard_rounded,      Icons.dashboard_outlined,      'Dashboard'),
        _NavItem(Icons.receipt_rounded,        Icons.receipt_outlined,        'Sales'),
        _NavItem(Icons.point_of_sale_rounded,  Icons.point_of_sale_outlined,  'POS'),
        _NavItem(Icons.inventory_2_rounded,    Icons.inventory_2_outlined,    'Stock'),
        _NavItem(Icons.bar_chart_rounded,      Icons.bar_chart_outlined,      'Reports'),
        _NavItem(Icons.person_rounded,         Icons.person_outlined,         'Profile'),
      ];
    }

    // Guard tab index in case it's stale after role change
    final safeTab = _tab.clamp(0, screens.length - 1);

    return Scaffold(
      body: IndexedStack(index: safeTab, children: screens),
      bottomNavigationBar: FadeTransition(
        opacity: _navCtrl,
        child: _PremiumBottomNav(
          currentIndex: safeTab,
          items: navItems,
          onTap: (i) {
            setState(() => _tab = i);
            _tabNotifier.value = i; // triggers reload in Dashboard/Sales/Stock
          },
        ),
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
