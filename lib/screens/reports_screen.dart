import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/animations.dart';
import '../utils/formatter.dart';
import '../utils/responsive.dart';
import '../widgets/common_widgets.dart';

class ReportsScreen extends StatefulWidget {
  final AuthUser user;
  const ReportsScreen({super.key, required this.user});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with SingleTickerProviderStateMixin {
  DashboardStats? _stats;
  List<SalesChartPoint> _chart = [];
  bool _loading = true;
  String? _error;
  late AnimationController _listCtrl;

  @override
  void initState() {
    super.initState();
    _listCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1200));
    _load();
  }

  @override
  void dispose() { _listCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        ApiService.getDashboard(),
        ApiService.getWeeklyChart(),
      ]);
      if (!mounted) return;
      setState(() {
        _stats = results[0] as DashboardStats;
        _chart = results[1] as List<SalesChartPoint>;
        _loading = false;
      });
      _listCtrl.forward(from: 0);
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(children: [
        // ── Premium header ──────────────────────────────────────────────────
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.navy, Color(0xFF1E2B5E)],
              begin: Alignment.topLeft, end: Alignment.bottomRight),
          ),
          child: Stack(children: [
            Positioned(top: -40, right: -30,
              child: PulsingOrb(size: 160,
                color: AppColors.gold.withValues(alpha: 0.12), duration: const Duration(seconds: 5))),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Reports',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 22, fontWeight: FontWeight.w900,
                          color: Colors.white, letterSpacing: -0.6)),
                      Text(DateFormat('MMMM yyyy').format(DateTime.now()),
                        style: GoogleFonts.inter(
                          fontSize: 12, fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.5))),
                    ]),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.auto_graph_rounded, color: AppColors.gold, size: 14),
                        const SizedBox(width: 6),
                        Text('Analytics',
                          style: GoogleFonts.inter(
                            fontSize: 11, fontWeight: FontWeight.w800,
                            color: AppColors.gold)),
                      ]),
                    ),
                  ],
                ),
              ),
            ),
          ]),
        ),

        // ── Body ────────────────────────────────────────────────────────────
        Expanded(
          child: _loading
              ? _buildShimmer()
              : _error != null
                  ? ErrorState(message: _error!, onRetry: _load)
                  : RefreshIndicator(
                      color: AppColors.navy,
                      onRefresh: _load,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                        child: _buildContent(),
                      ),
                    ),
        ),
      ]),
    );
  }

  Widget _buildContent() {
    final stats = _stats!;
    final cur = widget.user.currency;
    final profit = stats.monthRevenue - stats.monthExpenses;
    final fmt = NumberFormat('#,##0', 'en_US');
    final resp = Responsive.of(context);

    if (resp.isLargeTablet) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // PnL + Donut side-by-side
        StaggeredItem(index: 0, controller: _listCtrl,
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(flex: 6,
              child: _PnlCard(profit: profit, stats: stats, currency: cur, fmt: fmt)),
            const SizedBox(width: 20),
            Expanded(flex: 4,
              child: _PremiumDonut(revenue: stats.monthRevenue,
                expenses: stats.monthExpenses, currency: cur, fmt: fmt)),
          ])),
        const SizedBox(height: 20),
        StaggeredItem(index: 1, controller: _listCtrl,
          child: _KpiGrid(stats: stats, currency: cur, fmt: fmt)),
        if (_chart.isNotEmpty) ...[
          const SizedBox(height: 20),
          StaggeredItem(index: 2, controller: _listCtrl,
            child: _PremiumLineChart(points: _chart, currency: cur)),
        ],
      ]);
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

      // ── P&L Hero ────────────────────────────────────────────────────────
      StaggeredItem(
        index: 0, controller: _listCtrl,
        child: _PnlCard(profit: profit, stats: stats, currency: cur, fmt: fmt),
      ),

      const SizedBox(height: 16),

      // ── KPI grid ────────────────────────────────────────────────────────
      StaggeredItem(
        index: 1, controller: _listCtrl,
        child: _KpiGrid(stats: stats, currency: cur, fmt: fmt),
      ),

      const SizedBox(height: 20),

      // ── Weekly chart ─────────────────────────────────────────────────────
      if (_chart.isNotEmpty)
        StaggeredItem(
          index: 2, controller: _listCtrl,
          child: _PremiumLineChart(points: _chart, currency: cur),
        ),

      const SizedBox(height: 20),

      // ── Donut ────────────────────────────────────────────────────────────
      StaggeredItem(
        index: 3, controller: _listCtrl,
        child: _PremiumDonut(
          revenue: stats.monthRevenue,
          expenses: stats.monthExpenses,
          currency: cur, fmt: fmt),
      ),
    ]);
  }

  Widget _buildShimmer() => SingleChildScrollView(
    padding: const EdgeInsets.all(20),
    child: Column(children: [
      ShimmerBox(width: double.infinity, height: 160, radius: 20),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(child: ShimmerBox(width: double.infinity, height: 90, radius: 16)),
        const SizedBox(width: 12),
        Expanded(child: ShimmerBox(width: double.infinity, height: 90, radius: 16)),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: ShimmerBox(width: double.infinity, height: 90, radius: 16)),
        const SizedBox(width: 12),
        Expanded(child: ShimmerBox(width: double.infinity, height: 90, radius: 16)),
      ]),
      const SizedBox(height: 16),
      ShimmerBox(width: double.infinity, height: 180, radius: 20),
    ]),
  );
}

