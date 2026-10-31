import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatter.dart';
import '../widgets/pin_confirm_sheet.dart';

class StockAdjustmentsScreen extends StatefulWidget {
  const StockAdjustmentsScreen({super.key});

  @override
  State<StockAdjustmentsScreen> createState() => _StockAdjustmentsScreenState();
}

class _StockAdjustmentsScreenState extends State<StockAdjustmentsScreen> {
  final _searchCtrl = TextEditingController();

  List<Map<String, dynamic>>  _rows    = [];
  List<PendingAdjustment>    _pending = [];
  List<Branch>               _branches = [];
  AuthUser?                  _user;
  int?                       _branchId; // null = all branches
  bool   _loading        = true;
  bool   _pendingLoading = false;
  bool   _branchesLoading = false;
  String? _error;
  String _date = 'month';

  static const _dateFilters = [
    ('today', 'Today'),
    ('week',  'This Week'),
    ('month', 'This Month'),
    ('all',   'All Time'),
  ];

  bool get _isManager =>
      (_user?.role == 'owner' || _user?.role == 'manager') &&
      (_user?.canAccess('stock') ?? false);

  List<PendingAdjustment> get _filteredPending =>
      _branchId == null
          ? _pending
          : _pending.where((p) => p.branchId == _branchId).toList();

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final user = await ApiService.getCachedUser();
    if (!mounted) return;
    setState(() => _user = user);
    if (user?.role == 'owner' || user?.role == 'manager') {
      _loadBranches();
      _loadPending();
    }
    _load();
  }

  Future<void> _loadPending() async {
    setState(() => _pendingLoading = true);
    try {
      final rows = await ApiService.getPendingAdjustments();
      if (mounted) setState(() { _pending = rows; _pendingLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _pendingLoading = false);
    }
  }

  Future<void> _approve(int id) async {
    final pinOk = await showPinConfirm(context,
      title: 'Confirm Approval',
      subtitle: 'Enter your PIN to approve this adjustment',
      accentColor: AppColors.success,
      icon: Icons.check_circle_outline_rounded,
    );
    if (!pinOk || !mounted) return;

    setState(() => _pending.removeWhere((p) => p.id == id)); // optimistic remove
    final res = await ApiService.approvePendingAdjustment(id);
    if (!mounted) return;
    if (res['ok'] == true) {
      _loadPending();
      _load();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Adjustment approved and applied.'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(res['error']?.toString() ?? 'Approval failed'),
        backgroundColor: AppColors.danger,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }

  Future<void> _reject(int id) async {
    final pinOk = await showPinConfirm(context,
      title: 'Confirm Rejection',
      subtitle: 'Enter your PIN to reject this adjustment',
      accentColor: AppColors.danger,
      icon: Icons.cancel_outlined,
    );
    if (!pinOk || !mounted) return;

    String reason = '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Adjustment'),
        content: TextField(
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Reason (optional)',
            border: OutlineInputBorder(),
          ),
          onChanged: (v) => reason = v,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Reject', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _pending.removeWhere((p) => p.id == id)); // optimistic remove
    final res = await ApiService.rejectPendingAdjustment(id, reason);
    if (!mounted) return;
    if (res['ok'] == true) {
      _loadPending();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Adjustment rejected.'),
        backgroundColor: AppColors.textMuted,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }

  Future<void> _loadBranches() async {
    setState(() => _branchesLoading = true);
    try {
      final branches = await ApiService.getBranches();
      if (mounted) setState(() { _branches = branches; _branchesLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _branchesLoading = false);
    }
  }

  Future<void> _load({String? search}) async {
    setState(() { _loading = true; _error = null; });
    try {
      final rows = await ApiService.getStockAdjustments(
        date: _date,
        search: search ?? _searchCtrl.text.trim(),
        branchId: _isManager ? _branchId : null,
      );
      if (!mounted) return;
      setState(() { _rows = rows; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = 'Failed to load adjustments. Pull to refresh.'; });
    }
  }

  // Stats
  int    get _totalCount   => _rows.length;
  double get _totalAdded   => _rows
      .where((r) => (r['after_qty'] as num) >= (r['before_qty'] as num))
      .fold(0.0, (s, r) => s + (r['qty'] as num).abs());
  double get _totalRemoved => _rows
      .where((r) => (r['after_qty'] as num) < (r['before_qty'] as num))
      .fold(0.0, (s, r) => s + (r['qty'] as num).abs());

  String _fmtDate(String? raw) {
    if (raw == null) return '';
    try {
      return DateFormat('d MMM yyyy, HH:mm').format(DateTime.parse(raw).toLocal());
    } catch (_) { return raw; }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(children: [
        _buildHeader(),
        _buildFilters(),
        Expanded(child: _buildBody()),
      ]),
    );
  }

  Widget _buildPendingBanner() {
    if (_pendingLoading) {
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFDE68A), width: 1.5),
        ),
        child: const Row(children: [
          SizedBox(width: 16, height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFF59E0B))),
          SizedBox(width: 10),
          Text('Loading approval requests…',
            style: TextStyle(fontSize: 12, color: Color(0xFF92400E))),
        ]),
      );
    }
    final fp = _filteredPending;
    if (fp.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Row(children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                  blurRadius: 8, offset: const Offset(0, 3))]),
              child: const Icon(Icons.pending_actions_rounded,
                size: 19, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Approval Requests',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15, fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary, letterSpacing: -0.2)),
                Text('${fp.length} adjustment${fp.length > 1 ? 's' : ''} awaiting your approval',
                  style: GoogleFonts.inter(
                    fontSize: 11, fontWeight: FontWeight.w500,
                    color: AppColors.textMuted)),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFFDE68A))),
              child: Text('${fp.length} pending',
                style: GoogleFonts.inter(
                  fontSize: 10, fontWeight: FontWeight.w800,
                  color: const Color(0xFF92400E))),
            ),
          ]),
        ),
        ...fp.map((a) => _PendingItem(
          item: a,
          onApprove: () => _approve(a.id),
          onReject: () => _reject(a.id),
        )),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          child: Divider(color: AppColors.border),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0C2518), AppColors.primary, Color(0xFF1A4A2E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 20, 16),
          child: Row(children: [
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_rounded,
                color: Colors.white, size: 22),
            ),
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.18)),
              ),
              child: const Icon(Icons.tune_rounded,
                color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Stock Adjustments',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 19, fontWeight: FontWeight.w900,
                      color: Colors.white, letterSpacing: -0.4)),
                  Text(
                    _isManager
                        ? (_branchId == null
                            ? 'All branches'
                            : _branches
                                .where((b) => b.id == _branchId)
                                .map((b) => b.name)
                                .firstOrNull ?? 'Branch')
                        : 'This branch',
                    style: GoogleFonts.inter(
                      fontSize: 11, fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.5))),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Branch picker (owner/manager only)
        if (_isManager && (_branches.isNotEmpty || _branchesLoading)) ...[
          _branchesLoading
              ? const SizedBox(
                  height: 36,
                  child: Center(child: SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))))
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    _BranchChip(
                      label: 'All Branches',
                      selected: _branchId == null,
                      onTap: () {
                        if (_branchId == null) return;
                        setState(() => _branchId = null);
                        _load();
                      },
                    ),
                    ..._branches.map((b) => _BranchChip(
                      label: b.name,
                      selected: _branchId == b.id,
                      onTap: () {
                        if (_branchId == b.id) return;
                        setState(() => _branchId = b.id);
                        _load();
                      },
                    )),
                  ]),
                ),
          const SizedBox(height: 10),
        ],

        // Date filter chips
        Row(
          children: _dateFilters.map((f) {
            final sel = _date == f.$1;
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  if (_date == f.$1) return;
                  setState(() => _date = f.$1);
                  _load();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: sel ? AppColors.primary
                               : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(f.$2,
                      style: GoogleFonts.inter(
                        fontSize: 11, fontWeight: FontWeight.w700,
                        color: sel ? Colors.white : AppColors.textMuted)),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 10),

        // Search bar
        TextField(
          controller: _searchCtrl,
          onChanged: (v) => _load(search: v.trim()),
          style: GoogleFonts.inter(
            fontSize: 14, color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Search by product name…',
            hintStyle: GoogleFonts.inter(
              fontSize: 13, color: AppColors.textMuted),
            prefixIcon: const Icon(Icons.search_rounded,
              size: 18, color: AppColors.textMuted),
            suffixIcon: _searchCtrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close_rounded, size: 16),
                    onPressed: () {
                      _searchCtrl.clear();
                      _load(search: '');
                    })
                : null,
            filled: true,
            fillColor: const Color(0xFFF5F7FA),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppColors.primary.withValues(alpha: 0.4))),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 11),
          ),
        ),
        const SizedBox(height: 12),
      ]),
    );
  }

  Widget _buildSummary() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(children: [
        _SummaryTile(
          label: 'Adjustments',
          value: '$_totalCount',
          icon: Icons.list_alt_rounded,
          color: AppColors.primary,
          bg: AppColors.primary.withValues(alpha: 0.08)),
        const SizedBox(width: 8),
        _SummaryTile(
          label: 'Added',
          value: '+${Fmt.qty(_totalAdded)}',
          icon: Icons.add_circle_outline_rounded,
          color: AppColors.success,
          bg: AppColors.success.withValues(alpha: 0.08)),
        const SizedBox(width: 8),
        _SummaryTile(
          label: 'Removed',
          value: '-${Fmt.qty(_totalRemoved)}',
          icon: Icons.remove_circle_outline_rounded,
          color: AppColors.danger,
          bg: AppColors.danger.withValues(alpha: 0.08)),
      ]),
    );
  }

  Widget _buildBody() {
    if (_loading) return _buildShimmer();

    if (_error != null) {
      return RefreshIndicator(
        onRefresh: _load,
        color: AppColors.primary,
        child: ListView(
          padding: const EdgeInsets.all(32),
          children: [
            Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.wifi_off_rounded, size: 48, color: Colors.red),
              const SizedBox(height: 14),
              Text(_error!, textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
              const SizedBox(height: 16),
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
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async { _loadPending(); await _load(); },
      color: AppColors.primary,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          // Pending approvals banner — scrolls with the list
          if (_isManager && (_pendingLoading || _filteredPending.isNotEmpty))
            _buildPendingBanner(),

          // Summary row
          _buildSummary(),

          // Empty state
          if (_rows.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(20)),
                  child: const Icon(Icons.tune_rounded,
                    size: 36, color: AppColors.primary)),
                const SizedBox(height: 14),
                Text('No adjustments found',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16, fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                Text('Try a different filter or time range',
                  style: GoogleFonts.inter(
                    fontSize: 13, color: AppColors.textMuted)),
              ]),
            ),

          // Adjustment cards
          ...(_rows.map((r) => Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: _AdjustmentCard(
              data: r,
              fmtDate: _fmtDate,
              showBranch: _isManager && _branchId == null,
            ),
          ))),
        ],
      ),
    );
  }

  Widget _buildShimmer() => ListView.builder(
    padding: const EdgeInsets.all(16),
    itemCount: 6,
    itemBuilder: (_, __) => Container(
      margin: const EdgeInsets.only(bottom: 10),
      height: 120,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16)),
    ),
  );
}

