import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/animations.dart';
import '../widgets/common_widgets.dart';
import 'home_screen.dart';

class DashboardScreen extends StatefulWidget {
  final AuthUser user;
  final void Function(int tab)? onTabSwitch;
  final ValueNotifier<int>? tabNotifier;
  const DashboardScreen({super.key, required this.user, this.onTabSwitch, this.tabNotifier});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  DashboardStats? _stats;
  List<SalesChartPoint> _chart = [];
  List<Branch> _branches = [];
  List<Sale> _recentSales = [];
  Branch? _activeBranch;
  bool _loading = true;
  String? _error;
  late AnimationController _listCtrl;

  @override
  void initState() {
    super.initState();
    _listCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1100));
    widget.tabNotifier?.addListener(_onTabVisible);
    _load();
  }

  void _onTabVisible() {
    // Reload when our tab (index 0) becomes active
    if (widget.tabNotifier?.value == 0) _load();
  }

  @override
  void dispose() {
    widget.tabNotifier?.removeListener(_onTabVisible);
    _listCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        ApiService.getDashboard(),
        ApiService.getWeeklyChart(),
        ApiService.getBranches(),
        ApiService.getSales(filter: 'today', page: 1),
      ]);
      if (!mounted) return;
      final branches = results[2] as List<Branch>;
      final active = branches.firstWhere(
        (b) => b.id == widget.user.branchId,
        orElse: () => branches.isNotEmpty
            ? branches.first
            : const Branch(id: 0, name: 'Main', code: '', isMain: true),
      );
      setState(() {
        _stats       = results[0] as DashboardStats;
        _chart       = results[1] as List<SalesChartPoint>;
        _branches    = branches;
        _activeBranch = active;
        _recentSales = (results[3] as List<Sale>).take(5).toList();
        _loading     = false;
      });
      _listCtrl.forward(from: 0);
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _switchBranch(Branch branch) async {
    Navigator.pop(context); // close the picker sheet
    try {
      final ok = await ApiService.switchBranch(branch.id);
      if (!ok || !mounted) return;

      // Update the cached user so HomeScreen reloads with the correct branchId
      await ApiService.updateCachedBranch(branch.id);
      if (!mounted) return;

      // Restart HomeScreen so every tab (POS, Stock, Sales, etc.) reloads fresh
      Navigator.of(context).pushAndRemoveUntil(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const HomeScreen(),
          transitionDuration: const Duration(milliseconds: 300),
          transitionsBuilder: (_, a, __, child) => FadeTransition(
            opacity: CurvedAnimation(parent: a, curve: Curves.easeOut),
            child: child,
          ),
        ),
        (_) => false,
      );
    } catch (_) {}
  }

  void _showBranchPicker() {
    // Cashiers are locked to their registered branch — no switching allowed
    if (widget.user.role == 'cashier') return;
    if (_branches.length <= 1) return;
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _BranchSheet(
          branches: _branches, active: _activeBranch, onSelect: _switchBranch),
    );
  }

  String _fmt(double v) =>
      '${widget.user.currency} ${NumberFormat('#,##0').format(v.round())}';

  String _fmtK(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
    return v.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Morning' : hour < 17 ? 'Afternoon' : 'Evening';
    final first = widget.user.name.split(' ').first;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: RefreshIndicator(
        color: AppColors.accent,
        backgroundColor: AppColors.primary,
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ── Header ────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: _Header(
                greeting: greeting, name: first,
                shopName: widget.user.shopName,
                activeBranch: _activeBranch,
                hasBranches: _branches.length > 1 && widget.user.role != 'cashier',
                onBranchTap: _showBranchPicker,
              ),
            ),

            if (_loading)
              SliverToBoxAdapter(child: _Shimmer())
            else if (_error != null)
              SliverFillRemaining(
                  child: ErrorState(message: _error!, onRetry: _load))
            else ...[
              // ── Revenue strip ─────────────────────────────────────────
              SliverToBoxAdapter(
                child: StaggeredItem(index: 0, controller: _listCtrl,
                  child: _RevenueStrip(
                    todayRevenue: _stats!.todayRevenue,
                    monthRevenue: _stats!.monthRevenue,
                    todayTx: _stats!.todayTransactions,
                    currency: widget.user.currency,
                    onNewSale: () => widget.onTabSwitch?.call(2),
                  )),
              ),

              // ── KPI row ───────────────────────────────────────────────
              SliverToBoxAdapter(
                child: StaggeredItem(index: 1, controller: _listCtrl,
                  child: _KpiRow(stats: _stats!, currency: widget.user.currency)),
              ),

              // ── Weekly chart ──────────────────────────────────────────
              if (_chart.isNotEmpty)
                SliverToBoxAdapter(
                  child: StaggeredItem(index: 2, controller: _listCtrl,
                    child: _WeeklyChart(points: _chart, currency: widget.user.currency)),
                ),

              // ── Recent sales ──────────────────────────────────────────
              if (_recentSales.isNotEmpty)
                SliverToBoxAdapter(
                  child: StaggeredItem(index: 3, controller: _listCtrl,
                    child: _RecentSales(
                        sales: _recentSales,
                        currency: widget.user.currency,
                        fmtFn: _fmt)),
                ),

              // ── Quick actions ─────────────────────────────────────────
              SliverToBoxAdapter(
                child: StaggeredItem(index: 4, controller: _listCtrl,
                  child: _QuickActions(
                    stats: _stats!,
                    currency: widget.user.currency,
                    onTabSwitch: widget.onTabSwitch,
                  )),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final String greeting, name, shopName;
  final Branch? activeBranch;
  final bool hasBranches;
  final VoidCallback onBranchTap;
  const _Header({required this.greeting, required this.name,
    required this.shopName, required this.activeBranch,
    required this.hasBranches, required this.onBranchTap});

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFF0a2012), Color(0xFF0F2D1A), Color(0xFF1a5c32)],
        begin: Alignment.topLeft, end: Alignment.bottomRight),
    ),
    child: Stack(children: [
      Positioned(top: -40, right: -30,
        child: PulsingOrb(size: 180,
          color: AppColors.primaryLight.withValues(alpha: 0.15),
          duration: const Duration(seconds: 8))),
      SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
          child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text('Good $greeting · ',
                    style: GoogleFonts.inter(
                      fontSize: 12, fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.45))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(10)),
                    child: Text(
                      DateFormat('EEE d MMM').format(DateTime.now()),
                      style: GoogleFonts.inter(
                        fontSize: 10, fontWeight: FontWeight.w700,
                        color: AppColors.accent)),
                  ),
                ]),
                const SizedBox(height: 3),
                Text(name,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 24, fontWeight: FontWeight.w900,
                    color: Colors.white, letterSpacing: -0.8, height: 1.1)),
                const SizedBox(height: 8),
                Row(children: [
                  _HeaderChip(
                    Icons.storefront_rounded, shopName, Colors.white.withValues(alpha: 0.08),
                    Colors.white.withValues(alpha: 0.7)),
                  const SizedBox(width: 7),
                  GestureDetector(
                    onTap: onBranchTap,
                    child: _HeaderChip(
                      Icons.location_on_rounded,
                      activeBranch?.name ?? 'Branch',
                      AppColors.accent.withValues(alpha: 0.18),
                      AppColors.accent,
                      trailing: hasBranches
                          ? Icon(Icons.keyboard_arrow_down_rounded,
                              size: 13, color: AppColors.accent)
                          : null,
                    ),
                  ),
                ]),
              ]),
            ),
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.accent, AppColors.accentDark],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.35),
                  blurRadius: 12, offset: const Offset(0, 4))],
              ),
              child: Center(
                child: Text(name.substring(0, 1).toUpperCase(),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20, fontWeight: FontWeight.w900,
                    color: Colors.white)),
              ),
            ),
          ]),
        ),
      ),
    ]),
  );
}

