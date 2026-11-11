import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatter.dart' show Fmt;
import '../utils/l10n_ext.dart';

enum _SortBy { profit, revenue, margin, qty }

class ProductProfitScreen extends StatefulWidget {
  final AuthUser user;
  const ProductProfitScreen({super.key, required this.user});
  @override
  State<ProductProfitScreen> createState() => _ProductProfitScreenState();
}

class _ProductProfitScreenState extends State<ProductProfitScreen>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _summary = {};
  List<Map<String, dynamic>> _products = [];
  late DateTime _from;
  late DateTime _to;
  _SortBy _sortBy = _SortBy.profit;
  late AnimationController _fadeCtrl;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 500));
    _from = DateTime(DateTime.now().year, DateTime.now().month, 1);
    _to   = DateTime.now();
    _load();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    _fadeCtrl.reset();
    try {
      final res = await ApiService.getProductProfit(
        from: DateFormat('yyyy-MM-dd').format(_from),
        to:   DateFormat('yyyy-MM-dd').format(_to),
        limit: 30,
      );
      if (!mounted) return;
      if (res['ok'] == true) {
        setState(() {
          _summary  = Map<String, dynamic>.from(res['summary'] ?? {});
          _products = List<Map<String, dynamic>>.from(res['products'] ?? []);
          _loading  = false;
        });
        _fadeCtrl.forward();
      } else {
        setState(() { _error = res['error']?.toString() ?? 'Failed to load.'; _loading = false; });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _from, end: _to),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.light(primary: AppColors.primary)),
        child: child!),
    );
    if (picked != null) {
      setState(() { _from = picked.start; _to = picked.end; });
      _load();
    }
  }

  List<Map<String, dynamic>> get _sorted {
    final list = List<Map<String, dynamic>>.from(_products);
    list.sort((a, b) {
      switch (_sortBy) {
        case _SortBy.profit:
          return (b['gross_profit'] as num).compareTo(a['gross_profit'] as num);
        case _SortBy.revenue:
          return (b['revenue'] as num).compareTo(a['revenue'] as num);
        case _SortBy.margin:
          return (b['margin_pct'] as num).compareTo(a['margin_pct'] as num);
        case _SortBy.qty:
          return (b['qty_sold'] as num).compareTo(a['qty_sold'] as num);
      }
    });
    return list;
  }

  String get _cur => widget.user.currency;

  String _fmtPeriod() {
    final same = _from.year == _to.year && _from.month == _to.month;
    if (same) return DateFormat('MMM yyyy').format(_from);
    return '${DateFormat('d MMM').format(_from)} – ${DateFormat('d MMM yyyy').format(_to)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F4F1),
      body: CustomScrollView(
        slivers: [
          // ── App bar ─────────────────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            expandedHeight: 0,
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            title: Text(context.l10n.profitByProductTitle,
              style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 17)),
            actions: [
              GestureDetector(
                onTap: _pickDateRange,
                child: Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.calendar_month_outlined, size: 13, color: Colors.white),
                    const SizedBox(width: 5),
                    Text(_fmtPeriod(),
                      style: GoogleFonts.inter(
                        fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
                  ]),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, size: 20),
                onPressed: _loading ? null : _load,
                tooltip: 'Refresh'),
            ],
          ),

          if (_loading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()))
          else if (_error != null)
            SliverFillRemaining(
              child: _ErrorView(error: _error!, onRetry: _load))
          else if (_products.isEmpty)
            SliverFillRemaining(
              child: _EmptyView(onPick: _pickDateRange))
          else
            _DataBody(
              summary: _summary,
              sorted: _sorted,
              all: _products,
              currency: _cur,
              sortBy: _sortBy,
              fadeCtrl: _fadeCtrl,
              onSort: (s) => setState(() => _sortBy = s),
            ),
        ],
      ),
    );
  }
}

// ── Main data body ─────────────────────────────────────────────────────────────
class _DataBody extends StatelessWidget {
  final Map<String, dynamic> summary;
  final List<Map<String, dynamic>> sorted, all;
  final String currency;
  final _SortBy sortBy;
  final AnimationController fadeCtrl;
  final ValueChanged<_SortBy> onSort;

  const _DataBody({
    required this.summary, required this.sorted, required this.all,
    required this.currency, required this.sortBy,
    required this.fadeCtrl, required this.onSort,
  });

