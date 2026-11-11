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
import '../utils/l10n_ext.dart';
import '../widgets/common_widgets.dart';
import 'home_screen.dart';
import 'stock_adjustments_screen.dart';
import 'product_profit_screen.dart';

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
  StockValueSummary? _stockValues;

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
          ApiService.getStockValues(),
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
          _stockValues       = results[6] as StockValueSummary;
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
        user: widget.user,
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
      backgroundColor: const Color(0xFFF2F4F7),
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

              // ── Stock Value Card (not for cashier) ───────────────────
              if (!isCashier && _stockValues != null)
                SliverToBoxAdapter(
                  child: StaggeredItem(index: 2, controller: _listCtrl,
                    child: _StockValueCard(
                      summary: _stockValues!,
                      currency: widget.user.currency,
                    )),
                ),

              // ── All tablets: chart + recent side-by-side ─────────────
              if (!isCashier && resp.isTablet && _chart.isNotEmpty && _recentSales.isNotEmpty)
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
                              label: context.l10n.recentSales)),
                        ],
                      ),
                    )),
                )
              else ...[
                // ── Weekly chart (not shown for cashier, not tablet side-by-side) ─
                if (!isCashier && _chart.isNotEmpty)
                  SliverToBoxAdapter(
                    child: StaggeredItem(index: 3, controller: _listCtrl,
                      child: _WeeklyChart(points: _chart, currency: widget.user.currency)),
                  ),

                // ── Recent sales ──────────────────────────────────────────
                if (_recentSales.isNotEmpty)
                  SliverToBoxAdapter(
                    child: StaggeredItem(index: 4, controller: _listCtrl,
                      child: _RecentSales(
                          sales: _recentSales,
                          currency: widget.user.currency,
                          fmtFn: _fmt,
                          label: isCashier ? context.l10n.myRecentSales : context.l10n.recentSales)),
                  ),
              ],

              // ── Quick actions ─────────────────────────────────────────
              SliverToBoxAdapter(
                child: StaggeredItem(index: 5, controller: _listCtrl,
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
        child: Builder(builder: (ctx) {
          final resp = Responsive.of(ctx);
          return Padding(
          padding: EdgeInsets.fromLTRB(resp.hPad, 16, resp.hPad, 22),
          child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text('Good $greeting · ',
                    style: GoogleFonts.inter(
                      fontSize: resp.isTablet ? 14 : 12, fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.45))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(10)),
                    child: Text(
                      DateFormat('EEE d MMM').format(DateTime.now()),
                      style: GoogleFonts.inter(
                        fontSize: resp.isTablet ? 12 : 10, fontWeight: FontWeight.w700,
                        color: AppColors.accent)),
                  ),
                ]),
                const SizedBox(height: 3),
                Text(name,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: resp.isTablet ? 30 : 24, fontWeight: FontWeight.w900,
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
              width: resp.isTablet ? 54 : 46,
              height: resp.isTablet ? 54 : 46,
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
                    fontSize: resp.isTablet ? 24 : 20, fontWeight: FontWeight.w900,
                    color: Colors.white)),
              ),
            ),
          ]),
        );
      }),
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
  Widget build(BuildContext context) {
    final resp = Responsive.of(context);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: resp.isTablet ? 11 : 9,
        vertical: resp.isTablet ? 6 : 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withValues(alpha: 0.2)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: resp.isTablet ? 13 : 10, color: fg),
        const SizedBox(width: 4),
        Text(label,
          style: GoogleFonts.inter(
            fontSize: resp.isTablet ? 13 : 11,
            fontWeight: FontWeight.w700, color: fg),
          maxLines: 1, overflow: TextOverflow.ellipsis),
        if (trailing != null) ...[const SizedBox(width: 2), trailing!],
      ]),
    );
  }
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
  Widget build(BuildContext context) {
    final resp = Responsive.of(context);
    return Padding(
    padding: EdgeInsets.fromLTRB(resp.hPad, 16, resp.hPad, 0),
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
          padding: EdgeInsets.all(resp.isTablet ? 24 : 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
                      fontSize: resp.isTablet ? 11 : 9, fontWeight: FontWeight.w800,
                      color: const Color(0xFF4ADE80), letterSpacing: 0.8)),
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
                    fontSize: resp.isTablet ? 12 : 10, fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.55))),
              ),
            ]),
            const SizedBox(height: 18),
            Text(context.l10n.todaysRevenueLabel,
              style: GoogleFonts.inter(
                fontSize: resp.isTablet ? 11 : 9, fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: 0.35), letterSpacing: 1.2)),
            const SizedBox(height: 5),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: CountUpText(
                target: todayRevenue,
                prefix: '$currency ',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: resp.isTablet ? 42 : 34, fontWeight: FontWeight.w900,
                  color: Colors.white, letterSpacing: -1.0, height: 1.0),
              ),
            ),
            const SizedBox(height: 16),
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
                    Text(context.l10n.monthLabel,
                      style: GoogleFonts.inter(
                        fontSize: resp.isTablet ? 10 : 8, fontWeight: FontWeight.w800,
                        color: Colors.white.withValues(alpha: 0.3), letterSpacing: 0.8)),
                    const SizedBox(height: 2),
                    CountUpText(
                      target: monthRevenue,
                      prefix: '$currency ',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: resp.isTablet ? 18 : 14, fontWeight: FontWeight.w900,
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
                      Text(context.l10n.statusLabel,
                        style: GoogleFonts.inter(
                          fontSize: resp.isTablet ? 10 : 8, fontWeight: FontWeight.w800,
                          color: Colors.white.withValues(alpha: 0.3), letterSpacing: 0.8)),
                      const SizedBox(height: 2),
                      Row(children: [
                        Container(width: 6, height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFF4ADE80), shape: BoxShape.circle)),
                        const SizedBox(width: 5),
                        Text(context.l10n.activeLabel,
                          style: GoogleFonts.inter(
                            fontSize: resp.isTablet ? 15 : 13, fontWeight: FontWeight.w700,
                            color: const Color(0xFF4ADE80))),
                      ]),
                    ]),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 14),
            GestureDetector(
              onTap: onNewSale,
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: resp.isTablet ? 15 : 13),
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
                  Text(context.l10n.newSaleBtn,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: resp.isTablet ? 16 : 14, fontWeight: FontWeight.w900,
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
        child: LayoutBuilder(builder: (ctx, cons) {
          final cols = resp.isLargeTablet ? 4 : 2;
          final spacing = 12.0;
          final tileW = (cons.maxWidth - spacing * (cols - 1)) / cols;
          // Tile content min height: padding(18)*2 + icon(50) + value(30) + label(18) + gap(8) = 142
          // Add 20px breathing room → target 162px min
          final tileH = tileW < 160 ? tileW / 0.95 : 162.0;
          final ratio = tileW / tileH;
          return GridView.count(
            crossAxisCount: cols,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
            childAspectRatio: ratio,
            children: kpis.map((k) => _KpiTile(kpi: k)).toList(),
          );
        }),
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
    final resp = Responsive.of(context);
    final p = resp.isTablet ? 18.0 : 15.0;
    return Container(
      width: resp.isTablet ? null : 152,
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
        Positioned(
          top: -22, right: -22,
          child: Container(
            width: 88, height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.08)),
          ),
        ),
        Positioned(
          bottom: -18, left: -18,
          child: Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.05)),
          ),
        ),
        Padding(
          padding: EdgeInsets.all(p),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: resp.isTablet ? 50 : 42,
                height: resp.isTablet ? 50 : 42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.22), width: 1),
                ),
                child: Icon(kpi.icon, color: Colors.white,
                  size: resp.isTablet ? 24 : 20),
              ),
              const Spacer(),
              Text(
                kpi.value,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: resp.isTablet ? 24 : 19,
                  fontWeight: FontWeight.w900,
                  color: Colors.white, letterSpacing: -0.6, height: 1.1),
                maxLines: 1, overflow: TextOverflow.ellipsis,
              ),
              if (kpi.subValue != null) ...[
                const SizedBox(height: 3),
                Row(children: [
                  Text(kpi.subValueLabel ?? '',
                    style: GoogleFonts.inter(
                      fontSize: resp.isTablet ? 11 : 8,
                      color: Colors.white.withValues(alpha: 0.5))),
                  const SizedBox(width: 4),
                  Text(kpi.subValue!,
                    style: GoogleFonts.inter(
                      fontSize: resp.isTablet ? 11 : 8,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.75))),
                ]),
              ],
              const SizedBox(height: 4),
              Row(children: [
                Expanded(
                  child: Text(
                    kpi.label,
                    style: GoogleFonts.inter(
                      fontSize: resp.isTablet ? 13 : 10.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.85),
                      letterSpacing: 0.1),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    kpi.sublabel,
                    style: GoogleFonts.inter(
                      fontSize: resp.isTablet ? 10 : 8,
                      fontWeight: FontWeight.w700,
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

    final resp = Responsive.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(resp.hPad, 14, resp.hPad, 0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: resp.isTablet ? const Color(0xFFCBD5E1) : AppColors.border,
            width: resp.isTablet ? 1.5 : 1.0),
          boxShadow: resp.isTablet ? [
            BoxShadow(color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 16, offset: const Offset(0, 4)),
            BoxShadow(color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4, offset: const Offset(0, 1)),
          ] : AppShadows.sm,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(context.l10n.weeklyRevenue,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: resp.isTablet ? 17 : 15, fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary, letterSpacing: -0.4)),
                  const SizedBox(height: 2),
                  Text('$currency ${NumberFormat('#,##0').format(total.round())} · this week',
                    style: GoogleFonts.inter(
                      fontSize: resp.isTablet ? 13 : 11, fontWeight: FontWeight.w500,
                      color: AppColors.textMuted)),
                ]),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20)),
                child: Text('7 DAYS',
                  style: GoogleFonts.inter(
                    fontSize: resp.isTablet ? 11 : 9, fontWeight: FontWeight.w900,
                    color: AppColors.primary, letterSpacing: 0.5)),
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
            Expanded(
              child: Text(label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15, fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary, letterSpacing: -0.4)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20)),
              child: Text(context.l10n.todayLabel,
                style: GoogleFonts.inter(
                  fontSize: 9, fontWeight: FontWeight.w900,
                  color: AppColors.success, letterSpacing: 0.5)),
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
                        Flexible(
                          child: Text(s.invoiceNo,
                            style: GoogleFonts.inter(
                              fontSize: 10, fontWeight: FontWeight.w500,
                              color: AppColors.textMuted),
                            maxLines: 1, overflow: TextOverflow.ellipsis)),
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
                SizedBox(
                  width: 90,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(fmtFn(s.totalAmount),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13, fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary, letterSpacing: -0.3))),
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
                  ])),
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
        label: context.l10n.newSaleBtn,
        subtitle: 'Start a transaction',
        color: const Color(0xFF0E7C3A),
        bg: const Color(0xFFDCFCE7),
        badge: null,
        onTap: () => onTabSwitch?.call(2),
      ),
      _ActionCard(
        icon: Icons.receipt_long_rounded,
        label: context.l10n.sales,
        subtitle: '${stats.todayTransactions} today',
        color: const Color(0xFF0369A1),
        bg: const Color(0xFFE0F2FE),
        badge: null,
        onTap: () => onTabSwitch?.call(1),
      ),
    ] : [
      _ActionCard(
        icon: Icons.receipt_long_rounded,
        label: context.l10n.sales,
        subtitle: '${stats.todayTransactions} today',
        color: const Color(0xFF0E7C3A),
        bg: const Color(0xFFDCFCE7),
        badge: null,
        onTap: () => onTabSwitch?.call(1),
      ),
      _ActionCard(
        icon: Icons.bar_chart_rounded,
        label: context.l10n.analytics,
        subtitle: '$currency ${_k(stats.monthRevenue)}',
        color: const Color(0xFF6D28D9),
        bg: const Color(0xFFEDE9FE),
        badge: null,
        onTap: () => onTabSwitch?.call(3),
      ),
      _ActionCard(
        icon: Icons.inventory_2_rounded,
        label: context.l10n.inventory,
        subtitle: 'Manage stock',
        color: const Color(0xFF0369A1),
        bg: AppColors.infoBg,
        badge: null,
        onTap: () => onTabSwitch?.call(2),
      ),
      _ActionCard(
        icon: Icons.warning_amber_rounded,
        label: context.l10n.lowStock,
        subtitle: '${stats.lowStockCount} item${stats.lowStockCount == 1 ? '' : 's'}',
        color: const Color(0xFFB45309),
        bg: AppColors.warningBg,
        badge: stats.lowStockCount > 0 ? stats.lowStockCount.toString() : null,
        onTap: () => onTabSwitch?.call(2),
      ),
    ];

    return LayoutBuilder(builder: (context, constraints) {
      final resp = Responsive.of(context);
      // On tablets show all actions in a single row; on phones keep 2×N grid
      final cols = resp.isTablet ? actions.length : 2;
      final rows = <List<_ActionCard>>[];
      for (var i = 0; i < actions.length; i += cols) {
        rows.add(actions.sublist(i, (i + cols).clamp(0, actions.length)));
      }

      return Padding(
        padding: EdgeInsets.fromLTRB(resp.hPad, 14, resp.hPad, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(context.l10n.quickActions,
                style: GoogleFonts.inter(
                  fontSize: 9, fontWeight: FontWeight.w900,
                  color: AppColors.primary, letterSpacing: 1.2)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(height: 1,
                color: AppColors.primary.withValues(alpha: 0.08))),
          ]),
          const SizedBox(height: 10),
          Column(children: [
            for (final row in rows) ...[
              Row(children: [
                for (var i = 0; i < row.length; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  Expanded(child: _QuickActionTile(action: row[i])),
                ],
              ]),
              if (row != rows.last) const SizedBox(height: 10),
            ],
          ]),
        ]),
      );
    });
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
      height: 116,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _darken(action.color, 0.15),
            action.color,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: action.color.withValues(alpha: 0.38),
            blurRadius: 20, offset: const Offset(0, 8), spreadRadius: -3),
          BoxShadow(
            color: action.color.withValues(alpha: 0.12),
            blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Stack(children: [
        // Decorative orb top-right
        Positioned(top: -24, right: -24,
          child: Container(
            width: 90, height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.08)))),
        // Decorative orb bottom-left
        Positioned(bottom: -18, left: -18,
          child: Container(
            width: 60, height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.05)))),
        // Content
        Padding(
          padding: const EdgeInsets.fromLTRB(15, 15, 15, 15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: icon + badge
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.22), width: 1)),
                  child: Icon(action.icon, color: Colors.white, size: 20)),
                const Spacer(),
                if (action.badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 6, offset: const Offset(0, 2))]),
                    child: Text(action.badge!,
                      style: GoogleFonts.inter(
                        fontSize: 10, fontWeight: FontWeight.w900,
                        color: action.color))),
              ]),
              const Spacer(),
              // Label
              Text(action.label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13.5, fontWeight: FontWeight.w900,
                  color: Colors.white, letterSpacing: -0.3, height: 1.1)),
              const SizedBox(height: 3),
              // Subtitle
              Text(action.subtitle,
                style: GoogleFonts.inter(
                  fontSize: 10.5, fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.65)),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ]),
    ),
  );

  Color _darken(Color c, double amount) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0)).toColor();
  }
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
  final AuthUser user;
  const _BranchCarousel({
    required this.branches, required this.currency,
    required this.activeBranchId, required this.user, this.onNewSale,
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

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Swipeable branch cards ──────────────────────────────────────
        SizedBox(
          height: 400,
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
              user: widget.user,
            ),
          ),
        ),

        // ── Branch name tab indicators ──────────────────────────────────
        if (widget.branches.length > 1) ...[
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: List.generate(widget.branches.length, (i) {
                final isActive = _page == i;
                final b = widget.branches[i];
                return GestureDetector(
                  onTap: () {
                    _timer?.cancel();
                    _ctrl.animateToPage(i,
                      duration: const Duration(milliseconds: 420),
                      curve: Curves.easeInOutCubic);
                    if (widget.branches.length > 1) _startTimer();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 280),
                    margin: const EdgeInsets.only(right: 8),
                    padding: EdgeInsets.symmetric(
                      horizontal: isActive ? 14 : 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppColors.primary
                          : const Color(0xFFEEF0F3),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: isActive ? [BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.28),
                        blurRadius: 10, offset: const Offset(0, 4))] : [],
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (isActive) ...[
                        Container(
                          width: 5, height: 5,
                          decoration: const BoxDecoration(
                            color: Color(0xFF4ADE80), shape: BoxShape.circle)),
                        const SizedBox(width: 5),
                      ],
                      Text(b.branchName,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                          color: isActive ? Colors.white : const Color(0xFF9CA3AF)),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    ]),
                  ),
                );
              }),
            ),
          ),
        ],

        // ── Branch leaderboard panel ─────────────────────────────────────
        if (widget.branches.length > 1) ...[
          const SizedBox(height: 20),
          Builder(builder: (ctx) {
            final resp = Responsive.of(ctx);
            return Padding(
            padding: EdgeInsets.fromLTRB(resp.hPad, 0, resp.hPad, 0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: resp.isTablet ? const Color(0xFFCBD5E1) : AppColors.border,
                  width: resp.isTablet ? 1.5 : 1.0),
                boxShadow: resp.isTablet ? [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.07),
                    blurRadius: 16, offset: const Offset(0, 4)),
                ] : AppShadows.sm,
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // ── Header ─────────────────────────────────────────────
                Container(
                  padding: EdgeInsets.fromLTRB(
                    resp.isTablet ? 20 : 16,
                    resp.isTablet ? 16 : 13,
                    resp.isTablet ? 20 : 16,
                    resp.isTablet ? 16 : 13),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0B1E10), Color(0xFF0F2D1A)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                  ),
                  child: Row(children: [
                    Container(
                      width: resp.isTablet ? 40 : 32,
                      height: resp.isTablet ? 40 : 32,
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10)),
                      child: Icon(Icons.leaderboard_rounded,
                        size: resp.isTablet ? 20 : 16, color: AppColors.accent),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Branch Leaderboard',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: resp.isTablet ? 16 : 13,
                            fontWeight: FontWeight.w800,
                            color: Colors.white, letterSpacing: -0.2)),
                        Text('Today\'s revenue · ${DateFormat('d MMM yyyy').format(DateTime.now())}',
                          style: GoogleFonts.inter(
                            fontSize: resp.isTablet ? 12 : 10,
                            color: Colors.white.withValues(alpha: 0.5))),
                      ]),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFF10B981).withValues(alpha: 0.3))),
                      child: Text('LIVE',
                        style: GoogleFonts.inter(
                          fontSize: resp.isTablet ? 11 : 9,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF4ADE80), letterSpacing: 0.5)),
                    ),
                  ]),
                ),

                // ── Branch rows ─────────────────────────────────────────
                Padding(
                  padding: EdgeInsets.all(resp.isTablet ? 16 : 12),
                  child: Column(children: [
                    ...ranked.asMap().entries.map((e) {
                      final rank = e.key;
                      final b = widget.branches.firstWhere((x) => x.branchId == e.value);
                      final isViewing = widget.branches[_page].branchId == b.branchId;
                      final pct = maxRev > 0 ? (b.todayRevenue / maxRev).clamp(0.0, 1.0) : 0.0;
                      final profitPositive = b.monthProfit >= 0;

                      const medalColors = [Color(0xFFF59E0B), Color(0xFF94A3B8), Color(0xFFCD7F32)];
                      final medalColor = rank < 3 ? medalColors[rank] : const Color(0xFFCBD5E1);
                      final medal = rank == 0 ? '🥇' : rank == 1 ? '🥈' : rank == 2 ? '🥉' : null;

                      final fmtShort = (double v) {
                        if (v >= 1000000) return '${(v/1000000).toStringAsFixed(1)}M';
                        if (v >= 1000)    return '${(v/1000).toStringAsFixed(0)}K';
                        return v.toInt().toString();
                      };

                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 280),
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: EdgeInsets.fromLTRB(
                          resp.isTablet ? 16 : 12,
                          resp.isTablet ? 14 : 11,
                          resp.isTablet ? 16 : 12,
                          resp.isTablet ? 14 : 11),
                        decoration: BoxDecoration(
                          gradient: isViewing
                              ? LinearGradient(
                                  colors: [
                                    AppColors.primary.withValues(alpha: 0.06),
                                    AppColors.primary.withValues(alpha: 0.02)],
                                  begin: Alignment.topLeft, end: Alignment.bottomRight)
                              : null,
                          color: isViewing ? null : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isViewing
                                ? AppColors.primary.withValues(alpha: 0.25)
                                : const Color(0xFFEEF0F3),
                            width: isViewing ? 1.5 : 1),
                          boxShadow: isViewing ? [BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            blurRadius: 12, offset: const Offset(0, 4))] : [],
                        ),
                        child: Row(children: [
                          // Medal / rank
                          SizedBox(
                            width: resp.isTablet ? 44 : 36,
                            child: medal != null
                                ? Text(medal,
                                    style: TextStyle(fontSize: resp.isTablet ? 26 : 20),
                                    textAlign: TextAlign.center)
                                : Container(
                                    width: resp.isTablet ? 34 : 28,
                                    height: resp.isTablet ? 34 : 28,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF3F4F6),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: const Color(0xFFE5E7EB))),
                                    child: Center(child: Text('${rank + 1}',
                                      style: GoogleFonts.inter(
                                        fontSize: resp.isTablet ? 13 : 10,
                                        fontWeight: FontWeight.w900,
                                        color: const Color(0xFF9CA3AF))))),
                          ),
                          SizedBox(width: resp.isTablet ? 14 : 10),
                          // Name + bar
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Row(children: [
                                Expanded(
                                  child: Text(b.branchName,
                                    maxLines: 1, overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                      fontSize: resp.isTablet ? 15 : 12,
                                      fontWeight: isViewing ? FontWeight.w900 : FontWeight.w600,
                                      color: isViewing
                                          ? AppColors.textPrimary
                                          : const Color(0xFF6B7280))),
                                ),
                                if (isViewing)
                                  Container(
                                    margin: const EdgeInsets.only(left: 8),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: AppColors.primary.withValues(alpha: 0.2))),
                                    child: Text('CURRENT',
                                      style: GoogleFonts.inter(
                                        fontSize: resp.isTablet ? 10 : 7.5,
                                        fontWeight: FontWeight.w900,
                                        color: AppColors.primary, letterSpacing: 0.5))),
                              ]),
                              SizedBox(height: resp.isTablet ? 8 : 6),
                              LayoutBuilder(builder: (ctx, cons) => Stack(children: [
                                Container(
                                  height: resp.isTablet ? 6 : 5,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEEF0F3),
                                    borderRadius: BorderRadius.circular(3))),
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 900),
                                  curve: Curves.easeOutExpo,
                                  height: resp.isTablet ? 6 : 5,
                                  width: cons.maxWidth * pct,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [medalColor.withValues(alpha: 0.7), medalColor]),
                                    borderRadius: BorderRadius.circular(3))),
                              ])),
                            ]),
                          ),
                          SizedBox(width: resp.isTablet ? 16 : 12),
                          // Revenue + stats
                          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                            Text('${widget.currency} ${fmtShort(b.todayRevenue)}',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: resp.isTablet ? 17 : 13,
                                fontWeight: FontWeight.w900,
                                color: AppColors.textPrimary, letterSpacing: -0.4)),
                            const SizedBox(height: 4),
                            Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(
                                profitPositive
                                    ? Icons.trending_up_rounded
                                    : Icons.trending_down_rounded,
                                size: resp.isTablet ? 14 : 12,
                                color: profitPositive
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFFEF4444)),
                              const SizedBox(width: 3),
                              Text(fmtShort(b.monthProfit.abs()),
                                style: GoogleFonts.inter(
                                  fontSize: resp.isTablet ? 12 : 10,
                                  fontWeight: FontWeight.w700,
                                  color: profitPositive
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFFEF4444))),
                              const SizedBox(width: 8),
                              Text('${b.todayTransactions} txns',
                                style: GoogleFonts.inter(
                                  fontSize: resp.isTablet ? 12 : 10,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF9CA3AF))),
                            ]),
                          ]),
                        ]),
                      );
                    }),

                    // Footer hint
                    Row(children: [
                      Icon(Icons.swipe_rounded,
                        size: resp.isTablet ? 13 : 11,
                        color: const Color(0xFFCBD5E1)),
                      const SizedBox(width: 5),
                      Text('Swipe cards above · Revenue = today · Profit = this month',
                        style: GoogleFonts.inter(
                          fontSize: resp.isTablet ? 11 : 9,
                          color: const Color(0xFFCBD5E1))),
                    ]),
                  ]),
                ),
              ]),
            ),
          );
          }),
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
  final AuthUser user;
  const _BranchCard({
    required this.branch, required this.currency,
    required this.isActive, required this.rank, required this.totalBranches,
    required this.user, this.onNewSale,
  });

  String _fmt(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000)    return '${(v / 1000).toStringAsFixed(0)}K';
    return NumberFormat('#,###').format(v.toInt());
  }

  void _navigateToProfit(BuildContext context) {
    Navigator.push(context,
      MaterialPageRoute(builder: (_) => ProductProfitScreen(user: user)));
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
            colors: [Color(0xFF03100A), Color(0xFF071C10), Color(0xFF0D2818)],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.5),
              blurRadius: 36, spreadRadius: -6, offset: const Offset(0, 14)),
          ],
        ),
        child: Stack(clipBehavior: Clip.hardEdge, children: [

          // ── Large rank watermark ──────────────────────────────────────
          if (totalBranches > 1)
            Positioned(right: -10, top: -8,
              child: Text('#$rank',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 110, fontWeight: FontWeight.w900,
                  color: Colors.white.withValues(alpha: 0.04),
                  letterSpacing: -6, height: 1),
              ),
            ),

          // ── Radial glow — top right ───────────────────────────────────
          Positioned(top: -80, right: -60,
            child: Container(
              width: 260, height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  const Color(0xFF2D6A4F).withValues(alpha: 0.22),
                  Colors.transparent,
                ]),
              ),
            ),
          ),

          // ── Accent glow — bottom left ─────────────────────────────────
          Positioned(bottom: -40, left: -30,
            child: Container(
              width: 160, height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  AppColors.accent.withValues(alpha: 0.1),
                  Colors.transparent,
                ]),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // ── Top row: branch name + badges ─────────────────────────
              Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                // Branch icon
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1))),
                  child: Icon(
                    Icons.storefront_rounded,
                    size: 17, color: Colors.white.withValues(alpha: 0.6)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(branch.branchName,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15, fontWeight: FontWeight.w900,
                        color: Colors.white, letterSpacing: -0.4, height: 1.1)),
                    if (isActive)
                      Text('Active branch',
                        style: GoogleFonts.inter(
                          fontSize: 9, fontWeight: FontWeight.w600,
                          color: const Color(0xFF4ADE80).withValues(alpha: 0.8))),
                  ]),
                ),
                // Rank medal
                if (totalBranches > 1) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: rank == 1
                          ? const Color(0xFFF59E0B).withValues(alpha: 0.18)
                          : Colors.white.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: rank == 1
                            ? const Color(0xFFF59E0B).withValues(alpha: 0.4)
                            : Colors.white.withValues(alpha: 0.1))),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(rank == 1 ? '🥇' : rank == 2 ? '🥈' : rank == 3 ? '🥉' : '',
                        style: const TextStyle(fontSize: 11)),
                      if (rank > 3) ...[
                        Text('#$rank',
                          style: GoogleFonts.inter(
                            fontSize: 10, fontWeight: FontWeight.w900,
                            color: Colors.white.withValues(alpha: 0.5))),
                      ] else
                        const SizedBox(width: 2),
                      Text(' of $totalBranches',
                        style: GoogleFonts.inter(
                          fontSize: 9, fontWeight: FontWeight.w600,
                          color: rank == 1
                              ? const Color(0xFFF59E0B).withValues(alpha: 0.8)
                              : Colors.white.withValues(alpha: 0.4))),
                    ]),
                  ),
                ],
              ]),

              const SizedBox(height: 20),

              // ── Revenue hero ──────────────────────────────────────────
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text("TODAY'S REVENUE",
                      style: GoogleFonts.inter(
                        fontSize: 9, fontWeight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: 0.3), letterSpacing: 1.3)),
                    const SizedBox(height: 6),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: CountUpText(
                        target: branch.todayRevenue,
                        prefix: '$currency ',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 36, fontWeight: FontWeight.w900,
                          color: Colors.white, letterSpacing: -1.5, height: 1.0),
                      ),
                    ),
                  ]),
                ),
                // Txns badge (top right of revenue)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1))),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
                    Text('${branch.todayTransactions}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18, fontWeight: FontWeight.w900,
                        color: Colors.white, height: 1.1)),
                    Text('txns',
                      style: GoogleFonts.inter(
                        fontSize: 8, fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.4))),
                  ]),
                ),
              ]),

              const SizedBox(height: 10),

              // ── Today profit chip ─────────────────────────────────────
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                  decoration: BoxDecoration(
                    color: profitColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: profitColor.withValues(alpha: 0.28))),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(profitIcon, size: 13, color: profitColor),
                    const SizedBox(width: 5),
                    Text('$currency ${_fmt(branch.todayProfit.abs())} profit',
                      style: GoogleFonts.inter(
                        fontSize: 11, fontWeight: FontWeight.w700, color: profitColor)),
                  ]),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(20)),
                  child: Text('$marginPct% margin',
                    style: GoogleFonts.inter(
                      fontSize: 10, fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.4))),
                ),
              ]),

              const SizedBox(height: 16),

              // ── 3-tile stat grid ──────────────────────────────────────
              IntrinsicHeight(
                child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  // Tile 1: Month Revenue
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08))),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('MONTH',
                          style: GoogleFonts.inter(
                            fontSize: 7.5, fontWeight: FontWeight.w900,
                            color: Colors.white.withValues(alpha: 0.3), letterSpacing: 0.8)),
                        const SizedBox(height: 5),
                        Text('$currency ${_fmt(branch.monthRevenue)}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13, fontWeight: FontWeight.w900,
                            color: Colors.white.withValues(alpha: 0.9),
                            letterSpacing: -0.4),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text('revenue',
                          style: GoogleFonts.inter(
                            fontSize: 8, fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.3))),
                      ]),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Tile 2: Month Profit — tappable, navigates to profit-by-product
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _navigateToProfit(context),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                        decoration: BoxDecoration(
                          color: branch.monthProfit >= 0
                              ? const Color(0xFF4ADE80).withValues(alpha: 0.08)
                              : const Color(0xFFFF6B6B).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: branch.monthProfit >= 0
                                ? const Color(0xFF4ADE80).withValues(alpha: 0.2)
                                : const Color(0xFFFF6B6B).withValues(alpha: 0.2))),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Text('PROFIT',
                              style: GoogleFonts.inter(
                                fontSize: 7.5, fontWeight: FontWeight.w900,
                                color: Colors.white.withValues(alpha: 0.3), letterSpacing: 0.8)),
                            const SizedBox(width: 3),
                            Icon(Icons.chevron_right_rounded, size: 11,
                              color: branch.monthProfit >= 0
                                  ? const Color(0xFF4ADE80).withValues(alpha: 0.5)
                                  : const Color(0xFFFF6B6B).withValues(alpha: 0.5)),
                          ]),
                          const SizedBox(height: 5),
                          Text('$currency ${_fmt(branch.monthProfit.abs())}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13, fontWeight: FontWeight.w900,
                              color: branch.monthProfit >= 0
                                  ? const Color(0xFF4ADE80)
                                  : const Color(0xFFFF6B6B),
                              letterSpacing: -0.4),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text('by product →',
                            style: GoogleFonts.inter(
                              fontSize: 8, fontWeight: FontWeight.w600,
                              color: branch.monthProfit >= 0
                                  ? const Color(0xFF4ADE80).withValues(alpha: 0.5)
                                  : const Color(0xFFFF6B6B).withValues(alpha: 0.5))),
                        ]),
                      ),
                    ),
                  ),
                ]),
              ),

              const SizedBox(height: 14),

              // ── New Sale button ───────────────────────────────────────
              GestureDetector(
                onTap: onNewSale,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF4A261), Color(0xFFD97706)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(
                      color: AppColors.accent.withValues(alpha: 0.45),
                      blurRadius: 18, offset: const Offset(0, 6))]),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.add_circle_rounded, color: Colors.white, size: 17),
                    const SizedBox(width: 9),
                    Text('New Sale',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15, fontWeight: FontWeight.w900,
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

// ── Stock Value Card ──────────────────────────────────────────────────────────
class _StockValueCard extends StatelessWidget {
  final StockValueSummary summary;
  final String currency;
  const _StockValueCard({required this.summary, required this.currency});

  String _fmt(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000)    return '${(v / 1000).toStringAsFixed(0)}K';
    return v.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    final profitPct = summary.marginPct;
    final resp = Responsive.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(resp.hPad, 14, resp.hPad, 0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: resp.isTablet ? const Color(0xFFCBD5E1) : AppColors.border,
            width: resp.isTablet ? 1.5 : 1.0),
          boxShadow: resp.isTablet ? [
            BoxShadow(color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 16, offset: const Offset(0, 4)),
            BoxShadow(color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4, offset: const Offset(0, 1)),
          ] : AppShadows.sm,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Header ──────────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0B1E10), Color(0xFF0F2D1A)],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            ),
            child: Row(children: [
              Container(
                width: resp.isTablet ? 40 : 34,
                height: resp.isTablet ? 40 : 34,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.inventory_2_rounded,
                  size: resp.isTablet ? 20 : 17, color: AppColors.accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Stock Value',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: resp.isTablet ? 16 : 14, fontWeight: FontWeight.w800,
                      color: Colors.white, letterSpacing: -0.2)),
                  Text('${summary.totalProducts} products · ${_fmt(summary.totalUnits)} units',
                    style: GoogleFonts.inter(
                      fontSize: resp.isTablet ? 12 : 10,
                      color: Colors.white.withValues(alpha: 0.5))),
                ]),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3))),
                child: Text('${profitPct.toStringAsFixed(1)}% margin',
                  style: GoogleFonts.inter(
                    fontSize: resp.isTablet ? 12 : 10, fontWeight: FontWeight.w800,
                    color: const Color(0xFF4ADE80))),
              ),
            ]),
          ),

          // ── 3 value tiles ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
            child: Row(children: [
              _StockValueTile(
                label: 'At Cost',
                value: '$currency ${_fmt(summary.totalCostValue)}',
                icon: Icons.shopping_bag_outlined,
                color: const Color(0xFF0284C7),
              ),
              const SizedBox(width: 10),
              _StockValueTile(
                label: 'At Selling',
                value: '$currency ${_fmt(summary.totalSellingValue)}',
                icon: Icons.sell_outlined,
                color: const Color(0xFF059669),
              ),
              const SizedBox(width: 10),
              _StockValueTile(
                label: 'Potential Profit',
                value: '$currency ${_fmt(summary.potentialProfit)}',
                icon: Icons.trending_up_rounded,
                color: AppColors.accent,
              ),
            ]),
          ),

          // ── Top products by capital ──────────────────────────────────────────
          if (summary.topProducts.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
              child: Row(children: [
                Container(width: 3, height: 12,
                  decoration: BoxDecoration(
                    color: AppColors.accent, borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 8),
                Text('Top by Capital',
                  style: GoogleFonts.inter(
                    fontSize: resp.isTablet ? 13 : 11, fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary, letterSpacing: 0.1)),
                const Spacer(),
                Text('cost value',
                  style: GoogleFonts.inter(
                    fontSize: resp.isTablet ? 11 : 9, color: AppColors.textMuted)),
              ]),
            ),
            ...summary.topProducts.take(5).map((p) {
              final pct = summary.totalCostValue > 0
                  ? p.valueAtCost / summary.totalCostValue
                  : 0.0;
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: Row(children: [
                  Expanded(
                    flex: 5,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(p.name,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: resp.isTablet ? 13 : 11, fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                      const SizedBox(height: 4),
                      LayoutBuilder(builder: (ctx, cons) => Stack(children: [
                        Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(2))),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 900),
                          curve: Curves.easeOutExpo,
                          height: 4,
                          width: cons.maxWidth * pct.clamp(0, 1),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF0F2D1A), Color(0xFF10B981)]),
                            borderRadius: BorderRadius.circular(2))),
                      ])),
                    ]),
                  ),
                  const SizedBox(width: 10),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('$currency ${_fmt(p.valueAtCost)}',
                      style: GoogleFonts.inter(
                        fontSize: resp.isTablet ? 13 : 11, fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary)),
                    Text('${p.qty.toInt()} units',
                      style: GoogleFonts.inter(
                        fontSize: resp.isTablet ? 11 : 9, color: AppColors.textMuted)),
                  ]),
                ]),
              );
            }),
          ],

          const SizedBox(height: 14),
        ]),
      ),
    );
  }
}

class _StockValueTile extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _StockValueTile({
    required this.label, required this.value,
    required this.icon, required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final resp = Responsive.of(context);
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: resp.isTablet ? 14 : 12,
          vertical: resp.isTablet ? 13 : 11),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: resp.isTablet
                ? color.withValues(alpha: 0.22)
                : color.withValues(alpha: 0.12),
            width: resp.isTablet ? 1.5 : 1.0),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: resp.isTablet ? 32 : 28,
            height: resp.isTablet ? 32 : 28,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: resp.isTablet ? 16 : 14, color: color),
          ),
          const SizedBox(height: 8),
          Text(value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: resp.isTablet ? 15 : 13, fontWeight: FontWeight.w900,
              color: AppColors.textPrimary, letterSpacing: -0.4),
            maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(label,
            style: GoogleFonts.inter(
              fontSize: resp.isTablet ? 11 : 9, fontWeight: FontWeight.w700,
              color: AppColors.textMuted)),
        ]),
      ),
    );
  }
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