class _HeaderChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color bg, fg;
  final Widget? trailing;
  const _HeaderChip(this.icon, this.label, this.bg, this.fg, {this.trailing});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: fg.withValues(alpha: 0.2)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 10, color: fg),
      const SizedBox(width: 4),
      Text(label,
        style: GoogleFonts.inter(
          fontSize: 11, fontWeight: FontWeight.w700, color: fg),
        maxLines: 1, overflow: TextOverflow.ellipsis),
      if (trailing != null) ...[const SizedBox(width: 2), trailing!],
    ]),
  );
}

// ── Revenue strip ─────────────────────────────────────────────────────────────
class _RevenueStrip extends StatelessWidget {
  final double todayRevenue, monthRevenue;
  final int todayTx;
  final String currency;
  final VoidCallback? onNewSale;
  const _RevenueStrip({required this.todayRevenue, required this.monthRevenue,
    required this.todayTx, required this.currency, this.onNewSale});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
    child: Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF061410), Color(0xFF0F2D1A), Color(0xFF1a5c32)],
          begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(
          color: AppColors.primary.withValues(alpha: 0.4),
          blurRadius: 24, offset: const Offset(0, 10))],
      ),
      child: Stack(children: [
        Positioned(top: -30, right: -20,
          child: PulsingOrb(size: 160,
            color: AppColors.primaryLight.withValues(alpha: 0.1),
            duration: const Duration(seconds: 7))),
        Positioned(bottom: -20, left: 40,
          child: PulsingOrb(size: 100,
            color: AppColors.accent.withValues(alpha: 0.06),
            duration: const Duration(seconds: 10))),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Top row: live badge + sale count
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1))),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 6, height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFF4ADE80), shape: BoxShape.circle)),
                  const SizedBox(width: 5),
                  Text('Live  ·  ${DateFormat('d MMM').format(DateTime.now())}',
                    style: GoogleFonts.inter(
                      fontSize: 10, fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.6))),
                ]),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.accent.withValues(alpha: 0.25))),
                child: Text('$todayTx transactions',
                  style: GoogleFonts.inter(
                    fontSize: 10, fontWeight: FontWeight.w700,
                    color: AppColors.accent)),
              ),
            ]),
            const SizedBox(height: 14),

            // Revenue numbers
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(
                flex: 3,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Today\'s Revenue',
                    style: GoogleFonts.inter(
                      fontSize: 11, fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.45))),
                  const SizedBox(height: 3),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: CountUpText(
                      target: todayRevenue,
                      prefix: '$currency ',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 26, fontWeight: FontWeight.w900,
                        color: Colors.white, letterSpacing: -0.7),
                    ),
                  ),
                ]),
              ),
              Container(
                width: 1, height: 50,
                color: Colors.white.withValues(alpha: 0.1),
                margin: const EdgeInsets.symmetric(horizontal: 16)),
              Expanded(
                flex: 2,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('This Month',
                    style: GoogleFonts.inter(
                      fontSize: 11, fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.4))),
                  const SizedBox(height: 3),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: CountUpText(
                      target: monthRevenue,
                      prefix: '$currency ',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16, fontWeight: FontWeight.w900,
                        color: Colors.white.withValues(alpha: 0.8),
                        letterSpacing: -0.4),
                    ),
                  ),
                ]),
              ),
            ]),

            const SizedBox(height: 16),
            // Divider
            Container(height: 1, color: Colors.white.withValues(alpha: 0.08)),
            const SizedBox(height: 14),

            // New sale shortcut
            GestureDetector(
              onTap: onNewSale,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.accent, AppColors.accentDark],
                    begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.35),
                    blurRadius: 12, offset: const Offset(0, 4))]),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.add_circle_rounded, color: Colors.white, size: 17),
                  const SizedBox(width: 7),
                  Text('Start New Sale',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14, fontWeight: FontWeight.w900,
                      color: Colors.white, letterSpacing: -0.2)),
                ]),
              ),
            ),
          ]),
        ),
      ]),
    ),
  );
}