  @override
  Widget build(BuildContext context) {
    final maxProfit = sorted.fold<double>(0, (m, p) {
      final v = (p['gross_profit'] as num).toDouble();
      return v > m ? v : m;
    });

    return SliverList(
      delegate: SliverChildListDelegate([
        FadeTransition(
          opacity: fadeCtrl,
          child: Column(children: [
            // ── Summary hero ──────────────────────────────────────────────
            _SummaryHero(summary: summary, currency: currency),

            // ── Top 5 bar chart ───────────────────────────────────────────
            _TopBarsSection(products: all.take(5).toList(), currency: currency),

            // ── Sort chips ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Row(children: [
                Text(context.l10n.allProducts,
                  style: GoogleFonts.inter(
                    fontSize: 15, fontWeight: FontWeight.w800,
                    color: const Color(0xFF111827))),
                const Spacer(),
                ...{
                  _SortBy.profit:  'Profit',
                  _SortBy.revenue: 'Revenue',
                  _SortBy.margin:  'Margin',
                  _SortBy.qty:     'Qty',
                }.entries.map((e) => _SortChip(
                  label: e.value,
                  active: sortBy == e.key,
                  onTap: () => onSort(e.key))),
              ]),
            ),

            // ── Product rows ──────────────────────────────────────────────
            ...sorted.asMap().entries.map((e) => _ProductRow(
              index: e.key,
              product: e.value,
              currency: currency,
              maxProfit: maxProfit,
            )),

            const SizedBox(height: 32),
          ]),
        ),
      ]),
    );
  }
}

// ── Summary hero ──────────────────────────────────────────────────────────────
class _SummaryHero extends StatelessWidget {
  final Map<String, dynamic> summary;
  final String currency;
  const _SummaryHero({required this.summary, required this.currency});

  @override
  Widget build(BuildContext context) {
    final revenue = (summary['revenue']    as num?)?.toDouble() ?? 0;
    final cost    = (summary['cost']       as num?)?.toDouble() ?? 0;
    final profit  = (summary['profit']     as num?)?.toDouble() ?? 0;
    final margin  = (summary['avg_margin'] as num?)?.toDouble() ?? 0;
    final qty     = (summary['qty_sold']   as num?)?.toInt()    ?? 0;
    final isGain  = profit >= 0;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F2D1A), Color(0xFF1B4332), Color(0xFF2D6A4F)],
          begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(
          color: const Color(0xFF0F2D1A).withValues(alpha: 0.35),
          blurRadius: 20, offset: const Offset(0, 8))]),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Top: profit + margin pill
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(context.l10n.netProfitLabel,
                  style: GoogleFonts.inter(
                    fontSize: 10, fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.4), letterSpacing: 1.1)),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    Fmt.money(profit.abs(), currency: currency),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 28, fontWeight: FontWeight.w900,
                      color: Colors.white, letterSpacing: -0.8, height: 1.0)),
                ),
              ]),
            ),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: (isGain
                    ? const Color(0xFF4ADE80)
                    : const Color(0xFFFF6B6B)).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: (isGain
                      ? const Color(0xFF4ADE80)
                      : const Color(0xFFFF6B6B)).withValues(alpha: 0.3))),
                child: Text(
                  '${isGain ? "▲" : "▼"} ${margin.toStringAsFixed(1)}% margin',
                  style: GoogleFonts.inter(
                    fontSize: 11, fontWeight: FontWeight.w700,
                    color: isGain ? const Color(0xFF4ADE80) : const Color(0xFFFF6B6B)))),
              const SizedBox(height: 6),
              Text('$qty ${context.l10n.unitsSold}',
                style: GoogleFonts.inter(
                  fontSize: 10, color: Colors.white.withValues(alpha: 0.35))),
            ]),
          ]),

          const SizedBox(height: 16),
          Container(height: 1, color: Colors.white.withValues(alpha: 0.08)),
          const SizedBox(height: 14),

          // Revenue / Cost / Profit KPI row
          Row(children: [
            _HeroKpi(context.l10n.revenue, Fmt.money(revenue, currency: currency), const Color(0xFF93C5FD)),
            _HeroKpiDiv(),
            _HeroKpi(context.l10n.costOfGoods, Fmt.money(cost, currency: currency), const Color(0xFFFCA5A5)),
            _HeroKpiDiv(),
            _HeroKpi(context.l10n.grossProfit, Fmt.money(profit, currency: currency),
              isGain ? const Color(0xFF4ADE80) : const Color(0xFFFF6B6B)),
          ]),
        ]),
      ),
    );
  }
}

class _HeroKpi extends StatelessWidget {
  final String label, value;
  final Color color;
  const _HeroKpi(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: GoogleFonts.inter(
        fontSize: 9, fontWeight: FontWeight.w600,
        color: Colors.white.withValues(alpha: 0.35), letterSpacing: 0.5)),
      const SizedBox(height: 4),
      FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(value, style: GoogleFonts.inter(
          fontSize: 13, fontWeight: FontWeight.w700, color: color))),
    ]),
  );
}

