import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/animations.dart';
import '../utils/responsive.dart';
import '../widgets/common_widgets.dart';
import 'home_screen.dart';
import 'stock_adjustments_screen.dart';

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
  List<BranchStats> _branchStats = [];
  CashierStats? _cashierStats;
  int _pendingApprovals = 0;

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
      final isCashier = widget.user.role == 'cashier';

      if (isCashier) {
        final results = await Future.wait([
          ApiService.getDashboard(),
          ApiService.getCashierStats(),
          ApiService.getBranches(),
          ApiService.getSales(filter: 'today', page: 1),
        ]);
        if (!mounted) return;
        final branches = results[2] as List<Branch>;
        setState(() {
          _stats        = results[0] as DashboardStats;
          _cashierStats = results[1] as CashierStats;
          _branches     = branches;
          _activeBranch = branches.firstWhere(
            (b) => b.id == widget.user.branchId,
            orElse: () => branches.isNotEmpty
                ? branches.first
                : const Branch(id: 0, name: 'Main', code: '', isMain: true),
          );
          _recentSales  = (results[3] as List<Sale>).take(5).toList();
          _loading      = false;
        });
      } else {
        final results = await Future.wait([
          ApiService.getDashboard(),
          ApiService.getWeeklyChart(),
          ApiService.getBranches(),
          ApiService.getSales(filter: 'today', page: 1),
          ApiService.getAllBranchStats(),
          ApiService.getPendingAdjustments(),
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
          _stats             = results[0] as DashboardStats;
          _chart             = results[1] as List<SalesChartPoint>;
          _branches          = branches;
          _activeBranch      = active;
          _recentSales       = (results[3] as List<Sale>).take(5).toList();
          _branchStats       = results[4] as List<BranchStats>;
          _pendingApprovals  = (results[5] as List<PendingAdjustment>).length;
          _loading           = false;
        });
      }
      _listCtrl.forward(from: 0);
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Widget _buildRevenueSection() {
    final isCashier = widget.user.role == 'cashier';

    if (isCashier && _cashierStats != null) {
      return _CashierShiftCard(
        stats: _stats!,
        cashierStats: _cashierStats!,
        currency: widget.user.currency,
        onNewSale: () => widget.onTabSwitch?.call(2),
      );
    }

    if (_branchStats.length > 1) {
      return _BranchCarousel(
        branches: _branchStats,
        currency: widget.user.currency,
        activeBranchId: _activeBranch?.id ?? 0,
        onNewSale: () => widget.onTabSwitch?.call(2),
      );
    }

    return _RevenueStrip(
      todayRevenue: _stats!.todayRevenue,
      monthRevenue: _stats!.monthRevenue,
      todayTx: _stats!.todayTransactions,
      currency: widget.user.currency,
      onNewSale: () => widget.onTabSwitch?.call(2),
    );
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

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Morning' : hour < 17 ? 'Afternoon' : 'Evening';
    final first = widget.user.name.split(' ').first;

    final resp = Responsive.of(context);
    final isCashier = widget.user.role == 'cashier';

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
                hasBranches: _branches.length > 1 && !isCashier,
                onBranchTap: _showBranchPicker,
              ),
            ),

            if (_loading)
              SliverToBoxAdapter(child: _Shimmer())
            else if (_error != null)
              SliverFillRemaining(
                  child: ErrorState(message: _error!, onRetry: _load))
            else ...[
              // ── Revenue / Branch carousel / Cashier shift card ────────
              SliverToBoxAdapter(
                child: StaggeredItem(index: 0, controller: _listCtrl,
                  child: _buildRevenueSection()),
              ),

              // ── Pending approvals alert (owner/manager only) ──────────
              if (!isCashier && _pendingApprovals > 0)
                SliverToBoxAdapter(
                  child: StaggeredItem(index: 0, controller: _listCtrl,
                    child: _PendingApprovalsCard(
                      count: _pendingApprovals,
                      onTap: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => const StockAdjustmentsScreen())),
                    )),
                ),

              // ── KPI row (not shown for cashier) ───────────────────────
              if (!isCashier)
                SliverToBoxAdapter(
                  child: StaggeredItem(index: 1, controller: _listCtrl,
                    child: _KpiRow(stats: _stats!, currency: widget.user.currency)),
                ),

              // ── Large tablet: chart + recent side-by-side ─────────────
              if (!isCashier && resp.isLargeTablet && _chart.isNotEmpty && _recentSales.isNotEmpty)
                SliverToBoxAdapter(
                  child: StaggeredItem(index: 2, controller: _listCtrl,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 6,
                            child: _WeeklyChart(points: _chart, currency: widget.user.currency)),
                          const SizedBox(width: 16),
                          Expanded(flex: 4,
                            child: _RecentSales(
                              sales: _recentSales,
                              currency: widget.user.currency,
                              fmtFn: _fmt,
                              label: 'Recent Sales')),
                        ],
                      ),
                    )),
                )
              else ...[
                // ── Weekly chart (not shown for cashier, not large tablet side-by-side) ─
                if (!isCashier && _chart.isNotEmpty)
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
                          fmtFn: _fmt,
                          label: isCashier ? 'My Recent Sales' : 'Recent Sales')),
                  ),
              ],

              // ── Quick actions ─────────────────────────────────────────
              SliverToBoxAdapter(
                child: StaggeredItem(index: 4, controller: _listCtrl,
                  child: _QuickActions(
                    stats: _stats!,
                    currency: widget.user.currency,
                    onTabSwitch: widget.onTabSwitch,
                    isCashier: isCashier,
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
          colors: [Color(0xFF050F08), Color(0xFF0A2015), Color(0xFF0F2D1A)],
          begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.5),
            blurRadius: 32, spreadRadius: -4, offset: const Offset(0, 12)),
          BoxShadow(
            color: const Color(0xFF2D6A4F).withValues(alpha: 0.2),
            blurRadius: 60, spreadRadius: 0, offset: const Offset(0, 4)),
        ],
      ),
      child: Stack(children: [
        // Geometric accent — top right corner glow
        Positioned(top: -50, right: -40,
          child: Container(
            width: 200, height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                const Color(0xFF2D6A4F).withValues(alpha: 0.25),
                Colors.transparent,
              ]),
            ),
          ),
        ),
        // Accent line at top
        Positioned(top: 0, left: 32, right: 32,
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                Colors.transparent,
                Colors.white.withValues(alpha: 0.12),
                Colors.transparent,
              ]),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Top row: live badge + transactions
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF166534).withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF4ADE80).withValues(alpha: 0.25))),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 5, height: 5,
                    decoration: const BoxDecoration(
                      color: Color(0xFF4ADE80), shape: BoxShape.circle)),
                  const SizedBox(width: 5),
                  Text('LIVE  ·  ${DateFormat('d MMM').format(DateTime.now())}',
                    style: GoogleFonts.inter(
                      fontSize: 9, fontWeight: FontWeight.w800,
                      color: const Color(0xFF4ADE80),
                      letterSpacing: 0.8)),
                ]),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1))),
                child: Text('$todayTx txns',
                  style: GoogleFonts.inter(
                    fontSize: 10, fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.55))),
              ),
            ]),

            const SizedBox(height: 18),

            // Main revenue figure
            Text("TODAY'S REVENUE",
              style: GoogleFonts.inter(
                fontSize: 9, fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: 0.35),
                letterSpacing: 1.2)),
            const SizedBox(height: 5),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: CountUpText(
                target: todayRevenue,
                prefix: '$currency ',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 34, fontWeight: FontWeight.w900,
                  color: Colors.white, letterSpacing: -1.0, height: 1.0),
              ),
            ),

            const SizedBox(height: 16),

            // Month + Profit sub-row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('MONTH',
                      style: GoogleFonts.inter(
                        fontSize: 8, fontWeight: FontWeight.w800,
                        color: Colors.white.withValues(alpha: 0.3), letterSpacing: 0.8)),
                    const SizedBox(height: 2),
                    CountUpText(
                      target: monthRevenue,
                      prefix: '$currency ',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14, fontWeight: FontWeight.w900,
                        color: Colors.white.withValues(alpha: 0.85), letterSpacing: -0.3),
                    ),
                  ]),
                ),
                Container(width: 1, height: 28,
                  color: Colors.white.withValues(alpha: 0.1)),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 14),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('STATUS',
                        style: GoogleFonts.inter(
                          fontSize: 8, fontWeight: FontWeight.w800,
                          color: Colors.white.withValues(alpha: 0.3), letterSpacing: 0.8)),
                      const SizedBox(height: 2),
                      Row(children: [
                        Container(width: 6, height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFF4ADE80), shape: BoxShape.circle)),
                        const SizedBox(width: 5),
                        Text('Active',
                          style: GoogleFonts.inter(
                            fontSize: 13, fontWeight: FontWeight.w700,
                            color: const Color(0xFF4ADE80))),
                      ]),
                    ]),
                  ),
                ),
              ]),
            ),

            const SizedBox(height: 14),

            // New Sale CTA
            GestureDetector(
              onTap: onNewSale,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF4A261), Color(0xFFD97706)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accent.withValues(alpha: 0.45),
                      blurRadius: 16, offset: const Offset(0, 6)),
                  ]),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.add_circle_rounded, color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Text('New Sale',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14, fontWeight: FontWeight.w900,
                      color: Colors.white, letterSpacing: 0.1)),
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
      _Kpi(
        label: 'P&L',
        value: '${stats.monthNetProfit >= 0 ? '+' : '-'}$currency ${_k(stats.monthNetProfit.abs())}',
        sublabel: 'This month',
        icon: stats.monthNetProfit >= 0
            ? Icons.trending_up_rounded
            : Icons.trending_down_rounded,
        gradientStart: stats.monthNetProfit >= 0
            ? const Color(0xFF064E3B)
            : const Color(0xFF7F1D1D),
        gradientEnd: stats.monthNetProfit >= 0
            ? const Color(0xFF10B981)
            : const Color(0xFFEF4444),
        glowColor: stats.monthNetProfit >= 0
            ? const Color(0xFF059669)
            : const Color(0xFFDC2626),
        subValue: '$currency ${_k(stats.monthGrossProfit)}',
        subValueLabel: 'Gross profit',
        profit: stats.monthNetProfit >= 0,
      ),
    ];

    final resp = Responsive.of(context);

    if (resp.isTablet) {
      return Padding(
        padding: EdgeInsets.fromLTRB(resp.hPad, 14, resp.hPad, 0),
        child: GridView.count(
          crossAxisCount: resp.isLargeTablet ? 4 : 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: resp.isLargeTablet ? 1.55 : 1.95,
          children: kpis.map((k) => _KpiTile(kpi: k)).toList(),
        ),
      );
    }

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
  // P&L extras
  final String? subValue;
  final String? subValueLabel;
  final bool profit; // true = positive value shown in green, false = red
  const _Kpi({
    required this.label,
    required this.value,
    required this.sublabel,
    required this.icon,
    required this.gradientStart,
    required this.gradientEnd,
    required this.glowColor,
    this.subValue,
    this.subValueLabel,
    this.profit = true,
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
              // P&L sub-value (gross profit line)
              if (kpi.subValue != null) ...[
                const SizedBox(height: 3),
                Row(children: [
                  Text(kpi.subValueLabel ?? '',
                    style: GoogleFonts.inter(
                      fontSize: 8, color: Colors.white.withValues(alpha: 0.5))),
                  const SizedBox(width: 4),
                  Text(kpi.subValue!,
                    style: GoogleFonts.inter(
                      fontSize: 8, fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.75))),
                ]),
              ],
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

// ── Weekly chart — premium line area ──────────────────────────────────────────
class _WeeklyChart extends StatelessWidget {
  final List<SalesChartPoint> points;
  final String currency;
  const _WeeklyChart({required this.points, required this.currency});

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const SizedBox.shrink();
    final maxVal = points.map((p) => p.value).fold(0.0, (a, b) => a > b ? a : b);
    final total  = points.fold(0.0, (s, p) => s + p.value);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.border),
          boxShadow: AppShadows.sm,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(width: 3, height: 14,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.accent, AppColors.accentDark],
                          begin: Alignment.topCenter, end: Alignment.bottomCenter),
                        borderRadius: BorderRadius.circular(2))),
                    const SizedBox(width: 8),
                    Text('Weekly Revenue',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14, fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary, letterSpacing: -0.2)),
                  ]),
                  const SizedBox(height: 3),
                  Padding(
                    padding: const EdgeInsets.only(left: 11),
                    child: Text('$currency ${NumberFormat('#,##0').format(total.round())} this week',
                      style: GoogleFonts.inter(
                        fontSize: 11, fontWeight: FontWeight.w500,
                        color: AppColors.textMuted)),
                  ),
                ]),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(20)),
                child: Text('7D',
                  style: GoogleFonts.inter(
                    fontSize: 11, fontWeight: FontWeight.w700,
                    color: AppColors.primary)),
              ),
            ]),
          ),

          const SizedBox(height: 14),

          // Line area chart
          SizedBox(
            height: 130,
            child: LineChart(LineChartData(
              minY: 0,
              maxY: maxVal * 1.25,
              clipData: const FlClipData.all(),
              lineTouchData: LineTouchData(
                enabled: true,
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (spots) => spots.map((s) => LineTooltipItem(
                    '$currency ${NumberFormat('#,##0').format(s.y.round())}',
                    GoogleFonts.inter(
                      fontSize: 11, fontWeight: FontWeight.w800,
                      color: Colors.white),
                  )).toList(),
                ),
              ),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(sideTitles: SideTitles(
                  showTitles: true, reservedSize: 24,
                  getTitlesWidget: (v, _) {
                    final i = v.toInt();
                    if (i < 0 || i >= points.length) return const SizedBox();
                    final isToday = i == points.length - 1;
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(points[i].label,
                        style: GoogleFonts.inter(
                          fontSize: 9.5, fontWeight: FontWeight.w700,
                          color: isToday ? AppColors.accent : const Color(0xFFCBD5E1))),
                    );
                  },
                )),
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: maxVal > 0 ? maxVal * 0.5 : 1,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: const Color(0xFFF1F5F9), strokeWidth: 1),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: List.generate(points.length,
                    (i) => FlSpot(i.toDouble(), points[i].value)),
                  isCurved: true, curveSmoothness: 0.35,
                  color: AppColors.primary,
                  barWidth: 2.5,
                  isStrokeCapRound: true,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, _, __, i) {
                      final isToday = i == points.length - 1;
                      return FlDotCirclePainter(
                        radius: isToday ? 5.0 : 3.0,
                        color: isToday ? AppColors.accent : AppColors.primary,
                        strokeWidth: isToday ? 2.5 : 1.5,
                        strokeColor: Colors.white,
                      );
                    },
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withValues(alpha: 0.15),
                        AppColors.primary.withValues(alpha: 0.0),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ],
            )),
          ),
          const SizedBox(height: 4),
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
  final String label;
  const _RecentSales({required this.sales, required this.currency, required this.fmtFn, this.label = 'Recent Sales'});

  static IconData _methodIcon(String method) {
    switch (method.toLowerCase()) {
      case 'mpesa':   return Icons.phone_android_rounded;
      case 'tigo':    return Icons.phone_android_rounded;
      case 'airtel':  return Icons.phone_android_rounded;
      case 'bank':    return Icons.account_balance_rounded;
      case 'wallet':  return Icons.account_balance_wallet_rounded;
      case 'credit':  return Icons.credit_card_rounded;
      default:        return Icons.payments_rounded; // cash
    }
  }

  static Color _methodColor(String method) {
    switch (method.toLowerCase()) {
      case 'mpesa':   return const Color(0xFF16A34A);
      case 'tigo':    return const Color(0xFF0284C7);
      case 'airtel':  return const Color(0xFFDC2626);
      case 'bank':    return const Color(0xFF1D4ED8);
      case 'wallet':  return const Color(0xFF7C3AED);
      case 'credit':  return const Color(0xFFD97706);
      default:        return const Color(0xFF059669);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
    child: Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.sm,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
          child: Row(children: [
            Row(children: [
              Container(width: 3, height: 14,
                decoration: BoxDecoration(
                  color: AppColors.success,
                  borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 8),
              Text(label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14, fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary, letterSpacing: -0.2)),
            ]),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.success.withValues(alpha: 0.2))),
              child: Text('Today',
                style: GoogleFonts.inter(
                  fontSize: 10, fontWeight: FontWeight.w700,
                  color: AppColors.success)),
            ),
          ]),
        ),
        const SizedBox(height: 10),
        ...sales.asMap().entries.map((e) {
          final s = e.value;
          final isLast = e.key == sales.length - 1;
          final statusColor = s.status == 'paid'
              ? AppColors.success
              : s.status == 'credit'
                  ? AppColors.warning
                  : AppColors.info;
          final mColor = _methodColor(s.paymentMethod);

          return Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 9, 16, 9),
              child: Row(children: [
                // Payment method icon
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: mColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: mColor.withValues(alpha: 0.15))),
                  child: Icon(_methodIcon(s.paymentMethod), size: 18, color: mColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.customerName.isNotEmpty ? s.customerName : 'Walk-in Customer',
                        style: GoogleFonts.inter(
                          fontSize: 13, fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Row(children: [
                        Text(s.invoiceNo,
                          style: GoogleFonts.inter(
                            fontSize: 10, fontWeight: FontWeight.w500,
                            color: AppColors.textMuted)),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: mColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(5)),
                          child: Text(s.paymentMethod.toUpperCase(),
                            style: GoogleFonts.inter(
                              fontSize: 8, fontWeight: FontWeight.w800,
                              color: mColor, letterSpacing: 0.3)),
                        ),
                      ]),
                    ]),
                ),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(fmtFn(s.totalAmount),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13, fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary, letterSpacing: -0.3)),
                  const SizedBox(height: 3),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8)),
                    child: Text(s.status.toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: 8.5, fontWeight: FontWeight.w800,
                        color: statusColor, letterSpacing: 0.3)),
                  ),
                ]),
              ]),
            ),
            if (!isLast)
              Container(height: 1,
                margin: const EdgeInsets.only(left: 68, right: 16),
                color: const Color(0xFFF1F5F9)),
          ]);
        }),
        const SizedBox(height: 6),
      ]),
    ),
  );
}

