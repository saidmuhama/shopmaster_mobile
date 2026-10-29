import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatter.dart';
import '../utils/animations.dart';
import '../utils/responsive.dart';
import '../widgets/common_widgets.dart';

class SalesScreen extends StatefulWidget {
  final String filter;
  final ValueNotifier<int>? tabNotifier;
  const SalesScreen({super.key, this.filter = 'today', this.tabNotifier});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen>
    with SingleTickerProviderStateMixin {
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  late String _filter;
  List<Sale> _sales = [];
  bool _loading = true;
  bool _showSearch = false;
  String? _error;

  final _filters = const [
    ('today',  'Today'),
    ('week',   'This Week'),
    ('month',  'This Month'),
    ('all',    'All Time'),
  ];

  @override
  void initState() {
    super.initState();
    _filter = widget.filter;
    widget.tabNotifier?.addListener(_onTabVisible);
    _load();
  }

  void _onTabVisible() {
    if (widget.tabNotifier?.value == 1) _load();
  }

  @override
  void dispose() {
    widget.tabNotifier?.removeListener(_onTabVisible);
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _load({String? search}) async {
    setState(() { _loading = true; _error = null; });
    try {
      final sales = await ApiService.getSales(filter: _filter, search: search);
      if (!mounted) return;
      setState(() { _sales = sales; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = 'Failed to load sales. Pull to refresh.'; });
    }
  }

  double get _totalAmount =>
      _sales.fold(0.0, (s, sale) => s + sale.totalAmount);

  int get _paidCount => _sales.where((s) => s.isPaid).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(children: [
        _buildHeader(),
        Expanded(
          child: _loading
              ? _buildShimmer()
              : _error != null
                  ? _buildError()
                  : _sales.isEmpty
                      ? _buildEmpty()
                      : Builder(builder: (ctx) {
                        final resp = Responsive.of(ctx);
                        return RefreshIndicator(
                          onRefresh: _load,
                          color: AppColors.primary,
                          child: resp.isLargeTablet
                              ? GridView.builder(
                                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                    childAspectRatio: 3.2,
                                  ),
                                  itemCount: _sales.length,
                                  itemBuilder: (_, i) => _SaleCard(sale: _sales[i]),
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                                  itemCount: _sales.length,
                                  itemBuilder: (_, i) => _SaleCard(sale: _sales[i]),
                                ),
                        );
                      }),
        ),
      ]),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF061410), Color(0xFF0F2D1A), Color(0xFF163522)],
          begin: Alignment.topLeft, end: Alignment.bottomRight)),
      child: Column(children: [
        // Top bar
        Padding(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 14,
            left: 20, right: 20, bottom: 0),
          child: Row(children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: AppColors.accent.withValues(alpha: 0.25))),
              child: const Icon(Icons.receipt_long_rounded,
                color: AppColors.accent, size: 20)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Sales History',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18, fontWeight: FontWeight.w900,
                    color: Colors.white, letterSpacing: -0.4)),
                if (!_loading)
                  Text('${_sales.length} records  ·  ${_paidCount} paid',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.45),
                      fontWeight: FontWeight.w500)),
              ]),
            ),
            GestureDetector(
              onTap: () {
                setState(() {
                  _showSearch = !_showSearch;
                  if (!_showSearch) { _searchCtrl.clear(); _load(); }
                });
                if (_showSearch) {
                  Future.delayed(const Duration(milliseconds: 100),
                    () => _searchFocus.requestFocus());
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: _showSearch
                      ? AppColors.accent.withValues(alpha: 0.2)
                      : Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(
                    color: _showSearch
                        ? AppColors.accent.withValues(alpha: 0.4)
                        : Colors.white.withValues(alpha: 0.14))),
                child: Icon(_showSearch ? Icons.close_rounded : Icons.search_rounded,
                  color: _showSearch ? AppColors.accent : Colors.white54, size: 18)),
            ),
          ]),
        ),

        // Summary strip
        if (!_loading && _sales.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: Row(children: [
              _SummaryPill(
                label: 'Total Sales',
                value: _fmtMoney(_totalAmount),
                icon: Icons.trending_up_rounded,
                color: const Color(0xFF4ADE80)),
              const SizedBox(width: 8),
              _SummaryPill(
                label: 'Paid',
                value: '$_paidCount / ${_sales.length}',
                icon: Icons.check_circle_rounded,
                color: AppColors.accent),
            ]),
          ),

        // Search bar
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          child: _showSearch
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.09),
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15))),
                    child: Row(children: [
                      const Padding(
                        padding: EdgeInsets.only(left: 12),
                        child: Icon(Icons.search_rounded,
                          color: Colors.white54, size: 17)),
                      Expanded(
                        child: TextField(
                          controller: _searchCtrl,
                          focusNode: _searchFocus,
                          onChanged: (q) =>
                            _load(search: q.trim().isEmpty ? null : q.trim()),
                          style: GoogleFonts.inter(
                            color: Colors.white, fontSize: 13,
                            fontWeight: FontWeight.w500),
                          decoration: InputDecoration(
                            hintText: 'Search invoice, customer…',
                            hintStyle: GoogleFonts.inter(
                              color: Colors.white.withValues(alpha: 0.35),
                              fontSize: 13),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            filled: true, fillColor: Colors.transparent,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 12),
                            isDense: true),
                        ),
                      ),
                    ]),
                  ),
                )
              : const SizedBox.shrink(),
        ),

        // Filter chips
        SizedBox(
          height: 44,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            itemCount: _filters.length,
            itemBuilder: (_, i) {
              final (id, label) = _filters[i];
              final sel = _filter == id;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _filter = id);
                  _load();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.only(right: 7),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                  decoration: BoxDecoration(
                    color: sel ? AppColors.accent : Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: sel ? AppColors.accent : Colors.white.withValues(alpha: 0.14))),
                  child: Text(label,
                    style: GoogleFonts.inter(
                      fontSize: 12, fontWeight: sel ? FontWeight.w800 : FontWeight.w500,
                      color: sel ? Colors.white : Colors.white.withValues(alpha: 0.55))),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
      ]),
    );
  }

  Widget _buildShimmer() => ListView.builder(
    padding: const EdgeInsets.all(16),
    itemCount: 7,
    itemBuilder: (_, __) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ShimmerBox(width: double.infinity, height: 84, radius: 16),
    ),
  );

  Widget _buildError() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20)),
          child: const Icon(Icons.wifi_off_rounded,
            size: 36, color: Colors.red)),
        const SizedBox(height: 14),
        Text('Connection Error',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16, fontWeight: FontWeight.w800,
            color: AppColors.textPrimary)),
        const SizedBox(height: 6),
        Text(_error!, textAlign: TextAlign.center,
          style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('Retry'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12))),
        ),
      ]),
    ),
  );

  Widget _buildEmpty() => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 72, height: 72,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(20)),
        child: const Icon(Icons.receipt_long_outlined,
          size: 36, color: AppColors.primary)),
      const SizedBox(height: 14),
      Text('No sales found',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 16, fontWeight: FontWeight.w800,
          color: AppColors.textPrimary)),
      const SizedBox(height: 4),
      Text('Try a different filter or time range',
        style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
    ]),
  );
}