// ── P&L card ───────────────────────────────────────────────────────────────────
class _PnlCard extends StatelessWidget {
  final double profit;
  final DashboardStats stats;
  final String currency;
  final NumberFormat fmt;
  const _PnlCard({required this.profit, required this.stats,
    required this.currency, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final isGain = profit >= 0;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.navy, Color(0xFF1C2E5E)],
          begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(22),
        boxShadow: AppShadows.navy,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
            ),
            child: Text('This Month',
              style: GoogleFonts.inter(
                fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.gold)),
          ),
          const Spacer(),
          Icon(
            isGain ? Icons.trending_up_rounded : Icons.trending_down_rounded,
            color: isGain ? AppColors.accentLight : Colors.redAccent, size: 20),
        ]),

        const SizedBox(height: 16),

        Text('Net Profit',
          style: GoogleFonts.inter(
            fontSize: 11, fontWeight: FontWeight.w700,
            color: Colors.white54, letterSpacing: 0.6)),
        const SizedBox(height: 6),
        CountUpText(
          target: profit.abs(),
          prefix: '${isGain ? "" : "- "}$currency ',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: -1.2,
            color: isGain ? AppColors.accentLight : Colors.redAccent),
        ),

        const SizedBox(height: 20),

        Container(height: 1, color: Colors.white.withValues(alpha: 0.1)),
        const SizedBox(height: 16),

        Row(children: [
          Expanded(child: _PnlStat(
            'Revenue', stats.monthRevenue, currency, fmt, AppColors.accentLight)),
          Container(width: 1, height: 44, color: Colors.white12),
          Expanded(child: _PnlStat(
            'Expenses', stats.monthExpenses, currency, fmt,
            Colors.redAccent.shade100)),
        ]),
      ]),
    );
  }
}

class _PnlStat extends StatelessWidget {
  final String label, currency;
  final double value;
  final NumberFormat fmt;
  final Color color;
  const _PnlStat(this.label, this.value, this.currency, this.fmt, this.color);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
        style: GoogleFonts.inter(
          fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white54)),
      const SizedBox(height: 6),
      CountUpText(
        target: value,
        prefix: '$currency ',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 14, fontWeight: FontWeight.w800, color: color),
      ),
    ]),
  );
}