// ── KPI row (horizontal scroll) ───────────────────────────────────────────────
class _KpiRow extends StatelessWidget {
  final DashboardStats stats;
  final String currency;
  const _KpiRow({required this.stats, required this.currency});

  String _k(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
    return v.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    final kpis = [
      _Kpi(
        label: 'Transactions',
        value: stats.todayTransactions.toString(),
        sublabel: 'Today',
        icon: Icons.receipt_long_rounded,
        gradientStart: const Color(0xFF1E3A8A),
        gradientEnd: const Color(0xFF3B82F6),
        glowColor: const Color(0xFF2563EB),
      ),
      _Kpi(
        label: 'Expenses',
        value: '$currency ${_k(stats.monthExpenses)}',
        sublabel: 'This month',
        icon: Icons.trending_down_rounded,
        gradientStart: const Color(0xFF7F1D1D),
        gradientEnd: const Color(0xFFEF4444),
        glowColor: const Color(0xFFDC2626),
      ),
      _Kpi(
        label: 'Low Stock',
        value: stats.lowStockCount.toString(),
        sublabel: 'Items',
        icon: Icons.inventory_2_rounded,
        gradientStart: const Color(0xFF78350F),
        gradientEnd: const Color(0xFFF59E0B),
        glowColor: const Color(0xFFD97706),
      ),
      _Kpi(
        label: 'Credits Due',
        value: '$currency ${_k(stats.outstandingCredits)}',
        sublabel: 'Outstanding',
        icon: Icons.account_balance_wallet_rounded,
        gradientStart: const Color(0xFF3B0764),
        gradientEnd: const Color(0xFF8B5CF6),
        glowColor: const Color(0xFF7C3AED),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 14, 0, 0),
      child: SizedBox(
        height: 162,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          itemCount: kpis.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (_, i) => _KpiTile(kpi: kpis[i]),
        ),
      ),
    );
  }
}