class _SummaryPill extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _SummaryPill({required this.label, required this.value,
    required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2))),
      child: Row(children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
              style: GoogleFonts.inter(
                fontSize: 9, fontWeight: FontWeight.w700,
                color: color.withValues(alpha: 0.7), letterSpacing: 0.5)),
            Text(value,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13, fontWeight: FontWeight.w900, color: color)),
          ]),
        ),
      ]),
    ),
  );
}

// ── Sale Card ────────────────────────────────────────────────────────────────
class _SaleCard extends StatelessWidget {
  final Sale sale;
  const _SaleCard({required this.sale});

  static Color _payColor(String method) {
    switch (method) {
      case 'mpesa':    return const Color(0xFF16A34A);
      case 'tigopesa': return const Color(0xFF0369A1);
      case 'airtel':   return const Color(0xFFDC2626);
      case 'bank':     return const Color(0xFF7C3AED);
      case 'credit':   return const Color(0xFFD97706);
      default:         return AppColors.primary;
    }
  }

  static IconData _payIcon(String method) {
    switch (method) {
      case 'mpesa':
      case 'tigopesa':
      case 'airtel':
        return Icons.phone_android_rounded;
      case 'bank':
        return Icons.account_balance_rounded;
      case 'credit':
        return Icons.credit_card_rounded;
      default:
        return Icons.payments_rounded;
    }
  }

  void _openDetail(BuildContext context) {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _InvoiceDetailSheet(sale: sale),
    );
  }

  @override
  Widget build(BuildContext context) {
    final payColor = _payColor(sale.paymentMethod);
    final payLabel = Fmt.payMethod(sale.paymentMethod);
    return PressScale(
      onTap: () => _openDetail(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
          boxShadow: AppShadows.sm),
        child: Row(children: [
          // Left accent bar
          Container(
            width: 4,
            height: 88,
            decoration: BoxDecoration(
              color: sale.isPaid ? payColor : AppColors.danger,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                bottomLeft: Radius.circular(18)))),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 12, 14, 12),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Flexible(
                        child: Text(sale.invoiceNo,
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14, fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary, letterSpacing: -0.3))),
                      const SizedBox(width: 8),
                      StatusBadge.fromStatus(sale.isPaid ? 'paid' : 'partial'),
                    ]),
                    const SizedBox(height: 4),
                    Text(sale.customerName.isNotEmpty ? sale.customerName : 'Walk-in Customer',
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 12, fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary)),
                    const SizedBox(height: 7),
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: payColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: payColor.withValues(alpha: 0.25))),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(_payIcon(sale.paymentMethod), size: 10, color: payColor),
                          const SizedBox(width: 4),
                          Text(payLabel,
                            style: GoogleFonts.inter(
                              fontSize: 10, fontWeight: FontWeight.w700,
                              color: payColor)),
                        ]),
                      ),
                      const SizedBox(width: 6),
                      Icon(Icons.access_time_rounded, size: 11, color: AppColors.textMuted),
                      const SizedBox(width: 3),
                      Text(Fmt.dateTime(sale.createdAt),
                        style: GoogleFonts.inter(
                          fontSize: 10, color: AppColors.textMuted,
                          fontWeight: FontWeight.w500)),
                    ]),
                  ]),
                ),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(Fmt.money(sale.totalAmount),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16, fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary, letterSpacing: -0.4)),
                  if (!sale.isPaid) ...[
                    const SizedBox(height: 4),
                    Text('Due ${Fmt.money(sale.totalAmount - sale.paidAmount)}',
                      style: GoogleFonts.inter(
                        fontSize: 10, fontWeight: FontWeight.w700,
                        color: AppColors.danger)),
                  ] else ...[
                    const SizedBox(height: 6),
                    Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.chevron_right_rounded,
                        size: 16, color: AppColors.primary)),
                  ],
                ]),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Invoice Detail Bottom Sheet ───────────────────────────────────────────────