// ── Quick actions ─────────────────────────────────────────────────────────────
class _QuickActions extends StatelessWidget {
  final DashboardStats stats;
  final String currency;
  final void Function(int)? onTabSwitch;
  final bool isCashier;

  const _QuickActions({
    required this.stats,
    required this.currency,
    this.onTabSwitch,
    this.isCashier = false,
  });

  String _k(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
    return v.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    final actions = isCashier ? [
      _ActionCard(
        icon: Icons.add_shopping_cart_rounded,
        label: 'New Sale',
        subtitle: 'Start a transaction',
        color: AppColors.primary,
        bg: const Color(0xFFDCFCE7),
        badge: null,
        onTap: () => onTabSwitch?.call(2),
      ),
      _ActionCard(
        icon: Icons.receipt_long_rounded,
        label: 'My Sales',
        subtitle: '${stats.todayTransactions} today',
        color: const Color(0xFF0284C7),
        bg: const Color(0xFFE0F2FE),
        badge: null,
        onTap: () => onTabSwitch?.call(1),
      ),
    ] : [
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
        Column(children: [
          Row(children: [
            Expanded(child: _QuickActionTile(action: actions[0])),
            const SizedBox(width: 10),
            Expanded(child: _QuickActionTile(action: actions[1])),
          ]),
          if (actions.length > 2) ...[
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _QuickActionTile(action: actions[2])),
              const SizedBox(width: 10),
              Expanded(child: _QuickActionTile(action: actions[3])),
            ]),
          ],
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

// ── Pending approvals notification card ───────────────────────────────────────
class _PendingApprovalsCard extends StatelessWidget {
  final int count;
  final VoidCallback onTap;
  const _PendingApprovalsCard({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFDE68A), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
              blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(13),
              boxShadow: [BoxShadow(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                blurRadius: 8, offset: const Offset(0, 3))]),
            child: Stack(clipBehavior: Clip.none, children: [
              const Center(child: Icon(Icons.pending_actions_rounded,
                size: 20, color: Colors.white)),
              Positioned(
                top: -5, right: -5,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white, width: 1.5)),
                  child: Text('$count',
                    style: GoogleFonts.inter(
                      fontSize: 9, fontWeight: FontWeight.w900,
                      color: Colors.white)),
                ),
              ),
            ]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$count Pending Approval${count > 1 ? 's' : ''}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14, fontWeight: FontWeight.w800,
                  color: const Color(0xFF78350F), letterSpacing: -0.2)),
              const SizedBox(height: 2),
              Text('Stock adjustments from branches need your review',
                style: GoogleFonts.inter(
                  fontSize: 11, fontWeight: FontWeight.w500,
                  color: const Color(0xFF92400E))),
            ]),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B),
              borderRadius: BorderRadius.circular(10)),
            child: Text('Review',
              style: GoogleFonts.inter(
                fontSize: 11, fontWeight: FontWeight.w800,
                color: Colors.white)),
          ),
        ]),
      ),
    ),
  );
}