class _Kpi {
  final String label, value, sublabel;
  final IconData icon;
  final Color gradientStart, gradientEnd, glowColor;
  const _Kpi({
    required this.label,
    required this.value,
    required this.sublabel,
    required this.icon,
    required this.gradientStart,
    required this.gradientEnd,
    required this.glowColor,
  });
}

class _KpiTile extends StatelessWidget {
  final _Kpi kpi;
  const _KpiTile({required this.kpi});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 152,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [kpi.gradientStart, kpi.gradientEnd],
          stops: const [0.0, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: kpi.glowColor.withValues(alpha: 0.38),
            blurRadius: 20, offset: const Offset(0, 8), spreadRadius: -3),
          BoxShadow(
            color: kpi.glowColor.withValues(alpha: 0.12),
            blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Stack(children: [
        // Decorative orb — top right
        Positioned(
          top: -22, right: -22,
          child: Container(
            width: 88, height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.08)),
          ),
        ),
        // Decorative orb — bottom left
        Positioned(
          bottom: -18, left: -18,
          child: Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.05)),
          ),
        ),
        // Content
        Padding(
          padding: const EdgeInsets.fromLTRB(15, 15, 15, 15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon pill
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.22), width: 1),
                ),
                child: Icon(kpi.icon, color: Colors.white, size: 20),
              ),
              const Spacer(),
              // Value
              Text(
                kpi.value,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 19, fontWeight: FontWeight.w900,
                  color: Colors.white, letterSpacing: -0.6, height: 1.1),
                maxLines: 1, overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              // Label + sublabel row
              Row(children: [
                Expanded(
                  child: Text(
                    kpi.label,
                    style: GoogleFonts.inter(
                      fontSize: 10.5, fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.85),
                      letterSpacing: 0.1),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    kpi.sublabel,
                    style: GoogleFonts.inter(
                      fontSize: 8, fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.80)),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ]),
    );
  }
}