class _InvoiceDetailSheet extends StatefulWidget {
  final Sale sale;
  const _InvoiceDetailSheet({required this.sale});

  @override
  State<_InvoiceDetailSheet> createState() => _InvoiceDetailSheetState();
}

class _InvoiceDetailSheetState extends State<_InvoiceDetailSheet>
    with SingleTickerProviderStateMixin {
  SaleDetail? _detail;
  bool _loading = true;
  String? _error;
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this,
      duration: const Duration(milliseconds: 600));
    _load();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    try {
      final d = await ApiService.getSaleDetail(widget.sale.id);
      if (!mounted) return;
      setState(() { _detail = d; _loading = false; });
      _ctrl.forward();
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);

    // Use live loaded data for status/balance so it updates after collection
    final isPaid = _detail != null
        ? (_detail!.totalAmount - _detail!.paidAmount) < 0.01
        : widget.sale.isPaid;
    final liveBalance = _detail != null
        ? _detail!.totalAmount - _detail!.paidAmount
        : widget.sale.totalAmount - widget.sale.paidAmount;
    final hasBalance = liveBalance > 0.5;

    return Container(
      constraints: BoxConstraints(maxHeight: mq.size.height * 0.92),
      decoration: const BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // ── Premium header ──────────────────────────────────────────────────
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF061410), Color(0xFF0F2D1A), Color(0xFF1a472a)],
              begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: Column(children: [
            Center(
              child: Container(width: 36, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Row(children: [
              Container(
                width: 50, height: 50,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.accent.withValues(alpha: 0.3))),
                child: const Icon(Icons.receipt_rounded,
                  color: AppColors.accent, size: 22)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(widget.sale.invoiceNo,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18, fontWeight: FontWeight.w900,
                      color: Colors.white, letterSpacing: -0.4)),
                  const SizedBox(height: 3),
                  Row(children: [
                    StatusBadge.fromStatus(isPaid ? 'paid' : 'partial'),
                    const SizedBox(width: 8),
                    Text(
                      widget.sale.customerName.isNotEmpty
                          ? widget.sale.customerName : 'Walk-in Customer',
                      style: GoogleFonts.inter(
                        fontSize: 11, fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.5)),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  ]),
                ]),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(Fmt.money(widget.sale.totalAmount),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22, fontWeight: FontWeight.w900,
                    color: AppColors.accent, letterSpacing: -0.5)),
                if (hasBalance)
                  Text('Due ${Fmt.money(liveBalance)}',
                    style: GoogleFonts.inter(
                      fontSize: 10, fontWeight: FontWeight.w700,
                      color: const Color(0xFFFCA5A5))),
              ]),
            ]),
            const SizedBox(height: 14),
            // ── Action chips ──────────────────────────────────────────────
            Row(children: [
              _HeaderChip(
                icon: Icons.copy_all_rounded,
                label: 'Copy #',
                onTap: _copyInvoiceNo,
              ),
              const SizedBox(width: 8),
              _HeaderChip(
                icon: Icons.share_rounded,
                label: 'Share',
                onTap: _shareInvoice,
              ),
              if (_detail != null && _detail!.custPhone.isNotEmpty) ...[
                const SizedBox(width: 8),
                _HeaderChip(
                  icon: Icons.phone_rounded,
                  label: 'Call',
                  onTap: _callCustomer,
                ),
              ],
              const SizedBox(width: 8),
              _HeaderChip(
                icon: Icons.edit_rounded,
                label: 'Amend',
                onTap: _openAmendSheet,
                accent: true,
              ),
            ]),
          ]),
        ),

        // ── Content ─────────────────────────────────────────────────────────
        Flexible(
          child: _loading
              ? const SizedBox(
                  height: 200,
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary)))
              : _error != null
                  ? SizedBox(
                      height: 200,
                      child: ErrorState(message: _error!, onRetry: _load))
                  : _buildContent(),
        ),

        // ── Sticky collect payment button ────────────────────────────────
        if (!_loading && _detail != null && hasBalance)
          Container(
            padding: EdgeInsets.fromLTRB(16, 12, 16,
              MediaQuery.of(context).padding.bottom + 16),
            decoration: BoxDecoration(
              color: AppColors.bg,
              border: Border(top: BorderSide(color: AppColors.border))),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _openCollectSheet,
                icon: const Icon(Icons.payments_rounded, size: 18),
                label: Text('Collect ${Fmt.money(liveBalance)}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14, fontWeight: FontWeight.w900)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16))),
              ),
            ),
          ),
      ]),
    );
  }

  void _copyInvoiceNo() {
    HapticFeedback.selectionClick();
    Clipboard.setData(ClipboardData(text: widget.sale.invoiceNo));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.copy_rounded, color: Colors.white, size: 16),
        const SizedBox(width: 8),
        Text('Invoice number copied',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white)),
      ]),
      backgroundColor: AppColors.primary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 2),
    ));
  }

  void _shareInvoice() {
    HapticFeedback.selectionClick();
    final d = _detail;
    final fmt = NumberFormat('#,##0', 'en_US');
    final balance = d != null ? d.totalAmount - d.paidAmount : 0.0;
    final isPaid = balance < 0.01;
    final date = d != null
        ? DateFormat('dd MMM yyyy').format(d.createdAt)
        : DateFormat('dd MMM yyyy').format(DateTime.now());

    final buf = StringBuffer();
    buf.writeln('🧾 *INVOICE — ${widget.sale.invoiceNo}*');
    buf.writeln('─────────────────────');
    if (d != null && d.custName.isNotEmpty && d.custName != 'Cash Customer') {
      buf.writeln('👤 Customer: ${d.custName}');
    }
    buf.writeln('📅 Date: $date');
    if (d != null && d.items.isNotEmpty) {
      buf.writeln('📦 Items: ${d.items.length}');
    }
    buf.writeln('─────────────────────');
    buf.writeln('💰 Total: *TZS ${fmt.format(widget.sale.totalAmount)}*');
    if (d != null && d.paidAmount > 0 && d.paidAmount < d.totalAmount) {
      buf.writeln('✅ Paid: TZS ${fmt.format(d.paidAmount)}');
      buf.writeln('⏳ Balance: TZS ${fmt.format(balance)}');
    } else {
      buf.writeln('Status: ${isPaid ? '✅ PAID' : '⏳ OUTSTANDING'}');
    }
    buf.writeln('─────────────────────');
    buf.writeln('_Powered by MDSPro_');

    Share.share(
      buf.toString(),
      subject: 'Invoice ${widget.sale.invoiceNo}',
    );
  }

  void _callCustomer() {
    final phone = _detail?.custPhone ?? '';
    if (phone.isEmpty) return;
    HapticFeedback.selectionClick();
    launchUrl(Uri.parse('tel:$phone'));
  }

  void _openAmendSheet() {
    if (_detail == null) return;
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AmendSheet(
        saleId: widget.sale.id,
        invoiceNo: widget.sale.invoiceNo,
        currentPaymentMethod: _detail!.paymentMethod,
        currentNotes: _detail!.notes,
        onSuccess: () {
          _load();
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Row(children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Text('Invoice amended successfully',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700, color: Colors.white)),
            ]),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 3),
          ));
        },
      ),
    );
  }

  void _openCollectSheet() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CollectPaymentSheet(
        saleId: widget.sale.id,
        invoiceNo: widget.sale.invoiceNo,
        balanceDue: _detail!.totalAmount - _detail!.paidAmount,
        onSuccess: () {
          _load();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(children: [
                const Icon(Icons.check_circle_rounded,
                  color: Colors.white, size: 18),
                const SizedBox(width: 10),
                Text('Payment collected successfully',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700, color: Colors.white)),
              ]),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.all(16),
              duration: const Duration(seconds: 3),
            ),
          );
        },
      ),
    );
  }

  Widget _buildContent() {
    final d = _detail!;
    final fmt = NumberFormat('#,##0', 'en_US');

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      child: FadeTransition(
        opacity: _ctrl,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 16),

          // ── Meta info card ────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
              boxShadow: AppShadows.sm),
            child: Column(children: [
              _MetaRow(Icons.calendar_today_rounded, 'Date',
                DateFormat('dd MMM yyyy  hh:mm a').format(d.createdAt)),
              if (d.servedBy.isNotEmpty) ...[
                _metaDivider(),
                _MetaRow(Icons.person_outline_rounded, 'Served by', d.servedBy),
              ],
              if (d.branchName.isNotEmpty) ...[
                _metaDivider(),
                _MetaRow(Icons.storefront_outlined, 'Branch', d.branchName),
              ],
              _metaDivider(),
              _MetaRow(Icons.payment_rounded, 'Payment',
                Fmt.payMethod(d.paymentMethod)),
              if (d.custPhone.isNotEmpty) ...[
                _metaDivider(),
                _MetaRow(Icons.phone_outlined, 'Phone', d.custPhone,
                  onTap: () => launchUrl(Uri.parse('tel:${d.custPhone}'))),
              ],
            ]),
          ),

          const SizedBox(height: 16),

          // ── Items section ────────────────────────────────────────────────
          Row(children: const [
            Icon(Icons.inventory_2_outlined, size: 14, color: AppColors.textMuted),
            SizedBox(width: 6),
            Text('ITEMS',
              style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w800,
                color: AppColors.textMuted, letterSpacing: 1.0)),
          ]),
          const SizedBox(height: 8),

          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
              boxShadow: AppShadows.sm),
            child: Column(children: [
              // Header row
              Container(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.04),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  border: Border(bottom: BorderSide(color: AppColors.border))),
                child: const Row(children: [
                  Expanded(flex: 4, child: _ColHeader('ITEM')),
                  Expanded(flex: 1, child: _ColHeader('QTY', align: TextAlign.center)),
                  Expanded(flex: 2, child: _ColHeader('PRICE', align: TextAlign.right)),
                  Expanded(flex: 2, child: _ColHeader('TOTAL', align: TextAlign.right)),
                ]),
              ),

              // Items
              ...d.items.asMap().entries.map((e) {
                final i = e.key;
                final item = e.value;
                final isLast = i == d.items.length - 1;
                return StaggeredItem(
                  index: i,
                  controller: _ctrl,
                  child: Container(
                    decoration: BoxDecoration(
                      color: i.isEven ? Colors.white : AppColors.bg.withValues(alpha: 0.6),
                      borderRadius: isLast
                          ? const BorderRadius.vertical(bottom: Radius.circular(15))
                          : BorderRadius.zero),
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    child: Column(children: [
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Expanded(
                          flex: 4,
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(item.productName,
                              style: GoogleFonts.inter(
                                fontSize: 13, fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary),
                              maxLines: 2, overflow: TextOverflow.ellipsis),
                            if (item.sku.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(item.sku,
                                  style: GoogleFonts.inter(
                                    fontSize: 10, fontWeight: FontWeight.w500,
                                    color: AppColors.textMuted))),
                            if (item.discount > 0)
                              Container(
                                margin: const EdgeInsets.only(top: 3),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.dangerBg,
                                  borderRadius: BorderRadius.circular(6)),
                                child: Text('- ${fmt.format(item.discount)} disc',
                                  style: GoogleFonts.inter(
                                    fontSize: 9, fontWeight: FontWeight.w700,
                                    color: AppColors.danger))),
                          ]),
                        ),
                        Expanded(
                          flex: 1,
                          child: Text(
                            '${Fmt.qty(item.quantity)}${item.unit.isNotEmpty ? ' ${item.unit}' : ''}',
                            style: GoogleFonts.inter(
                              fontSize: 12, fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary),
                            textAlign: TextAlign.center)),
                        Expanded(
                          flex: 2,
                          child: Text(fmt.format(item.unitPrice),
                            style: GoogleFonts.inter(
                              fontSize: 12, fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary),
                            textAlign: TextAlign.right)),
                        Expanded(
                          flex: 2,
                          child: Text(fmt.format(item.total),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13, fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary),
                            textAlign: TextAlign.right)),
                      ]),
                      if (!isLast) ...[
                        const SizedBox(height: 0),
                        const Divider(height: 1, color: AppColors.borderLight),
                      ],
                    ]),
                  ),
                );
              }),
            ]),
          ),

          const SizedBox(height: 16),

          // ── Totals card ──────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F2D1A), Color(0xFF1a4a2e)],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.25),
                blurRadius: 16, offset: const Offset(0, 5))]),
            child: Column(children: [
              if (d.discountAmount > 0)
                _DarkTotalRow('Discount',
                  '- ${fmt.format(d.discountAmount)}',
                  valueColor: const Color(0xFF4ADE80)),
              if (d.taxAmount > 0)
                _DarkTotalRow('Tax (VAT 18%)', fmt.format(d.taxAmount)),
              _DarkTotalRow('Subtotal', fmt.format(d.totalAmount)),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Container(
                  height: 1, color: Colors.white.withValues(alpha: 0.12))),
              Row(children: [
                Text('Total',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14, fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.65))),
                const Spacer(),
                Text(fmt.format(d.totalAmount),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22, fontWeight: FontWeight.w900,
                    color: AppColors.accent, letterSpacing: -0.5)),
              ]),
              if (d.paidAmount > 0 && d.paidAmount != d.totalAmount) ...[
                const SizedBox(height: 10),
                Container(height: 1, color: Colors.white.withValues(alpha: 0.08)),
                const SizedBox(height: 10),
                _DarkTotalRow('Paid', fmt.format(d.paidAmount),
                  valueColor: const Color(0xFF4ADE80)),
                _DarkTotalRow('Balance Due',
                  fmt.format(d.totalAmount - d.paidAmount),
                  valueColor: const Color(0xFFFCA5A5)),
              ],
            ]),
          ),

          if (d.notes.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.warningBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.warning.withValues(alpha: 0.3))),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.notes_rounded, size: 15, color: AppColors.warning),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(d.notes,
                    style: GoogleFonts.inter(
                      fontSize: 12, fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary))),
              ]),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _metaDivider() => Container(
    height: 1, margin: const EdgeInsets.symmetric(vertical: 8),
    color: AppColors.borderLight);
}