// ── KPI grid ───────────────────────────────────────────────────────────────────
class _KpiGrid extends StatelessWidget {
  final DashboardStats stats;
  final String currency;
  final NumberFormat fmt;
  const _KpiGrid({required this.stats, required this.currency, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final tiles = [
      _Kpi('Today Sales', Fmt.money(stats.todaySales, currency: currency),
        '${stats.todayTransactions} trans.',
        Icons.today_rounded, AppColors.primary, AppColors.successBg),
      _Kpi('Pending POs', '${stats.pendingOrders}', 'orders',
        Icons.pending_actions_rounded, AppColors.warning, AppColors.warningBg),
      _Kpi('Credits Due', Fmt.money(stats.outstandingCredits, currency: currency),
        'outstanding', Icons.credit_card_rounded, AppColors.info, AppColors.infoBg),
      _Kpi('Low Stock', '${stats.lowStockCount}', 'products',
        Icons.inventory_2_rounded, AppColors.danger, AppColors.dangerBg),
    ];

    final resp = Responsive.of(context);
    if (resp.isLargeTablet) {
      return Row(children: [
        for (int i = 0; i < tiles.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          Expanded(child: _KpiTile(t: tiles[i])),
        ],
      ]);
    }

    return Column(children: [
      Row(children: [
        Expanded(child: _KpiTile(t: tiles[0])),
        const SizedBox(width: 12),
        Expanded(child: _KpiTile(t: tiles[1])),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: _KpiTile(t: tiles[2])),
        const SizedBox(width: 12),
        Expanded(child: _KpiTile(t: tiles[3])),
      ]),
    ]);
  }
}

class _Kpi {
  final String label, value, sub;
  final IconData icon;
  final Color color, bg;
  const _Kpi(this.label, this.value, this.sub, this.icon, this.color, this.bg);
}

class _KpiTile extends StatelessWidget {
  final _Kpi t;
  const _KpiTile({super.key, required this.t});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
      boxShadow: AppShadows.sm,
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Container(
        width: 34, height: 34,
        decoration: BoxDecoration(
          color: t.bg, borderRadius: BorderRadius.circular(10)),
        child: Icon(t.icon, color: t.color, size: 16),
      ),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(t.value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16, fontWeight: FontWeight.w900,
            color: t.color, letterSpacing: -0.4),
          maxLines: 1, overflow: TextOverflow.ellipsis),
        Text(t.label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11, fontWeight: FontWeight.w700,
            color: AppColors.textPrimary)),
        Text(t.sub,
          style: GoogleFonts.inter(
            fontSize: 10, fontWeight: FontWeight.w500,
            color: AppColors.textMuted)),
      ]),
    ]),
  );
}

// ── Premium line chart ─────────────────────────────────────────────────────────
class _PremiumLineChart extends StatelessWidget {
  final List<SalesChartPoint> points;
  final String currency;
  const _PremiumLineChart({required this.points, required this.currency});