// ── Pending approval item ─────────────────────────────────────────────────────
class _PendingItem extends StatelessWidget {
  final PendingAdjustment item;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  const _PendingItem({required this.item, required this.onApprove, required this.onReject});

  String _fmtAgo(String raw) {
    try {
      final dt = DateTime.parse(raw).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) { return ''; }
  }

  @override
  Widget build(BuildContext context) {
    final isAdd      = item.isAddition;
    final qty        = item.qty;
    final curQty     = item.currentQty;
    final unit       = item.unit;
    final product    = item.productName;
    final requester  = item.requestedBy;
    final branchName = item.branchName;
    final note       = item.note;
    final ago        = _fmtAgo(item.createdAt);
    final qtyColor   = isAdd ? AppColors.success : AppColors.danger;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFDE68A), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
            blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Top: branch + time ──────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
          decoration: const BoxDecoration(
            color: Color(0xFFFFFBEB),
            borderRadius: BorderRadius.vertical(top: Radius.circular(17)),
          ),
          child: Row(children: [
            Icon(Icons.storefront_rounded, size: 13, color: const Color(0xFFF59E0B)),
            const SizedBox(width: 5),
            Expanded(
              child: Text(branchName,
                style: GoogleFonts.inter(
                  fontSize: 11, fontWeight: FontWeight.w800,
                  color: const Color(0xFF92400E)),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            if (ago.isNotEmpty)
              Text(ago, style: GoogleFonts.inter(
                fontSize: 10, color: const Color(0xFFB45309))),
          ]),
        ),

        // ── Content ─────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Qty badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: qtyColor.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: qtyColor.withValues(alpha: 0.25))),
                child: Text(
                  '${isAdd ? '+' : '-'}${qty % 1 == 0 ? qty.toInt() : qty}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18, fontWeight: FontWeight.w900, color: qtyColor,
                    letterSpacing: -0.4)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(product,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14, fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary, letterSpacing: -0.2),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(6)),
                      child: Text('Stock: ${curQty % 1 == 0 ? curQty.toInt() : curQty} $unit',
                        style: GoogleFonts.inter(
                          fontSize: 10, fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary)),
                    ),
                  ]),
                ]),
              ),
            ]),

            const SizedBox(height: 10),

            // Requester info
            Row(children: [
              Container(
                width: 26, height: 26,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8)),
                child: Center(
                  child: Text(
                    requester.isNotEmpty ? requester[0].toUpperCase() : '?',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11, fontWeight: FontWeight.w900,
                      color: AppColors.primary))),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(requester,
                    style: GoogleFonts.inter(
                      fontSize: 12, fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text('Cashier · Adjustment Request',
                    style: GoogleFonts.inter(
                      fontSize: 10, color: AppColors.textMuted)),
                ]),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: (isAdd ? AppColors.success : AppColors.danger).withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: (isAdd ? AppColors.success : AppColors.danger).withValues(alpha: 0.2))),
                child: Text(isAdd ? 'Addition' : 'Deduction',
                  style: GoogleFonts.inter(
                    fontSize: 9, fontWeight: FontWeight.w800,
                    color: isAdd ? AppColors.success : AppColors.danger,
                    letterSpacing: 0.2)),
              ),
            ]),

            if (note.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE5E7EB))),
                child: Row(children: [
                  const Icon(Icons.notes_rounded, size: 12, color: Color(0xFF9CA3AF)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(note,
                      style: GoogleFonts.inter(
                        fontSize: 11, color: AppColors.textSecondary,
                        fontStyle: FontStyle.italic),
                      maxLines: 2, overflow: TextOverflow.ellipsis)),
                ]),
              ),
            ],

            const SizedBox(height: 12),

            // Action buttons
            Row(children: [
              Expanded(
                flex: 2,
                child: GestureDetector(
                  onTap: onApprove,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF16A34A), Color(0xFF15803D)],
                        begin: Alignment.topLeft, end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(
                        color: AppColors.success.withValues(alpha: 0.3),
                        blurRadius: 8, offset: const Offset(0, 3))]),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.check_circle_rounded, size: 15, color: Colors.white),
                      const SizedBox(width: 6),
                      Text('Approve',
                        style: GoogleFonts.inter(
                          fontSize: 13, fontWeight: FontWeight.w800,
                          color: Colors.white)),
                    ]),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: onReject,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.danger.withValues(alpha: 0.4))),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.cancel_rounded, size: 15, color: AppColors.danger),
                      const SizedBox(width: 5),
                      Text('Reject',
                        style: GoogleFonts.inter(
                          fontSize: 13, fontWeight: FontWeight.w800,
                          color: AppColors.danger)),
                    ]),
                  ),
                ),
              ),
            ]),
          ]),
        ),
      ]),
    );
  }
}