class _MetaRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final VoidCallback? onTap;
  const _MetaRow(this.icon, this.label, this.value, {this.onTap});

  @override
  Widget build(BuildContext context) {
    final row = Row(children: [
      Container(
        width: 30, height: 30,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 14, color: AppColors.primary)),
      const SizedBox(width: 10),
      Text(label,
        style: GoogleFonts.inter(
          fontSize: 12, fontWeight: FontWeight.w600,
          color: AppColors.textMuted)),
      const SizedBox(width: 8),
      Expanded(
        child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          Flexible(
            child: Text(value,
              style: GoogleFonts.inter(
                fontSize: 12, fontWeight: FontWeight.w700,
                color: onTap != null ? AppColors.primary : AppColors.textPrimary),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis)),
          if (onTap != null) ...[
            const SizedBox(width: 4),
            const Icon(Icons.open_in_new_rounded, size: 12, color: AppColors.primary),
          ],
        ]),
      ),
    ]);
    if (onTap == null) return row;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: row,
    );
  }
}

class _ColHeader extends StatelessWidget {
  final String text;
  final TextAlign align;
  const _ColHeader(this.text, {this.align = TextAlign.left});

  @override
  Widget build(BuildContext context) => Text(text,
    textAlign: align,
    style: GoogleFonts.inter(
      fontSize: 9, fontWeight: FontWeight.w800,
      color: AppColors.textMuted, letterSpacing: 0.6));
}