// ── Weekly chart ───────────────────────────────────────────────────────────────
class _WeeklyChart extends StatelessWidget {
  final List<SalesChartPoint> points;
  final String currency;
  const _WeeklyChart({required this.points, required this.currency});

  @override
  Widget build(BuildContext context) {
    final maxVal = points.map((p) => p.value).fold(0.0, (a, b) => a > b ? a : b);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
          boxShadow: AppShadows.sm,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Weekly Sales',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14, fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary, letterSpacing: -0.2)),
                Text('Last 7 days performance',
                  style: GoogleFonts.inter(
                    fontSize: 11, fontWeight: FontWeight.w500,
                    color: AppColors.textMuted)),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(20)),
              child: Text('7 days',
                style: GoogleFonts.inter(
                  fontSize: 11, fontWeight: FontWeight.w700,
                  color: AppColors.primary)),
            ),
          ]),
          const SizedBox(height: 16),
          SizedBox(
            height: 120,
            child: BarChart(BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxVal * 1.3,
              barTouchData: BarTouchData(
                enabled: true,
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, gi, rod, ri) => BarTooltipItem(
                    '$currency ${NumberFormat('#,##0').format(rod.toY.round())}',
                    GoogleFonts.inter(
                        fontSize: 11, fontWeight: FontWeight.w700,
                        color: Colors.white),
                  ),
                ),
              ),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(sideTitles: SideTitles(
                  showTitles: true, reservedSize: 22,
                  getTitlesWidget: (v, _) {
                    final i = v.toInt();
                    if (i < 0 || i >= points.length) return const SizedBox();
                    final isToday = i == points.length - 1;
                    return Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Text(points[i].label,
                        style: GoogleFonts.inter(
                          fontSize: 10, fontWeight: FontWeight.w700,
                          color: isToday
                              ? AppColors.primary : AppColors.textMuted)),
                    );
                  },
                )),
                leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: FlGridData(
                show: true,
                horizontalInterval: maxVal > 0 ? maxVal * 0.5 : 1,
                getDrawingHorizontalLine: (_) => const FlLine(
                    color: AppColors.borderLight, strokeWidth: 1),
                drawVerticalLine: false,
              ),
              borderData: FlBorderData(show: false),
              barGroups: List.generate(points.length, (i) {
                final isToday = i == points.length - 1;
                return BarChartGroupData(x: i,
                  barRods: [BarChartRodData(
                    toY: points[i].value,
                    width: 18,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                    gradient: isToday
                        ? const LinearGradient(
                            colors: [AppColors.accent, AppColors.accentDark],
                            begin: Alignment.topCenter, end: Alignment.bottomCenter)
                        : const LinearGradient(
                            colors: [Color(0xFF1E6B3F), Color(0xFF0F2D1A)],
                            begin: Alignment.topCenter, end: Alignment.bottomCenter),
                  )],
                );
              }),
            )),
          ),
        ]),
      ),
    );
  }
}