// ── Branch carousel ───────────────────────────────────────────────────────────
class _BranchCarousel extends StatefulWidget {
  final List<BranchStats> branches;
  final String currency;
  final int activeBranchId;
  final VoidCallback? onNewSale;
  const _BranchCarousel({
    required this.branches, required this.currency,
    required this.activeBranchId, this.onNewSale,
  });
  @override
  State<_BranchCarousel> createState() => _BranchCarouselState();
}

class _BranchCarouselState extends State<_BranchCarousel> {
  late PageController _ctrl;
  int _page = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    final idx = widget.branches.indexWhere(
        (b) => b.branchId == widget.activeBranchId);
    _page = idx < 0 ? 0 : idx;
    _ctrl = PageController(initialPage: _page);
    if (widget.branches.length > 1) _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted || !_ctrl.hasClients) return;
      final next = (_page + 1) % widget.branches.length;
      _ctrl.animateToPage(next,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic);
    });
  }

  @override
  void dispose() { _timer?.cancel(); _ctrl.dispose(); super.dispose(); }

  // Sort by today's revenue descending to determine rank
  List<int> get _rankedIds {
    final sorted = [...widget.branches]
      ..sort((a, b) => b.todayRevenue.compareTo(a.todayRevenue));
    return sorted.map((b) => b.branchId).toList();
  }

  @override
  Widget build(BuildContext context) {
    final ranked = _rankedIds;
    final maxRev = widget.branches.isEmpty ? 1.0
        : widget.branches.map((b) => b.todayRevenue).reduce((a, b) => a > b ? a : b);
    final maxProfit = widget.branches.isEmpty ? 1.0
        : widget.branches.map((b) => b.monthProfit.abs()).fold(0.0, (a, b) => a > b ? a : b);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Swipeable branch cards ──────────────────────────────────────
        SizedBox(
          height: 380,
          child: PageView.builder(
            controller: _ctrl,
            itemCount: widget.branches.length,
            onPageChanged: (i) {
              setState(() => _page = i);
              _timer?.cancel();
              if (widget.branches.length > 1) _startTimer();
            },
            itemBuilder: (_, i) => _BranchCard(
              branch: widget.branches[i],
              currency: widget.currency,
              isActive: widget.branches[i].branchId == widget.activeBranchId,
              rank: ranked.indexOf(widget.branches[i].branchId) + 1,
              totalBranches: widget.branches.length,
              onNewSale: widget.onNewSale,
            ),
          ),
        ),

        // ── Dot indicators ──────────────────────────────────────────────
        if (widget.branches.length > 1) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.branches.length, (i) =>
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: _page == i ? 22 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: _page == i ? AppColors.accent : const Color(0xFFD1D5DB),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ],

        // ── Corporate performance comparison panel ──────────────────────
        if (widget.branches.length > 1) ...[
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFF0F0F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 20, offset: const Offset(0, 6)),
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.04),
                    blurRadius: 40, offset: const Offset(0, 12)),
                ],
              ),
              child: Column(children: [
                // Header
                Container(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0B1E10),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Row(children: [
                    Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8)),
                      child: Icon(Icons.leaderboard_rounded,
                          size: 16, color: AppColors.accent),
                    ),
                    const SizedBox(width: 10),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Branch Performance',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13, fontWeight: FontWeight.w800,
                          color: Colors.white, letterSpacing: -0.2)),
                      Text("Today's ranking by revenue",
                        style: GoogleFonts.inter(
                          fontSize: 9, color: Colors.white.withValues(alpha: 0.45))),
                    ]),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08))),
                      child: Text(DateFormat('d MMM').format(DateTime.now()),
                        style: GoogleFonts.inter(
                          fontSize: 9, fontWeight: FontWeight.w700,
                          color: Colors.white.withValues(alpha: 0.5))),
                    ),
                  ]),
                ),

                // Column headers
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 6),
                  child: Row(children: [
                    const SizedBox(width: 30),
                    const SizedBox(width: 10),
                    Expanded(flex: 3, child: Text('Branch',
                      style: GoogleFonts.inter(
                        fontSize: 8, fontWeight: FontWeight.w800,
                        color: const Color(0xFF9CA3AF), letterSpacing: 0.6))),
                    Expanded(flex: 4, child: Text('Revenue', textAlign: TextAlign.end,
                      style: GoogleFonts.inter(
                        fontSize: 8, fontWeight: FontWeight.w800,
                        color: const Color(0xFF9CA3AF), letterSpacing: 0.6))),
                    Expanded(flex: 3, child: Text('Profit', textAlign: TextAlign.end,
                      style: GoogleFonts.inter(
                        fontSize: 8, fontWeight: FontWeight.w800,
                        color: const Color(0xFF9CA3AF), letterSpacing: 0.6))),
                    Expanded(flex: 3, child: Text('Txns', textAlign: TextAlign.end,
                      style: GoogleFonts.inter(
                        fontSize: 8, fontWeight: FontWeight.w800,
                        color: const Color(0xFF9CA3AF), letterSpacing: 0.6))),
                  ]),
                ),

                const Divider(height: 1, color: Color(0xFFF3F4F6)),

                // Branch rows
                ...ranked.asMap().entries.map((e) {
                  final rank = e.key;
                  final b = widget.branches.firstWhere((x) => x.branchId == e.value);
                  final isViewing = widget.branches[_page].branchId == b.branchId;
                  final pct = maxRev > 0 ? b.todayRevenue / maxRev : 0.0;
                  final profitPositive = b.monthProfit >= 0;

                  // Rank colors
                  const rankColors = [Color(0xFFF59E0B), Color(0xFF94A3B8), Color(0xFFCD7F32)];
                  final rankColor = rank < 3 ? rankColors[rank] : const Color(0xFFD1D5DB);
                  final rankEmoji = rank == 0 ? '🥇' : rank == 1 ? '🥈' : rank == 2 ? '🥉' : '';

                  final fmtShort = (double v) {
                    if (v >= 1000000) return '${(v/1000000).toStringAsFixed(1)}M';
                    if (v >= 1000)    return '${(v/1000).toStringAsFixed(0)}K';
                    return v.toInt().toString();
                  };

                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    color: isViewing
                        ? AppColors.primary.withValues(alpha: 0.03)
                        : Colors.transparent,
                    child: Column(children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 11, 18, 11),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                          // Rank
                          SizedBox(
                            width: 30,
                            child: rank < 3
                                ? Text(rankEmoji, style: const TextStyle(fontSize: 16))
                                : Container(
                                    width: 22, height: 22,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF9FAFB),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: const Color(0xFFE5E7EB))),
                                    child: Center(
                                      child: Text('${rank + 1}',
                                        style: GoogleFonts.inter(
                                          fontSize: 9, fontWeight: FontWeight.w900,
                                          color: const Color(0xFF9CA3AF))))),
                          ),
                          const SizedBox(width: 8),
                          // Branch name + bar
                          Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(b.branchName,
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: isViewing ? FontWeight.w800 : FontWeight.w600,
                                color: isViewing
                                    ? AppColors.textPrimary
                                    : const Color(0xFF6B7280))),
                            const SizedBox(height: 4),
                            LayoutBuilder(builder: (ctx, cons) => Stack(children: [
                              Container(
                                height: 4,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF3F4F6),
                                  borderRadius: BorderRadius.circular(2))),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 900),
                                curve: Curves.easeOutExpo,
                                height: 4,
                                width: cons.maxWidth * pct,
                                decoration: BoxDecoration(
                                  color: rankColor,
                                  borderRadius: BorderRadius.circular(2))),
                            ])),
                          ])),
                          // Revenue
                          Expanded(flex: 4, child: Text(
                            '${widget.currency} ${fmtShort(b.todayRevenue)}',
                            textAlign: TextAlign.end,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12, fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary))),
                          // Profit
                          Expanded(flex: 3, child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Icon(
                                profitPositive
                                    ? Icons.arrow_drop_up_rounded
                                    : Icons.arrow_drop_down_rounded,
                                size: 14,
                                color: profitPositive
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFFEF4444)),
                              Text(fmtShort(b.monthProfit.abs()),
                                style: GoogleFonts.inter(
                                  fontSize: 11, fontWeight: FontWeight.w700,
                                  color: profitPositive
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFFEF4444))),
                            ],
                          )),
                          // Txns
                          Expanded(flex: 3, child: Text(
                            b.todayTransactions.toString(),
                            textAlign: TextAlign.end,
                            style: GoogleFonts.inter(
                              fontSize: 12, fontWeight: FontWeight.w700,
                              color: const Color(0xFF6B7280)))),
                        ]),
                      ),
                      if (rank < ranked.length - 1)
                        const Divider(height: 1, color: Color(0xFFF9FAFB), indent: 56),
                    ]),
                  );
                }),

                // Footer note
                Container(
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: Color(0xFFF3F4F6))),
                  ),
                  child: Row(children: [
                    Icon(Icons.info_outline_rounded, size: 11, color: const Color(0xFFD1D5DB)),
                    const SizedBox(width: 5),
                    Text('Revenue = today · Profit = this month · Swipe cards above',
                      style: GoogleFonts.inter(
                        fontSize: 9, color: const Color(0xFFD1D5DB))),
                  ]),
                ),
              ]),
            ),
          ),
        ],
      ],
    );
  }
}