class _DarkTotalRow extends StatelessWidget {
  final String label, value;
  final Color? valueColor;
  const _DarkTotalRow(this.label, this.value, {this.valueColor});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(children: [
      Text(label,
        style: GoogleFonts.inter(
          fontSize: 13, fontWeight: FontWeight.w500,
          color: Colors.white.withValues(alpha: 0.5))),
      const Spacer(),
      Text(value,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 13, fontWeight: FontWeight.w700,
          color: valueColor ?? Colors.white.withValues(alpha: 0.8))),
    ]),
  );
}

String _fmtMoney(double v) {
  final n = v.toInt().toString()
    .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
  return 'TZS $n';
}

// ── Amend Invoice Sheet ───────────────────────────────────────────────────────
class _AmendSheet extends StatefulWidget {
  final int saleId;
  final String invoiceNo;
  final String currentPaymentMethod;
  final String currentNotes;
  final VoidCallback onSuccess;
  const _AmendSheet({
    required this.saleId,
    required this.invoiceNo,
    required this.currentPaymentMethod,
    required this.currentNotes,
    required this.onSuccess,
  });

  @override
  State<_AmendSheet> createState() => _AmendSheetState();
}

class _AmendSheetState extends State<_AmendSheet> {
  static const _methods = [
    ('cash',     'Cash',      Icons.payments_rounded,          Color(0xFF0F2D1A)),
    ('mpesa',    'M-Pesa',    Icons.phone_android_rounded,     Color(0xFF16A34A)),
    ('tigopesa', 'Tigo Pesa', Icons.phone_android_rounded,     Color(0xFF0369A1)),
    ('airtel',   'Airtel',    Icons.phone_android_rounded,     Color(0xFFDC2626)),
    ('bank',     'Bank',      Icons.account_balance_rounded,   Color(0xFF7C3AED)),
    ('credit',   'Credit',    Icons.credit_card_rounded,       Color(0xFFD97706)),
  ];