class _HeroKpiDiv extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: 1, height: 36,
    margin: const EdgeInsets.symmetric(horizontal: 12),
    color: Colors.white.withValues(alpha: 0.08));
}

// ── Top 5 horizontal bar chart ────────────────────────────────────────────────
class _TopBarsSection extends StatelessWidget {
  final List<Map<String, dynamic>> products;
  final String currency;
  const _TopBarsSection({required this.products, required this.currency});

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) return const SizedBox.shrink();

    final maxProfit = products.fold<double>(0, (m, p) {
      final v = (p['gross_profit'] as num).toDouble();
      return v > m ? v : m;
    });

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 10, offset: const Offset(0, 3))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(context.l10n.topPerformers,
            style: GoogleFonts.inter(
              fontSize: 13, fontWeight: FontWeight.w800,
              color: const Color(0xFF111827))),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(20)),
            child: Text('by profit',
              style: GoogleFonts.inter(
                fontSize: 9, fontWeight: FontWeight.w700,
                color: const Color(0xFF2D6A4F)))),
        ]),
        const SizedBox(height: 14),
        ...products.asMap().entries.map((e) {
          final p = e.value;
          final profit = (p['gross_profit'] as num).toDouble();
          final pct = maxProfit > 0 ? (profit / maxProfit).clamp(0.0, 1.0) : 0.0;
          final name = p['product_name']?.toString() ?? '';
          final margin = (p['margin_pct'] as num).toDouble();
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 18, height: 18,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F2D1A),
                    borderRadius: BorderRadius.circular(5)),
                  child: Text('${e.key + 1}',
                    style: GoogleFonts.inter(
                      fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white))),
                const SizedBox(width: 8),
                Expanded(child: Text(name,
                  style: GoogleFonts.inter(
                    fontSize: 12, fontWeight: FontWeight.w600,
                    color: const Color(0xFF374151)),
                  maxLines: 1, overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 8),
                Text(Fmt.money(profit, currency: currency),
                  style: GoogleFonts.inter(
                    fontSize: 12, fontWeight: FontWeight.w800,
                    color: const Color(0xFF059669))),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(10)),
                  child: Text('${margin.toStringAsFixed(0)}%',
                    style: GoogleFonts.inter(
                      fontSize: 9, fontWeight: FontWeight.w700,
                      color: const Color(0xFF2D6A4F)))),
              ]),
              const SizedBox(height: 5),
              Stack(children: [
                Container(height: 6, decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(3))),
                FractionallySizedBox(
                  widthFactor: pct,
                  child: Container(height: 6, decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0F2D1A), Color(0xFF52B788)]),
                    borderRadius: BorderRadius.circular(3)))),
              ]),
            ]),
          );
        }),
      ]),
    );
  }
}

// ── Sort chip ─────────────────────────────────────────────────────────────────
class _SortChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _SortChip({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.only(left: 5),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: active ? const Color(0xFF0F2D1A) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: active ? const Color(0xFF0F2D1A) : const Color(0xFFE5E7EB))),
      child: Text(label,
        style: GoogleFonts.inter(
          fontSize: 11, fontWeight: FontWeight.w700,
          color: active ? Colors.white : const Color(0xFF6B7280))),
    ),
  );
}

// ── Product row ───────────────────────────────────────────────────────────────
class _ProductRow extends StatelessWidget {
  final int index;
  final Map<String, dynamic> product;
  final String currency;
  final double maxProfit;
  const _ProductRow({
    required this.index, required this.product,
    required this.currency, required this.maxProfit,
  });