// ── Recent sales mini list ─────────────────────────────────────────────────────
class _RecentSales extends StatelessWidget {
  final List<Sale> sales;
  final String currency;
  final String Function(double) fmtFn;
  const _RecentSales({required this.sales, required this.currency, required this.fmtFn});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
    child: Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.sm,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Row(children: [
            Expanded(
              child: Text('Recent Sales',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14, fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary, letterSpacing: -0.2)),
            ),
            Text('Today',
              style: GoogleFonts.inter(
                fontSize: 11, fontWeight: FontWeight.w600,
                color: AppColors.textMuted)),
          ]),
        ),
        const SizedBox(height: 8),
        ...sales.asMap().entries.map((e) {
          final s = e.value;
          final isLast = e.key == sales.length - 1;
          final statusColor = s.status == 'paid'
              ? AppColors.success
              : s.status == 'credit'
                  ? AppColors.warning
                  : AppColors.info;

          return Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10)),
                  child: Center(
                    child: Text(
                      s.customerName.isNotEmpty
                          ? s.customerName[0].toUpperCase() : '#',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15, fontWeight: FontWeight.w900,
                        color: statusColor)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.customerName.isNotEmpty ? s.customerName : 'Walk-in',
                        style: GoogleFonts.inter(
                          fontSize: 13, fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(s.invoiceNo,
                        style: GoogleFonts.inter(
                          fontSize: 11, fontWeight: FontWeight.w500,
                          color: AppColors.textMuted)),
                    ]),
                ),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(fmtFn(s.totalAmount),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13, fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary, letterSpacing: -0.3)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8)),
                    child: Text(s.status,
                      style: GoogleFonts.inter(
                        fontSize: 10, fontWeight: FontWeight.w700,
                        color: statusColor)),
                  ),
                ]),
              ]),
            ),
            if (!isLast)
              Divider(height: 1, thickness: 1,
                indent: 64, endIndent: 16,
                color: AppColors.borderLight),
          ]);
        }),
        const SizedBox(height: 4),
      ]),
    ),
  );
}

// ── Quick actions ─────────────────────────────────────────────────────────────
class _QuickActions extends StatelessWidget {
  final DashboardStats stats;
  final String currency;
  final void Function(int)? onTabSwitch;

  const _QuickActions({
    required this.stats,
    required this.currency,
    this.onTabSwitch,
  });

  String _k(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
    return v.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    final actions = [
      _ActionCard(
        icon: Icons.receipt_long_rounded,
        label: 'Sales',
        subtitle: '${stats.todayTransactions} today',
        color: AppColors.primary,
        bg: const Color(0xFFDCFCE7),
        badge: null,
        onTap: () => onTabSwitch?.call(1),
      ),
      _ActionCard(
        icon: Icons.bar_chart_rounded,
        label: 'Analytics',
        subtitle: '$currency ${_k(stats.monthRevenue)}',
        color: const Color(0xFF7C3AED),
        bg: const Color(0xFFEDE9FE),
        badge: null,
        onTap: () => onTabSwitch?.call(3),
      ),
      _ActionCard(
        icon: Icons.inventory_2_rounded,
        label: 'Inventory',
        subtitle: 'Manage stock',
        color: AppColors.info,
        bg: AppColors.infoBg,
        badge: null,
        onTap: () => onTabSwitch?.call(2),
      ),
      _ActionCard(
        icon: Icons.warning_amber_rounded,
        label: 'Low Stock',
        subtitle: '${stats.lowStockCount} items',
        color: AppColors.warning,
        bg: AppColors.warningBg,
        badge: stats.lowStockCount > 0 ? stats.lowStockCount.toString() : null,
        onTap: () => onTabSwitch?.call(2),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text('Quick Actions',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14, fontWeight: FontWeight.w800,
                color: AppColors.textPrimary, letterSpacing: -0.2)),
          ),
          Text('Tap to navigate',
            style: GoogleFonts.inter(
              fontSize: 11, fontWeight: FontWeight.w500,
              color: AppColors.textMuted)),
        ]),
        const SizedBox(height: 10),
        // 2 × 2 grid
        Column(children: [
          Row(children: [
            Expanded(child: _QuickActionTile(action: actions[0])),
            const SizedBox(width: 10),
            Expanded(child: _QuickActionTile(action: actions[1])),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _QuickActionTile(action: actions[2])),
            const SizedBox(width: 10),
            Expanded(child: _QuickActionTile(action: actions[3])),
          ]),
        ]),
      ]),
    );
  }
}

class _ActionCard {
  final IconData icon;
  final String label, subtitle;
  final Color color, bg;
  final String? badge;
  final VoidCallback onTap;
  const _ActionCard({
    required this.icon, required this.label, required this.subtitle,
    required this.color, required this.bg, required this.badge,
    required this.onTap,
  });
}