  late String _method;
  late final TextEditingController _notesCtrl;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _method   = widget.currentPaymentMethod;
    _notesCtrl = TextEditingController(text: widget.currentNotes);
  }

  @override
  void dispose() { _notesCtrl.dispose(); super.dispose(); }

  bool get _hasChanges =>
      _method != widget.currentPaymentMethod ||
      _notesCtrl.text.trim() != widget.currentNotes.trim();

  Future<void> _submit() async {
    if (!_hasChanges) { Navigator.pop(context); return; }
    setState(() { _submitting = true; _error = null; });
    final res = await ApiService.amendSale(
      saleId:        widget.saleId,
      paymentMethod: _method != widget.currentPaymentMethod ? _method : null,
      notes:         _notesCtrl.text.trim() != widget.currentNotes.trim()
                         ? _notesCtrl.text.trim() : null,
    );
    if (!mounted) return;
    if (res['ok'] == true) {
      HapticFeedback.heavyImpact();
      Navigator.pop(context);
      widget.onSuccess();
    } else {
      setState(() {
        _submitting = false;
        _error = res['error']?.toString() ?? 'Amendment failed';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: mq.size.height * 0.88),
        decoration: const BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // ── Premium header ──────────────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF061410), Color(0xFF0F2D1A), Color(0xFF1a472a)],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            child: Column(children: [
              Center(child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Row(children: [
                Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.3))),
                  child: const Icon(Icons.edit_rounded,
                    color: AppColors.accent, size: 20)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Amend Invoice',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18, fontWeight: FontWeight.w900,
                        color: Colors.white, letterSpacing: -0.4)),
                    Text(widget.invoiceNo,
                      style: GoogleFonts.inter(
                        fontSize: 11, fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.5))),
                  ]),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 34, height: 34,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.close_rounded,
                      color: Colors.white54, size: 18))),
              ]),
            ]),
          ),

          // ── Body ────────────────────────────────────────────────────────
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                // Info banner
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warningBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.3))),
                  child: Row(children: [
                    const Icon(Icons.info_outline_rounded,
                      size: 15, color: AppColors.warning),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'You can change the payment method and notes. '
                        'Item changes must be done from the web portal.',
                        style: GoogleFonts.inter(
                          fontSize: 11, fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary))),
                  ]),
                ),
                const SizedBox(height: 20),

                // Payment method
                Text('PAYMENT METHOD',
                  style: GoogleFonts.inter(
                    fontSize: 10, fontWeight: FontWeight.w800,
                    color: AppColors.textMuted, letterSpacing: 1.0)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: _methods.map((m) {
                    final (id, label, icon, color) = m;
                    final sel = _method == id;
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _method = id);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 9),
                        decoration: BoxDecoration(
                          color: sel ? color : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: sel ? color : AppColors.border,
                            width: sel ? 2 : 1),
                          boxShadow: sel ? [] : AppShadows.sm),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(icon, size: 14,
                            color: sel ? Colors.white : AppColors.textMuted),
                          const SizedBox(width: 6),
                          Text(label,
                            style: GoogleFonts.inter(
                              fontSize: 12, fontWeight: FontWeight.w700,
                              color: sel ? Colors.white : AppColors.textSecondary)),
                        ]),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),

                // Notes
                Text('NOTES',
                  style: GoogleFonts.inter(
                    fontSize: 10, fontWeight: FontWeight.w800,
                    color: AppColors.textMuted, letterSpacing: 1.0)),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                    boxShadow: AppShadows.sm),
                  child: TextField(
                    controller: _notesCtrl,
                    maxLines: 3,
                    style: GoogleFonts.inter(
                      fontSize: 14, fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Add notes about this invoice…',
                      hintStyle: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.textMuted.withValues(alpha: 0.5)),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.all(14)),
                  ),
                ),

                // Error
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.dangerBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.danger.withValues(alpha: 0.3))),
                    child: Row(children: [
                      const Icon(Icons.error_outline_rounded,
                        size: 15, color: AppColors.danger),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_error!,
                          style: GoogleFonts.inter(
                            fontSize: 12, fontWeight: FontWeight.w600,
                            color: AppColors.danger))),
                    ]),
                  ),
                ],
              ]),
            ),
          ),

          // ── Save button ─────────────────────────────────────────────────
          Container(
            padding: EdgeInsets.fromLTRB(20, 12, 20, mq.padding.bottom + 20),
            decoration: BoxDecoration(
              color: AppColors.bg,
              border: Border(top: BorderSide(color: AppColors.border))),
            child: SizedBox(
              width: double.infinity, height: 54,
              child: ElevatedButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_rounded, size: 18),
                label: Text(
                  _hasChanges ? 'Save Changes' : 'No Changes',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15, fontWeight: FontWeight.w900)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _hasChanges
                      ? AppColors.accent : AppColors.border,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      AppColors.accent.withValues(alpha: 0.4),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16))),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Header action chip ────────────────────────────────────────────────────────