// ── Branch chip ───────────────────────────────────────────────────────────────
class _BranchChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _BranchChip({
    required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.only(right: 8, bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: selected
            ? AppColors.accent
            : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected
              ? AppColors.accent
              : const Color(0xFFE5E7EB)),
      ),
      child: Text(label,
        style: GoogleFonts.inter(
          fontSize: 12, fontWeight: FontWeight.w700,
          color: selected ? Colors.white : AppColors.textSecondary)),
    ),
  );
}

// ── Summary tile ──────────────────────────────────────────────────────────────
class _SummaryTile extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color, bg;
  const _SummaryTile({
    required this.label, required this.value,
    required this.icon, required this.color, required this.bg});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: bg, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15, fontWeight: FontWeight.w900,
              color: color, letterSpacing: -0.3)),
          Text(label,
            style: GoogleFonts.inter(
              fontSize: 10, fontWeight: FontWeight.w700,
              color: color.withValues(alpha: 0.65))),
        ]),
      ]),
    ),
  );
}

// ── Adjustment card ───────────────────────────────────────────────────────────
class _AdjustmentCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String Function(String?) fmtDate;
  final bool showBranch;
  const _AdjustmentCard({
    required this.data,
    required this.fmtDate,
    this.showBranch = false,
  });

  @override
  Widget build(BuildContext context) {
    final beforeQty = (data['before_qty'] as num).toDouble();
    final afterQty  = (data['after_qty']  as num).toDouble();
    final qty       = (data['qty'] as num).toDouble();
    final isAdd     = afterQty >= beforeQty;
    final qtyColor  = isAdd ? AppColors.success : AppColors.danger;
    final note      = data['note'] as String? ?? '';
    final unit      = data['unit']  as String? ?? 'pcs';

    // note is stored as "Reason" or "Reason — extra notes"
    final dashIdx   = note.indexOf(' — ');
    final reason    = dashIdx > 0 ? note.substring(0, dashIdx) : note;
    final extraNote = dashIdx > 0 ? note.substring(dashIdx + 4) : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Top row ───────────────────────────────────────────────────
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Qty change badge
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: qtyColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: qtyColor.withValues(alpha: 0.25)),
              ),
              child: Text(
                '${isAdd ? '+' : '-'}${Fmt.qty(qty.abs())}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18, fontWeight: FontWeight.w900,
                  color: qtyColor, letterSpacing: -0.4)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(data['product_name'] as String? ?? 'Unknown',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14, fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.2),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  // Before → After
                  Row(children: [
                    _QtyPill('${Fmt.qty(beforeQty)} $unit',
                      AppColors.textMuted,
                      const Color(0xFFF3F4F6)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(Icons.arrow_forward_rounded,
                        size: 12, color: AppColors.textMuted)),
                    _QtyPill('${Fmt.qty(afterQty)} $unit',
                      qtyColor,
                      qtyColor.withValues(alpha: 0.10)),
                  ]),
                ],
              ),
            ),
          ]),

          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFEEEEEE)),
          const SizedBox(height: 10),

          // ── Meta row ─────────────────────────────────────────────────
          Wrap(spacing: 8, runSpacing: 6, children: [
            if (reason.isNotEmpty)
              _MetaChip(
                icon: Icons.label_outline_rounded,
                label: reason,
                color: AppColors.primary),
            _MetaChip(
              icon: Icons.person_outline_rounded,
              label: data['adjusted_by'] as String? ?? 'System',
              color: AppColors.textSecondary),
            if (showBranch)
              _MetaChip(
                icon: Icons.store_outlined,
                label: data['branch_name'] as String? ?? '—',
                color: AppColors.textSecondary),
            _MetaChip(
              icon: Icons.schedule_rounded,
              label: fmtDate(data['created_at'] as String?),
              color: AppColors.textMuted),
          ]),

          // Extra notes
          if (extraNote.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Text(extraNote,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontStyle: FontStyle.italic)),
            ),
          ],
        ]),
      ),
    );
  }
}

class _QtyPill extends StatelessWidget {
  final String text;
  final Color color, bg;
  const _QtyPill(this.text, this.color, this.bg);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: bg, borderRadius: BorderRadius.circular(6)),
    child: Text(text,
      style: GoogleFonts.inter(
        fontSize: 11, fontWeight: FontWeight.w700, color: color)),
  );
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _MetaChip({
    required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: color.withValues(alpha: 0.7)),
      const SizedBox(width: 4),
      Text(label,
        style: GoogleFonts.inter(
          fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    ]);
}