class _BranchCard extends StatelessWidget {
  final BranchStats branch;
  final String currency;
  final bool isActive;
  final int rank;
  final int totalBranches;
  final VoidCallback? onNewSale;
  const _BranchCard({
    required this.branch, required this.currency,
    required this.isActive, required this.rank, required this.totalBranches,
    this.onNewSale,
  });

  String _fmt(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000)    return '${(v / 1000).toStringAsFixed(0)}K';
    return NumberFormat('#,###').format(v.toInt());
  }

  @override
  Widget build(BuildContext context) {
    final profitColor = branch.todayProfit >= 0
        ? const Color(0xFF4ADE80) : const Color(0xFFFF6B6B);
    final profitIcon = branch.todayProfit >= 0
        ? Icons.trending_up_rounded : Icons.trending_down_rounded;
    final marginPct = branch.todayRevenue > 0
        ? (branch.todayProfit / branch.todayRevenue * 100).abs().toStringAsFixed(1)
        : '0.0';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF050F08), Color(0xFF081A0F), Color(0xFF0F2D1A)],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.45),
              blurRadius: 28, spreadRadius: -4, offset: const Offset(0, 10)),
          ],
        ),
        child: Stack(children: [
          // Glow
          Positioned(top: -60, right: -50,
            child: Container(
              width: 220, height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  const Color(0xFF2D6A4F).withValues(alpha: 0.2),
                  Colors.transparent,
                ]),
              ),
            ),
          ),
          Positioned(bottom: -30, left: -20,
            child: Container(
              width: 120, height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  AppColors.accent.withValues(alpha: 0.08),
                  Colors.transparent,
                ]),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // ── Header row ────────────────────────────────────────────
              Row(children: [
                Container(width: 3, height: 16,
                  decoration: BoxDecoration(
                    color: AppColors.accent, borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(branch.branchName,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 13, fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.8))),
                ),
                const SizedBox(width: 8),
                // Rank badge
                if (totalBranches > 1)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: rank == 1
                          ? const Color(0xFFF59E0B).withValues(alpha: 0.2)
                          : Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: rank == 1
                            ? const Color(0xFFF59E0B).withValues(alpha: 0.4)
                            : Colors.white.withValues(alpha: 0.1))),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (rank == 1) ...[
                        const Text('🥇', style: TextStyle(fontSize: 10)),
                        const SizedBox(width: 3),
                      ],
                      Text('#$rank of $totalBranches',
                        style: GoogleFonts.inter(
                          fontSize: 9, fontWeight: FontWeight.w800,
                          color: rank == 1
                              ? const Color(0xFFF59E0B)
                              : Colors.white.withValues(alpha: 0.5))),
                    ]),
                  ),
                const SizedBox(width: 6),
                // Active dot + txn count
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1))),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(width: 5, height: 5,
                      decoration: BoxDecoration(
                        color: isActive ? const Color(0xFF4ADE80) : Colors.white.withValues(alpha: 0.3),
                        shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                    Text('${branch.todayTransactions} txns',
                      style: GoogleFonts.inter(
                        fontSize: 9, fontWeight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: 0.5))),
                  ]),
                ),
              ]),

              const SizedBox(height: 14),

              // ── Today Revenue ─────────────────────────────────────────
              Text("TODAY'S REVENUE",
                style: GoogleFonts.inter(
                  fontSize: 9, fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.35), letterSpacing: 1.2)),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: CountUpText(
                  target: branch.todayRevenue,
                  prefix: '$currency ',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 32, fontWeight: FontWeight.w900,
                    color: Colors.white, letterSpacing: -1.0, height: 1.0),
                ),
              ),

              const SizedBox(height: 6),

              // ── Today Profit ──────────────────────────────────────────
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: profitColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: profitColor.withValues(alpha: 0.25))),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(profitIcon, size: 12, color: profitColor),
                    const SizedBox(width: 4),
                    Text('$currency ${_fmt(branch.todayProfit.abs())}',
                      style: GoogleFonts.inter(
                        fontSize: 11, fontWeight: FontWeight.w700,
                        color: profitColor)),
                    const SizedBox(width: 4),
                    Text('profit today',
                      style: GoogleFonts.inter(
                        fontSize: 10, fontWeight: FontWeight.w500,
                        color: profitColor.withValues(alpha: 0.7))),
                  ]),
                ),
                const SizedBox(width: 8),
                Text('$marginPct% margin',
                  style: GoogleFonts.inter(
                    fontSize: 10, color: Colors.white.withValues(alpha: 0.3))),
              ]),

              const SizedBox(height: 14),

              // ── Month stats row ───────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Row(children: [
                  // Month revenue
                  Expanded(child: _StatCell(
                    label: 'MONTH REVENUE',
                    value: '$currency ${_fmt(branch.monthRevenue)}',
                    valueColor: Colors.white.withValues(alpha: 0.9),
                  )),
                  Container(width: 1, height: 32, color: Colors.white.withValues(alpha: 0.08)),
                  // Month profit
                  Expanded(child: Padding(
                    padding: const EdgeInsets.only(left: 14),
                    child: _StatCell(
                      label: 'MONTH PROFIT',
                      value: '$currency ${_fmt(branch.monthProfit.abs())}',
                      valueColor: branch.monthProfit >= 0
                          ? const Color(0xFF4ADE80)
                          : const Color(0xFFFF6B6B),
                      prefix: branch.monthProfit >= 0 ? '▲ ' : '▼ ',
                    ),
                  )),
                ]),
              ),

              const SizedBox(height: 14),

              // ── New Sale button ───────────────────────────────────────
              GestureDetector(
                onTap: onNewSale,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF4A261), Color(0xFFD97706)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(
                      color: AppColors.accent.withValues(alpha: 0.4),
                      blurRadius: 14, offset: const Offset(0, 5))]),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.add_circle_rounded, color: Colors.white, size: 16),
                    const SizedBox(width: 8),
                    Text('New Sale',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14, fontWeight: FontWeight.w900,
                        color: Colors.white, letterSpacing: 0.1)),
                  ]),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  final String prefix;
  const _StatCell({
    required this.label, required this.value, required this.valueColor,
    this.prefix = '',
  });
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label,
        style: GoogleFonts.inter(
          fontSize: 7, fontWeight: FontWeight.w800,
          color: Colors.white.withValues(alpha: 0.3), letterSpacing: 0.8)),
      const SizedBox(height: 4),
      Text('$prefix$value',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 13, fontWeight: FontWeight.w800,
          color: valueColor, letterSpacing: -0.2),
        maxLines: 1, overflow: TextOverflow.ellipsis),
    ],
  );
}