class _HeaderChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool accent;
  const _HeaderChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: accent
            ? AppColors.accent.withValues(alpha: 0.25)
            : Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: accent
              ? AppColors.accent.withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.2))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13,
          color: accent ? AppColors.accent : Colors.white.withValues(alpha: 0.85)),
        const SizedBox(width: 5),
        Text(label,
          style: GoogleFonts.inter(
            fontSize: 11, fontWeight: FontWeight.w700,
            color: accent ? AppColors.accent : Colors.white.withValues(alpha: 0.85))),
      ]),
    ),
  );
}

// ── Collect Payment Sheet ─────────────────────────────────────────────────────
class _CollectPaymentSheet extends StatefulWidget {
  final int saleId;
  final String invoiceNo;
  final double balanceDue;
  final VoidCallback onSuccess;
  const _CollectPaymentSheet({
    required this.saleId,
    required this.invoiceNo,
    required this.balanceDue,
    required this.onSuccess,
  });

  @override
  State<_CollectPaymentSheet> createState() => _CollectPaymentSheetState();
}

class _CollectPaymentSheetState extends State<_CollectPaymentSheet> {
  static const _methods = [
    ('cash',     'Cash',      Icons.payments_rounded),
    ('mpesa',    'M-Pesa',    Icons.phone_android_rounded),
    ('tigopesa', 'Tigo Pesa', Icons.phone_android_rounded),
    ('airtel',   'Airtel',    Icons.phone_android_rounded),
    ('bank',     'Bank',      Icons.account_balance_rounded),
  ];