class _QuickActionTile extends StatelessWidget {
  final _ActionCard action;
  const _QuickActionTile({required this.action});

  @override
  Widget build(BuildContext context) => PressScale(
    onTap: action.onTap,
    child: Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(
          color: action.color.withValues(alpha: 0.08),
          blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Row(children: [
        Stack(clipBehavior: Clip.none, children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [action.color, action.color.withValues(alpha: 0.7)],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(
                color: action.color.withValues(alpha: 0.3),
                blurRadius: 8, offset: const Offset(0, 3))]),
            child: Icon(action.icon, color: Colors.white, size: 20)),
          if (action.badge != null)
            Positioned(
              top: -5, right: -5,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.danger,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white, width: 1.5)),
                child: Text(action.badge!,
                  style: GoogleFonts.inter(
                    fontSize: 9, fontWeight: FontWeight.w900,
                    color: Colors.white)))),
        ]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(action.label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13, fontWeight: FontWeight.w800,
                color: AppColors.textPrimary, letterSpacing: -0.2)),
            const SizedBox(height: 2),
            Text(action.subtitle,
              style: GoogleFonts.inter(
                fontSize: 11, fontWeight: FontWeight.w500,
                color: AppColors.textMuted),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          ]),
        ),
        Container(
          width: 24, height: 24,
          decoration: BoxDecoration(
            color: action.color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(7)),
          child: Icon(Icons.arrow_forward_rounded,
            size: 13, color: action.color)),
      ]),
    ),
  );
}

// ── Branch picker sheet ────────────────────────────────────────────────────────
class _BranchSheet extends StatelessWidget {
  final List<Branch> branches;
  final Branch? active;
  final void Function(Branch) onSelect;
  const _BranchSheet({required this.branches, required this.active, required this.onSelect});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
    decoration: BoxDecoration(
      color: AppColors.surface, borderRadius: BorderRadius.circular(24)),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Center(
        child: Container(
          margin: const EdgeInsets.only(top: 12, bottom: 8),
          width: 36, height: 4,
          decoration: BoxDecoration(
            color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
        child: Text('Switch Branch',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary))),
      ...branches.map((b) {
        final isActive = b.id == active?.id;
        return GestureDetector(
          onTap: () => onSelect(b),
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isActive ? AppColors.primary.withValues(alpha: 0.07) : AppColors.bg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isActive ? AppColors.primary.withValues(alpha: 0.3) : AppColors.border)),
            child: Row(children: [
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  color: isActive
                      ? AppColors.primary.withValues(alpha: 0.12)
                      : AppColors.border.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(10)),
                child: Icon(
                  b.isMain ? Icons.home_work_rounded : Icons.storefront_rounded,
                  size: 16,
                  color: isActive ? AppColors.primary : AppColors.textMuted)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(b.name,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14, fontWeight: FontWeight.w700,
                    color: isActive ? AppColors.primary : AppColors.textPrimary))),
              if (isActive)
                Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 18),
            ]),
          ),
        );
      }),
      const SizedBox(height: 8),
    ]),
  );
}

// ── Shimmer ───────────────────────────────────────────────────────────────────
class _Shimmer extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
    child: Column(children: [
      ShimmerBox(width: double.infinity, height: 120, radius: 22),
      const SizedBox(height: 12),
      SizedBox(height: 100,
        child: Row(children: [
          Expanded(child: ShimmerBox(width: double.infinity, height: 100, radius: 18)),
          const SizedBox(width: 10),
          Expanded(child: ShimmerBox(width: double.infinity, height: 100, radius: 18)),
          const SizedBox(width: 10),
          Expanded(child: ShimmerBox(width: double.infinity, height: 100, radius: 18)),
        ])),
      const SizedBox(height: 12),
      ShimmerBox(width: double.infinity, height: 160, radius: 20),
    ]),
  );
}