// ── Cashier shift card ────────────────────────────────────────────────────────
class _CashierShiftCard extends StatelessWidget {
  final DashboardStats stats;
  final CashierStats cashierStats;
  final String currency;
  final VoidCallback? onNewSale;
  const _CashierShiftCard({required this.stats, required this.cashierStats,
    required this.currency, this.onNewSale});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
    child: Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF050F08), Color(0xFF0A2015), Color(0xFF0F2D1A)],
          begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.5),
            blurRadius: 32, spreadRadius: -4, offset: const Offset(0, 12)),
          BoxShadow(
            color: const Color(0xFF2D6A4F).withValues(alpha: 0.2),
            blurRadius: 60, spreadRadius: 0, offset: const Offset(0, 4)),
        ],
      ),
      child: Stack(children: [
        Positioned(top: -50, right: -40,
          child: Container(
            width: 200, height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                AppColors.accent.withValues(alpha: 0.15),
                Colors.transparent,
              ]),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // MY SHIFT badge + sale count
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.accent.withValues(alpha: 0.3))),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 5, height: 5,
                    decoration: BoxDecoration(
                      color: AppColors.accent, shape: BoxShape.circle)),
                  const SizedBox(width: 5),
                  Text('MY SHIFT  ·  ${DateFormat('d MMM').format(DateTime.now())}',
                    style: GoogleFonts.inter(
                      fontSize: 9, fontWeight: FontWeight.w800,
                      color: AppColors.accent, letterSpacing: 0.8)),
                ]),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1))),
                child: Text('${cashierStats.myTransactions} sales',
                  style: GoogleFonts.inter(
                    fontSize: 10, fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.55))),
              ),
            ]),

            const SizedBox(height: 18),

            Text('MY SALES TODAY',
              style: GoogleFonts.inter(
                fontSize: 9, fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: 0.35), letterSpacing: 1.2)),
            const SizedBox(height: 5),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: CountUpText(
                target: cashierStats.myRevenue,
                prefix: '$currency ',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 34, fontWeight: FontWeight.w900,
                  color: Colors.white, letterSpacing: -1.0, height: 1.0),
              ),
            ),

            const SizedBox(height: 14),

            // Branch total + avg sale
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('BRANCH TODAY',
                      style: GoogleFonts.inter(
                        fontSize: 8, fontWeight: FontWeight.w800,
                        color: Colors.white.withValues(alpha: 0.3), letterSpacing: 0.8)),
                    const SizedBox(height: 2),
                    CountUpText(
                      target: stats.todayRevenue,
                      prefix: '$currency ',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14, fontWeight: FontWeight.w900,
                        color: Colors.white.withValues(alpha: 0.85), letterSpacing: -0.3),
                    ),
                  ]),
                ),
                Container(width: 1, height: 28, color: Colors.white.withValues(alpha: 0.1)),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 14),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('AVG SALE',
                        style: GoogleFonts.inter(
                          fontSize: 8, fontWeight: FontWeight.w800,
                          color: Colors.white.withValues(alpha: 0.3), letterSpacing: 0.8)),
                      const SizedBox(height: 2),
                      Text(
                        cashierStats.myTransactions > 0
                            ? '$currency ${NumberFormat('#,##0').format((cashierStats.myRevenue / cashierStats.myTransactions).round())}'
                            : '—',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14, fontWeight: FontWeight.w900,
                          color: Colors.white.withValues(alpha: 0.85), letterSpacing: -0.3)),
                    ]),
                  ),
                ),
              ]),
            ),

            // Payment method chips
            if (cashierStats.paymentMethods.isNotEmpty) ...[
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: cashierStats.paymentMethods.map((m) {
                    final method = m['method'] as String? ?? '';
                    final total  = (m['total'] as num?)?.toDouble() ?? 0.0;
                    final count  = (m['count'] as num?)?.toInt() ?? 0;
                    return Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.12))),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(method.toUpperCase(),
                          style: GoogleFonts.inter(
                            fontSize: 8, fontWeight: FontWeight.w800,
                            color: Colors.white.withValues(alpha: 0.45), letterSpacing: 0.5)),
                        const SizedBox(width: 6),
                        Text('$currency ${NumberFormat('#,##0').format(total.round())}',
                          style: GoogleFonts.inter(
                            fontSize: 10, fontWeight: FontWeight.w700,
                            color: Colors.white.withValues(alpha: 0.85))),
                        const SizedBox(width: 4),
                        Text('($count)',
                          style: GoogleFonts.inter(
                            fontSize: 8, color: Colors.white.withValues(alpha: 0.4))),
                      ]),
                    );
                  }).toList(),
                ),
              ),
            ],

            const SizedBox(height: 14),

            GestureDetector(
              onTap: onNewSale,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF4A261), Color(0xFFD97706)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.45),
                    blurRadius: 16, offset: const Offset(0, 6))]),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.add_circle_rounded, color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Text('New Sale',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14, fontWeight: FontWeight.w900,
                      color: Colors.white, letterSpacing: 0.1)),
                ]),
              ),
            ),
          ]),
        ),
      ]),
    ),
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