  @override
  Widget build(BuildContext context) {
    final profit  = (product['gross_profit'] as num).toDouble();
    final revenue = (product['revenue']      as num).toDouble();
    final cost    = (product['cost']         as num).toDouble();
    final margin  = (product['margin_pct']   as num).toDouble();
    final qty     = (product['qty_sold']     as num).toInt();
    final isGain  = profit >= 0;
    final pct     = maxProfit > 0 ? (profit.abs() / maxProfit).clamp(0.0, 1.0) : 0.0;

    final mColor = margin >= 30 ? const Color(0xFF059669)
                 : margin >= 15 ? const Color(0xFF0284C7)
                 : margin >= 5  ? const Color(0xFFD97706)
                 :                const Color(0xFFDC2626);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.03),
          blurRadius: 8, offset: const Offset(0, 2))]),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // Name row
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Container(
              width: 30, height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: index < 3
                  ? [const Color(0xFFFEF3C7),
                     const Color(0xFFF3F4F6),
                     const Color(0xFFFEF9C3)][index]
                  : const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(9)),
              child: index < 3
                ? Text(['🥇','🥈','🥉'][index], style: const TextStyle(fontSize: 14))
                : Text('${index + 1}',
                    style: GoogleFonts.inter(
                      fontSize: 11, fontWeight: FontWeight.w900,
                      color: const Color(0xFF2D6A4F)))),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(product['product_name']?.toString() ?? '',
                  style: GoogleFonts.inter(
                    fontSize: 13, fontWeight: FontWeight.w700,
                    color: const Color(0xFF111827)),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
                if ((product['category'] ?? '').toString().isNotEmpty)
                  Text(product['category'].toString(),
                    style: GoogleFonts.inter(
                      fontSize: 10, color: const Color(0xFF9CA3AF))),
              ]),
            ),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(
                '${isGain ? "+" : "–"} ${Fmt.money(profit.abs(), currency: currency)}',
                style: GoogleFonts.inter(
                  fontSize: 14, fontWeight: FontWeight.w800,
                  color: isGain ? const Color(0xFF059669) : const Color(0xFFDC2626))),
              const SizedBox(height: 3),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: mColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: mColor.withValues(alpha: 0.2))),
                child: Text('${margin.toStringAsFixed(1)}% margin',
                  style: GoogleFonts.inter(
                    fontSize: 9, fontWeight: FontWeight.w700, color: mColor))),
            ]),
          ]),

          // Progress bar
          const SizedBox(height: 10),
          Stack(children: [
            Container(height: 4, decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(2))),
            FractionallySizedBox(
              widthFactor: pct,
              child: Container(height: 4, decoration: BoxDecoration(
                gradient: LinearGradient(colors: isGain
                  ? [const Color(0xFF0F2D1A), const Color(0xFF52B788)]
                  : [const Color(0xFFDC2626), const Color(0xFFFCA5A5)]),
                borderRadius: BorderRadius.circular(2)))),
          ]),

          // Stats row
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFF3F4F6))),
            child: Row(children: [
              _Stat(context.l10n.revenue, Fmt.money(revenue, currency: currency), const Color(0xFF2563EB)),
              _StatDiv(),
              _Stat(context.l10n.costOfGoods, Fmt.money(cost, currency: currency), const Color(0xFFDC2626)),
              _StatDiv(),
              _Stat(context.l10n.qty, '$qty ${context.l10n.unitsSold}', const Color(0xFF6B7280)),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _Stat(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: GoogleFonts.inter(
        fontSize: 9, fontWeight: FontWeight.w600,
        color: const Color(0xFF9CA3AF), letterSpacing: 0.3)),
      const SizedBox(height: 2),
      Text(value, style: GoogleFonts.inter(
        fontSize: 11, fontWeight: FontWeight.w700, color: color),
        maxLines: 1, overflow: TextOverflow.ellipsis),
    ]),
  );
}

class _StatDiv extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: 1, height: 28,
    margin: const EdgeInsets.symmetric(horizontal: 10),
    color: const Color(0xFFE5E7EB));
}

// ── Empty ─────────────────────────────────────────────────────────────────────
class _EmptyView extends StatelessWidget {
  final VoidCallback onPick;
  const _EmptyView({required this.onPick});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4), shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFF2D6A4F).withValues(alpha: 0.2))),
          child: const Icon(Icons.bar_chart_rounded,
            size: 32, color: Color(0xFF2D6A4F))),
        const SizedBox(height: 16),
        Text(context.l10n.noSalesData,
          style: GoogleFonts.inter(
            fontSize: 16, fontWeight: FontWeight.w700,
            color: const Color(0xFF111827))),
        const SizedBox(height: 6),
        Text(context.l10n.tryDifferentPeriod,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 13, color: const Color(0xFF9CA3AF), height: 1.5)),
        const SizedBox(height: 20),
        TextButton.icon(
          onPressed: onPick,
          icon: const Icon(Icons.calendar_month_outlined, size: 16),
          label: Text(context.l10n.changePeriod),
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF0F2D1A),
            textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700))),
      ]),
    ),
  );
}

// ── Error ─────────────────────────────────────────────────────────────────────
class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(
            color: const Color(0xFFFFF1F2), shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFFCA5A5))),
          child: const Icon(Icons.wifi_off_rounded,
            size: 28, color: Color(0xFFDC2626))),
        const SizedBox(height: 16),
        Text(context.l10n.couldntLoadData,
          style: GoogleFonts.inter(
            fontSize: 16, fontWeight: FontWeight.w700,
            color: const Color(0xFF111827))),
        const SizedBox(height: 6),
        Text(error, textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 12, color: const Color(0xFF9CA3AF), height: 1.5)),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text(context.l10n.retry,
              style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F2D1A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)))),
        ),
      ]),
    ),
  );
}