  String _method = 'cash';
  late final TextEditingController _amtCtrl;
  final _refCtrl = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _amtCtrl = TextEditingController(
        text: widget.balanceDue.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _amtCtrl.dispose();
    _refCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amt = double.tryParse(_amtCtrl.text.replaceAll(',', '')) ?? 0;
    if (amt <= 0) {
      setState(() => _error = 'Enter a valid amount');
      return;
    }
    setState(() { _submitting = true; _error = null; });
    final res = await ApiService.collectPayment(
      saleId: widget.saleId,
      amount: amt,
      paymentMethod: _method,
      reference: _refCtrl.text.trim(),
    );
    if (!mounted) return;
    if (res['ok'] == true) {
      HapticFeedback.heavyImpact();
      Navigator.pop(context);
      widget.onSuccess();
    } else {
      setState(() {
        _submitting = false;
        _error = res['error'] ?? 'Collection failed';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final needsRef = _method != 'cash' && _method != 'bank';

    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        padding: EdgeInsets.fromLTRB(20, 14, 20, mq.padding.bottom + 24),
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Drag handle
            Center(
              child: Container(width: 36, height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2)))),

            // Header row
            Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              Container(
                width: 46, height: 46,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: AppColors.accent.withValues(alpha: 0.25))),
                child: const Icon(Icons.payments_rounded,
                  color: AppColors.accent, size: 20)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Collect Payment',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 17, fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary, letterSpacing: -0.3)),
                  Text(widget.invoiceNo,
                    style: GoogleFonts.inter(
                      fontSize: 11, fontWeight: FontWeight.w600,
                      color: AppColors.textMuted)),
                ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('Outstanding',
                  style: GoogleFonts.inter(
                    fontSize: 9, fontWeight: FontWeight.w700,
                    color: AppColors.textMuted, letterSpacing: 0.4)),
                Text(Fmt.money(widget.balanceDue),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15, fontWeight: FontWeight.w900,
                    color: AppColors.danger, letterSpacing: -0.3)),
              ]),
            ]),
            const SizedBox(height: 24),

            // Payment method
            Align(
              alignment: Alignment.centerLeft,
              child: Text('PAYMENT METHOD',
                style: GoogleFonts.inter(
                  fontSize: 10, fontWeight: FontWeight.w800,
                  color: AppColors.textMuted, letterSpacing: 1.0))),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _methods.map((m) {
                final (id, label, icon) = m;
                final sel = _method == id;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _method = id);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: sel ? AppColors.primary : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: sel ? AppColors.primary : AppColors.border,
                        width: sel ? 2 : 1),
                      boxShadow: sel ? [] : AppShadows.sm),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(icon, size: 14,
                        color: sel ? AppColors.accent : AppColors.textMuted),
                      const SizedBox(width: 6),
                      Text(label,
                        style: GoogleFonts.inter(
                          fontSize: 12, fontWeight: FontWeight.w700,
                          color: sel ? Colors.white : AppColors.textSecondary)),
                    ]),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Amount field
            Align(
              alignment: Alignment.centerLeft,
              child: Text('AMOUNT (TZS)',
                style: GoogleFonts.inter(
                  fontSize: 10, fontWeight: FontWeight.w800,
                  color: AppColors.textMuted, letterSpacing: 1.0))),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
                boxShadow: AppShadows.sm),
              child: TextField(
                controller: _amtCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 20, fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: '0',
                  hintStyle: GoogleFonts.plusJakartaSans(
                    fontSize: 20, fontWeight: FontWeight.w900,
                    color: AppColors.textMuted.withValues(alpha: 0.3)),
                  prefixText: 'TZS  ',
                  prefixStyle: GoogleFonts.inter(
                    fontSize: 13, fontWeight: FontWeight.w700,
                    color: AppColors.textMuted),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  filled: false),
              ),
            ),

            // Reference field (mobile money only)
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              child: needsRef
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),
                        Text('TRANSACTION REFERENCE (OPTIONAL)',
                          style: GoogleFonts.inter(
                            fontSize: 10, fontWeight: FontWeight.w800,
                            color: AppColors.textMuted, letterSpacing: 1.0)),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border),
                            boxShadow: AppShadows.sm),
                          child: TextField(
                            controller: _refCtrl,
                            style: GoogleFonts.inter(
                              fontSize: 14, fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary),
                            decoration: InputDecoration(
                              hintText: 'e.g. TCR7XXXX (optional)',
                              hintStyle: GoogleFonts.inter(
                                fontSize: 13,
                                color: AppColors.textMuted
                                    .withValues(alpha: 0.45)),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding:
                                  const EdgeInsets.fromLTRB(16, 14, 16, 14),
                              filled: false),
                          ),
                        ),
                      ])
                  : const SizedBox.shrink(),
            ),

            // Error banner
            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.dangerBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.danger.withValues(alpha: 0.3))),
                child: Row(children: [
                  const Icon(Icons.error_outline_rounded,
                    size: 15, color: AppColors.danger),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_error!,
                      style: GoogleFonts.inter(
                        fontSize: 12, fontWeight: FontWeight.w600,
                        color: AppColors.danger))),
                ]),
              ),
            ],
            const SizedBox(height: 24),

            // Confirm button
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      AppColors.accent.withValues(alpha: 0.5),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16))),
                child: _submitting
                    ? const SizedBox(
                        width: 22, height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white))
                    : Text('Confirm Collection',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15, fontWeight: FontWeight.w900)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