  @override
  Widget build(BuildContext context) {
    final maxVal = points.map((p) => p.value).fold(0.0, (a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.md,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('Daily Revenue', style: AppTextStyles.headingSmall),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.primaryLight.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20)),
            child: Text('This Week',
              style: GoogleFonts.inter(
                fontSize: 10, fontWeight: FontWeight.w700,
                color: AppColors.primaryLight)),
          ),
        ]),
        const SizedBox(height: 20),
        SizedBox(
          height: 150,
          child: LineChart(
            LineChartData(
              maxY: maxVal * 1.3, minY: 0,
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (spots) => spots.map((s) => LineTooltipItem(
                    '$currency ${NumberFormat('#,##0').format(s.y.round())}',
                    GoogleFonts.inter(
                      fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                  )).toList(),
                ),
              ),
              gridData: FlGridData(
                drawVerticalLine: false,
                horizontalInterval: maxVal > 0 ? maxVal * 0.4 : 1,
                getDrawingHorizontalLine: (_) => const FlLine(
                  color: AppColors.borderLight, strokeWidth: 1),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true, reservedSize: 24,
                    getTitlesWidget: (v, _) {
                      final i = v.toInt();
                      if (i < 0 || i >= points.length) return const SizedBox();
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(points[i].label,
                          style: GoogleFonts.inter(
                            fontSize: 10, fontWeight: FontWeight.w700,
                            color: AppColors.textMuted)),
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true, reservedSize: 40,
                    getTitlesWidget: (v, _) => Text(Fmt.shortMoney(v),
                      style: GoogleFonts.inter(
                        fontSize: 9, fontWeight: FontWeight.w600,
                        color: AppColors.textMuted)),
                  ),
                ),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: List.generate(points.length, (i) =>
                    FlSpot(i.toDouble(), points[i].value)),
                  isCurved: true, curveSmoothness: 0.3,
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryLight]),
                  barWidth: 3,
                  shadow: Shadow(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    blurRadius: 8, offset: const Offset(0, 4)),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: [
                        AppColors.primary.withValues(alpha: 0.18),
                        AppColors.primary.withValues(alpha: 0.0)]),
                  ),
                  dotData: FlDotData(
                    getDotPainter: (_, __, ___, i) => FlDotCirclePainter(
                      radius: 4, color: AppColors.primary,
                      strokeWidth: 2.5, strokeColor: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}

// ── Premium donut ──────────────────────────────────────────────────────────────
class _PremiumDonut extends StatelessWidget {
  final double revenue, expenses;
  final String currency;
  final NumberFormat fmt;
  const _PremiumDonut({required this.revenue, required this.expenses,
    required this.currency, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final total = revenue + expenses;
    if (total == 0) {
      return const EmptyState(
        title: 'No data yet',
        subtitle: 'Revenue and expenses will appear here',
        icon: Icons.pie_chart_outline_rounded);
    }

    final revPct = (revenue / total * 100).toStringAsFixed(0);
    final expPct = (expenses / total * 100).toStringAsFixed(0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.md,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Revenue vs Expenses', style: AppTextStyles.headingSmall),
        const SizedBox(height: 20),
        Row(children: [
          SizedBox(
            width: 130, height: 130,
            child: PieChart(PieChartData(
              sectionsSpace: 3,
              centerSpaceRadius: 38,
              startDegreeOffset: -90,
              sections: [
                PieChartSectionData(
                  value: revenue, color: AppColors.primary,
                  title: '$revPct%',
                  titleStyle: GoogleFonts.plusJakartaSans(
                    fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white),
                  radius: 32),
                PieChartSectionData(
                  value: expenses, color: AppColors.danger,
                  title: '$expPct%',
                  titleStyle: GoogleFonts.plusJakartaSans(
                    fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white),
                  radius: 32),
              ],
            )),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _DonutLegend('Revenue', revenue, AppColors.primary, currency, fmt),
              const SizedBox(height: 12),
              _DonutLegend('Expenses', expenses, AppColors.danger, currency, fmt),
              const SizedBox(height: 14),
              Container(height: 1, color: AppColors.border),
              const SizedBox(height: 14),
              Row(children: [
                Container(
                  width: 10, height: 10,
                  decoration: BoxDecoration(
                    color: revenue >= expenses ? AppColors.success : AppColors.danger,
                    borderRadius: BorderRadius.circular(3))),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(revenue >= expenses ? 'Profit' : 'Loss',
                      style: GoogleFonts.inter(
                        fontSize: 10, fontWeight: FontWeight.w700,
                        color: AppColors.textMuted)),
                    Text('$currency ${fmt.format((revenue - expenses).abs().round())}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14, fontWeight: FontWeight.w900,
                        color: revenue >= expenses ? AppColors.success : AppColors.danger,
                        letterSpacing: -0.3)),
                  ]),
                ),
              ]),
            ]),
          ),
        ]),
      ]),
    );
  }
}

class _DonutLegend extends StatelessWidget {
  final String label, currency;
  final double value;
  final Color color;
  final NumberFormat fmt;
  const _DonutLegend(this.label, this.value, this.color, this.currency, this.fmt);

  @override
  Widget build(BuildContext context) => Row(children: [
    Container(
      width: 12, height: 12,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
    const SizedBox(width: 10),
    Expanded(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
          style: GoogleFonts.inter(
            fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
        Text('$currency ${fmt.format(value.round())}',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
      ]),
    ),
  ]);
}
