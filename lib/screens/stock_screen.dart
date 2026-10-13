import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/pin_service.dart';
import '../theme/app_theme.dart';
import '../utils/animations.dart';
import '../utils/formatter.dart';
import '../widgets/common_widgets.dart';

class StockScreen extends StatefulWidget {
  final bool lowStockOnly;
  final ValueNotifier<int>? tabNotifier;
  const StockScreen({super.key, this.lowStockOnly = false, this.tabNotifier});

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen>
    with TickerProviderStateMixin {
  final _searchCtrl = TextEditingController();
  late TabController _tabs;
  List<StockItem> _all = [];
  List<StockItem> _filtered = [];
  bool _loading = true;
  bool _searching = false;
  late AnimationController _listCtrl;
  AuthUser? _user;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
      length: 2, vsync: this, initialIndex: widget.lowStockOnly ? 1 : 0);
    _listCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900));
    widget.tabNotifier?.addListener(_onTabVisible);
    _loadUser();
    _load();
  }

  void _onTabVisible() {
    final idx = widget.tabNotifier?.value;
    if (idx == 3 || idx == 1) _load();
  }

  @override
  void dispose() {
    widget.tabNotifier?.removeListener(_onTabVisible);
    _searchCtrl.dispose();
    _tabs.dispose();
    _listCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final u = await ApiService.getCachedUser();
    if (mounted) setState(() => _user = u);
  }

  // All authenticated users can adjust stock and add products
  bool get _canAdjust => true;

  Future<void> _load() async {
    setState(() => _loading = true);
    final items = await ApiService.getStock();
    if (!mounted) return;
    setState(() {
      _all      = items;
      _filtered = items;
      _loading  = false;
    });
    _listCtrl.forward(from: 0);
  }

  void _onSearch(String q) {
    setState(() {
      _filtered = q.trim().isEmpty
          ? _all
          : _all.where((p) =>
              p.name.toLowerCase().contains(q.toLowerCase()) ||
              p.sku.toLowerCase().contains(q.toLowerCase())).toList();
    });
  }

  List<StockItem> get _lowStock =>
      _filtered.where((p) => p.isLowStock || p.isOutOfStock).toList();

  int get _outCount  => _all.where((p) => p.isOutOfStock).length;
  int get _lowCount  => _all.where((p) => p.isLowStock && !p.isOutOfStock).length;
  int get _goodCount => _all.length - _outCount - _lowCount;

  // ── Add-product sheet ────────────────────────────────────────────────────
  void _openAddProduct() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddProductSheet(
        onSaved: () {
          _load();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Product added!',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600, color: Colors.white)),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddProduct,
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.add_rounded, size: 22),
        label: Text('Add Product',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13, fontWeight: FontWeight.w800)),
      ),
      body: Column(children: [
        // ── Premium header ────────────────────────────────────────────────
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0C2518), AppColors.primary, Color(0xFF1A4A2E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
          ),
          child: Column(children: [
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: Row(children: [
                  // Icon badge
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.18)),
                    ),
                    child: const Icon(Icons.inventory_2_rounded,
                      color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Products',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -0.5)),
                        Text('Manage inventory & stock levels',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.5))),
                      ],
                    ),
                  ),
                  // Search toggle
                  GestureDetector(
                    onTap: () {
                      setState(() => _searching = !_searching);
                      if (!_searching) {
                        _searchCtrl.clear();
                        _onSearch('');
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: _searching
                            ? AppColors.accent.withValues(alpha: 0.3)
                            : Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _searching
                              ? AppColors.accent.withValues(alpha: 0.5)
                              : Colors.white.withValues(alpha: 0.15)),
                      ),
                      child: Icon(
                        _searching ? Icons.close_rounded : Icons.search_rounded,
                        color: Colors.white, size: 20),
                    ),
                  ),
                ]),
              ),
            ),

            // ── Stats strip ─────────────────────────────────────────────
            if (!_loading)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(children: [
                  _StatTile(
                    value: '${_all.length}',
                    label: 'Total',
                    icon: Icons.apps_rounded,
                    color: Colors.white,
                    bg: Colors.white.withValues(alpha: 0.12),
                  ),
                  const SizedBox(width: 8),
                  _StatTile(
                    value: '$_goodCount',
                    label: 'In Stock',
                    icon: Icons.check_circle_outline_rounded,
                    color: const Color(0xFF86EFAC),
                    bg: const Color(0xFF16A34A).withValues(alpha: 0.18),
                  ),
                  const SizedBox(width: 8),
                  _StatTile(
                    value: '$_lowCount',
                    label: 'Low',
                    icon: Icons.warning_amber_rounded,
                    color: AppColors.accentLight,
                    bg: AppColors.warning.withValues(alpha: 0.18),
                  ),
                  const SizedBox(width: 8),
                  _StatTile(
                    value: '$_outCount',
                    label: 'Out',
                    icon: Icons.remove_circle_outline_rounded,
                    color: const Color(0xFFFF8A80),
                    bg: Colors.red.withValues(alpha: 0.18),
                  ),
                ]),
              ),

            // ── Search field ────────────────────────────────────────────
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              child: _searching
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: TextField(
                        controller: _searchCtrl,
                        autofocus: true,
                        onChanged: _onSearch,
                        style: GoogleFonts.inter(
                          color: Colors.white, fontSize: 14,
                          fontWeight: FontWeight.w500),
                        decoration: InputDecoration(
                          hintText: 'Search products, SKU…',
                          hintStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4)),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.1),
                          prefixIcon: Icon(Icons.search_rounded,
                            color: Colors.white.withValues(alpha: 0.5),
                            size: 18),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: Colors.white.withValues(alpha: 0.3))),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 11),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),

            const SizedBox(height: 14),

            // ── Tab bar ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: TabBar(
                  controller: _tabs,
                  indicator: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.30),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.5)),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicatorPadding: const EdgeInsets.all(3),
                  dividerColor: Colors.transparent,
                  labelStyle: GoogleFonts.plusJakartaSans(
                    fontSize: 12, fontWeight: FontWeight.w800),
                  unselectedLabelStyle: GoogleFonts.inter(
                    fontSize: 12, fontWeight: FontWeight.w600),
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white60,
                  tabs: [
                    Tab(text: 'All Products (${_filtered.length})'),
                    Tab(text: 'Alerts (${_lowStock.length})'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ]),
        ),

        // ── Content ───────────────────────────────────────────────────────
        Expanded(
          child: _loading
              ? _buildShimmer()
              : TabBarView(
                  controller: _tabs,
                  children: [
                    _StockList(
                      items: _filtered,
                      listCtrl: _listCtrl,
                      emptyMsg: 'No products yet',
                      emptySubtitle: 'Tap "+ Add Product" to add your first product',
                      canAdjust: _canAdjust,
                      onAdjust: _showAdjustSheet),
                    _StockList(
                      items: _lowStock,
                      listCtrl: _listCtrl,
                      emptyMsg: 'All stocked up!',
                      emptySubtitle: 'No low stock or out-of-stock items',
                      emptyIcon: Icons.check_circle_outline_rounded,
                      canAdjust: _canAdjust,
                      onAdjust: _showAdjustSheet),
                  ],
                ),
        ),
      ]),
    );
  }

  void _showAdjustSheet(StockItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AdjustSheet(
        item: item,
        onSaved: (newQty) {
          setState(() {
            _all = _all.map((s) => s.id == item.id
                ? StockItem(
                    id: s.id, name: s.name, sku: s.sku, unit: s.unit,
                    qty: newQty, reorderLevel: s.reorderLevel,
                    buyingPrice: s.buyingPrice, sellingPrice: s.sellingPrice,
                    categoryName: s.categoryName)
                : s).toList();
            _onSearch(_searchCtrl.text);
          });
        },
      ),
    );
  }

  Widget _buildShimmer() => ListView.builder(
    padding: const EdgeInsets.all(16),
    itemCount: 8,
    itemBuilder: (_, __) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ShimmerBox(width: double.infinity, height: 110, radius: 18),
    ),
  );
}

// ── Stat tile ─────────────────────────────────────────────────────────────────
class _StatTile extends StatelessWidget {
  final String value, label;
  final IconData icon;
  final Color color, bg;
  const _StatTile({
    required this.value, required this.label,
    required this.icon, required this.color, required this.bg});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: bg, borderRadius: BorderRadius.circular(13)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 13, color: color.withValues(alpha: 0.8)),
          const SizedBox(height: 4),
          Text(value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16, fontWeight: FontWeight.w900,
              color: color, letterSpacing: -0.4)),
          Text(label,
            style: GoogleFonts.inter(
              fontSize: 9, fontWeight: FontWeight.w700,
              color: color.withValues(alpha: 0.65))),
        ],
      ),
    ),
  );
}

// ── Stock list ─────────────────────────────────────────────────────────────────
class _StockList extends StatelessWidget {
  final List<StockItem> items;
  final AnimationController listCtrl;
  final String emptyMsg, emptySubtitle;
  final IconData emptyIcon;
  final bool canAdjust;
  final void Function(StockItem)? onAdjust;

  const _StockList({
    required this.items,
    required this.listCtrl,
    required this.emptyMsg,
    required this.emptySubtitle,
    this.emptyIcon = Icons.inventory_2_outlined,
    this.canAdjust = false,
    this.onAdjust,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return EmptyState(
        title: emptyMsg, subtitle: emptySubtitle, icon: emptyIcon);
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: items.length,
      itemBuilder: (_, i) => StaggeredItem(
        index: i,
        controller: listCtrl,
        child: _StockCard(
          item: items[i],
          onAdjust: canAdjust ? () => onAdjust?.call(items[i]) : null,
        ),
      ),
    );
  }
}

// ── Premium stock card ────────────────────────────────────────────────────────
class _StockCard extends StatelessWidget {
  final StockItem item;
  final VoidCallback? onAdjust;
  const _StockCard({required this.item, this.onAdjust});

  @override
  Widget build(BuildContext context) {
    final isOut = item.isOutOfStock;
    final isLow = item.isLowStock && !isOut;
    final pct   = item.reorderLevel > 0
        ? (item.qty / (item.reorderLevel * 2)).clamp(0.0, 1.0)
        : (item.qty > 0 ? 1.0 : 0.0);

    final barColor = isOut
        ? AppColors.danger
        : isLow ? AppColors.warning : AppColors.success;
    final accent   = isOut
        ? AppColors.danger
        : isLow ? AppColors.warning : AppColors.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isOut
              ? AppColors.danger.withValues(alpha: 0.3)
              : isLow
                  ? AppColors.warning.withValues(alpha: 0.3)
                  : AppColors.border),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: isOut || isLow ? 0.08 : 0.04),
            blurRadius: 12, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(children: [
        // ── Top row ──────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Status icon circle
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    barColor.withValues(alpha: 0.22),
                    barColor.withValues(alpha: 0.10),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                isOut
                    ? Icons.remove_circle_outline_rounded
                    : isLow
                        ? Icons.warning_amber_rounded
                        : Icons.check_circle_outline_rounded,
                color: barColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.2),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Row(children: [
                    if (item.sku.isNotEmpty) ...[
                      _Chip(item.sku, AppColors.primary.withValues(alpha: 0.08),
                            AppColors.primary.withValues(alpha: 0.7)),
                      const SizedBox(width: 5),
                    ],
                    Flexible(
                      child: _Chip(
                        item.categoryName,
                        AppColors.bg,
                        AppColors.textMuted),
                    ),
                  ]),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Quantity block
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(Fmt.num(item.qty),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 22, fontWeight: FontWeight.w900,
                      color: barColor, letterSpacing: -0.6)),
                  const SizedBox(width: 3),
                  Text(item.unit,
                    style: GoogleFonts.inter(
                      fontSize: 11, fontWeight: FontWeight.w700,
                      color: barColor.withValues(alpha: 0.6))),
                ],
              ),
              if (isOut)
                _Badge('Out of Stock', AppColors.danger, const Color(0xFFFFEDED))
              else if (isLow)
                _Badge('Low Stock', AppColors.warning, const Color(0xFFFFF8ED)),
            ]),
          ]),
        ),

        // ── Progress bar ─────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
          child: _AnimatedBar(value: pct, color: barColor),
        ),

        // ── Footer row ────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
          child: Row(children: [
            Icon(Icons.refresh_rounded, size: 11, color: AppColors.textMuted),
            const SizedBox(width: 4),
            Text('Reorder @ ${Fmt.num(item.reorderLevel)} ${item.unit}',
              style: GoogleFonts.inter(
                fontSize: 11, fontWeight: FontWeight.w600,
                color: AppColors.textMuted)),
            const Spacer(),
            Text(Fmt.money(item.sellingPrice),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13, fontWeight: FontWeight.w900,
                color: AppColors.primary)),
          ]),
        ),

        // ── Adjust button ─────────────────────────────────────────────────
        if (onAdjust != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: GestureDetector(
              onTap: onAdjust,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.07),
                      AppColors.primaryMid.withValues(alpha: 0.04),
                    ]),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.15)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.tune_rounded, color: AppColors.primary, size: 14),
                    const SizedBox(width: 6),
                    Text('Adjust Stock',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12, fontWeight: FontWeight.w800,
                        color: AppColors.primary)),
                  ],
                ),
              ),
            ),
          )
        else
          const SizedBox(height: 14),
      ]),
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  final Color bg, fg;
  const _Chip(this.text, this.bg, this.fg);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: bg, borderRadius: BorderRadius.circular(6)),
    child: Text(text,
      style: GoogleFonts.inter(
        fontSize: 10, fontWeight: FontWeight.w700, color: fg),
      maxLines: 1, overflow: TextOverflow.ellipsis),
  );
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color, bg;
  const _Badge(this.label, this.color, this.bg);

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 3),
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: bg, borderRadius: BorderRadius.circular(20)),
    child: Text(label,
      style: GoogleFonts.inter(
        fontSize: 9, fontWeight: FontWeight.w800, color: color)),
  );
}

class _AnimatedBar extends StatefulWidget {
  final double value;
  final Color color;
  const _AnimatedBar({required this.value, required this.color});

  @override
  State<_AnimatedBar> createState() => _AnimatedBarState();
}

class _AnimatedBarState extends State<_AnimatedBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900));
    _anim = Tween<double>(begin: 0, end: widget.value)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    Future.delayed(const Duration(milliseconds: 80), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _anim,
    builder: (_, __) => ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Stack(children: [
        Container(
          height: 5,
          decoration: BoxDecoration(
            color: AppColors.borderLight,
            borderRadius: BorderRadius.circular(8))),
        FractionallySizedBox(
          widthFactor: _anim.value,
          child: Container(
            height: 5,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  widget.color.withValues(alpha: 0.7),
                  widget.color,
                ]),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: widget.color.withValues(alpha: 0.35),
                  blurRadius: 4, offset: const Offset(0, 1)),
              ]),
          ),
        ),
      ]),
    ),
  );
}

// ── Product draft model ───────────────────────────────────────────────────────
class _ProductDraft {
  final TextEditingController name    = TextEditingController();
  final TextEditingController sku     = TextEditingController();
  final TextEditingController buy     = TextEditingController();
  final TextEditingController sell    = TextEditingController();
  final TextEditingController qty     = TextEditingController();
  final TextEditingController reorder = TextEditingController();
  String unit     = 'pcs';
  int?   categoryId;
  bool   expanded = true;

  void dispose() {
    name.dispose(); sku.dispose(); buy.dispose();
    sell.dispose(); qty.dispose(); reorder.dispose();
  }

  String get summaryName => name.text.trim().isEmpty ? 'Unnamed product' : name.text.trim();
  String get summarySell => sell.text.trim().isEmpty ? '—' : 'TZS ${sell.text.trim()}';
  String get summaryQty  => qty.text.trim().isEmpty ? '0' : qty.text.trim();
}

// ── Add Product Sheet (single + bulk) ─────────────────────────────────────────
class _AddProductSheet extends StatefulWidget {
  final VoidCallback onSaved;
  const _AddProductSheet({required this.onSaved});

  @override
  State<_AddProductSheet> createState() => _AddProductSheetState();
}

class _AddProductSheetState extends State<_AddProductSheet> {
  final List<_ProductDraft> _drafts = [_ProductDraft()];
  List<Map<String, dynamic>> _categories = [];
  bool    _saving  = false;
  bool    _loading = true;
  String? _error;

  static const _units = ['pcs', 'kg', 'g', 'ltr', 'ml', 'box', 'carton',
                          'dozen', 'pair', 'roll', 'bag', 'packet'];

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    for (final d in _drafts) d.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    final cats = await ApiService.getCategories();
    if (mounted) setState(() { _categories = cats; _loading = false; });
  }

  void _addDraft() {
    setState(() {
      for (final d in _drafts) d.expanded = false;
      _drafts.add(_ProductDraft());
    });
    HapticFeedback.selectionClick();
  }

  void _removeDraft(int i) {
    if (_drafts.length == 1) return;
    setState(() { _drafts[i].dispose(); _drafts.removeAt(i); });
  }

  bool _validateAll() {
    for (int i = 0; i < _drafts.length; i++) {
      final d = _drafts[i];
      if (d.name.text.trim().isEmpty) {
        setState(() { _error = 'Product ${i+1}: name is required'; d.expanded = true; });
        return false;
      }
      if ((double.tryParse(d.sell.text.trim()) ?? 0) <= 0) {
        setState(() { _error = 'Product ${i+1} (${d.summaryName}): enter selling price'; d.expanded = true; });
        return false;
      }
    }
    return true;
  }

  Future<bool> _confirmPin() async {
    final hasPin = await PinService.hasPin();
    if (!hasPin) return true;
    if (!mounted) return false;
    final r = await showModalBottomSheet<bool>(
      context: context, isScrollControlled: true,
      backgroundColor: Colors.transparent, isDismissible: true,
      builder: (_) => const _PinConfirmSheet());
    return r == true;
  }

  Future<void> _save() async {
    setState(() => _error = null);
    if (!_validateAll()) return;
    HapticFeedback.mediumImpact();
    final pinOk = await _confirmPin();
    if (!pinOk || !mounted) return;
    setState(() => _saving = true);
    try {
      final products = _drafts.map((d) => <String, dynamic>{
        'name':          d.name.text.trim(),
        'sku':           d.sku.text.trim(),
        'unit':          d.unit,
        'category_id':   d.categoryId?.toString() ?? '',
        'buying_price':  double.tryParse(d.buy.text.trim())    ?? 0,
        'selling_price': double.tryParse(d.sell.text.trim())   ?? 0,
        'qty':           double.tryParse(d.qty.text.trim())    ?? 0,
        'reorder_level': double.tryParse(d.reorder.text.trim()) ?? 0,
      }).toList();

      Map<String, dynamic> res;
      if (products.length == 1) {
        final p = products.first;
        res = await ApiService.addProduct(
          name:         p['name'] as String,
          sku:          p['sku']  as String,
          unit:         p['unit'] as String,
          categoryId:   (p['category_id'] as String).isEmpty
                            ? null : int.tryParse(p['category_id'] as String),
          buyingPrice:  (p['buying_price']  as num).toDouble(),
          sellingPrice: (p['selling_price'] as num).toDouble(),
          qty:          (p['qty']           as num).toDouble(),
          reorderLevel: (p['reorder_level'] as num).toDouble(),
        );
      } else {
        res = await ApiService.bulkAddProducts(products);
      }

      if (!mounted) return;
      if (res['ok'] == true) {
        HapticFeedback.heavyImpact();
        Navigator.pop(context);
        widget.onSaved();
      } else {
        setState(() { _saving = false; _error = res['error'] ?? 'Failed to save'; });
      }
    } catch (_) {
      if (mounted) setState(() { _saving = false; _error = 'Network error — check connection'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = _drafts.length;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // ── Header ──────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, Color(0xFF1A4A2E)]),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              boxShadow: [BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.25),
                blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: Row(children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(11)),
                child: const Icon(Icons.add_box_rounded, color: Colors.white, size: 20)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text('Add Products',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16, fontWeight: FontWeight.w900,
                        color: Colors.white, letterSpacing: -0.3)),
                    if (count > 1) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.accent.withValues(alpha: 0.5))),
                        child: Text('$count',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11, fontWeight: FontWeight.w900,
                            color: Colors.white))),
                    ],
                  ]),
                  Text('Fill details · tap + to add more',
                    style: GoogleFonts.inter(
                      fontSize: 11, color: Colors.white.withValues(alpha: 0.6))),
                ])),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.close_rounded, color: Colors.white, size: 18))),
            ]),
          ),

          if (_loading)
            const Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(color: AppColors.primary)),

          if (!_loading)
            Flexible(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                itemCount: count + 1,
                itemBuilder: (_, idx) {
                  if (idx == count) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: GestureDetector(
                        onTap: _addDraft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.18))),
                          child: Row(mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 24, height: 24,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.1),
                                  shape: BoxShape.circle),
                                child: const Icon(Icons.add_rounded,
                                  color: AppColors.primary, size: 16)),
                              const SizedBox(width: 8),
                              Text('Add Another Product',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13, fontWeight: FontWeight.w800,
                                  color: AppColors.primary)),
                            ]),
                        ),
                      ),
                    );
                  }
                  return _DraftCard(
                    key: ValueKey(idx),
                    draft: _drafts[idx], index: idx, total: count,
                    categories: _categories, units: _units,
                    onRemove: () => _removeDraft(idx),
                    onToggle: () => setState(() =>
                      _drafts[idx].expanded = !_drafts[idx].expanded),
                  );
                },
              ),
            ),

          if (_error != null)
            Container(
              margin: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.dangerBg, borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.danger.withValues(alpha: 0.3))),
              child: Row(children: [
                const Icon(Icons.error_outline_rounded, size: 16, color: AppColors.danger),
                const SizedBox(width: 8),
                Expanded(child: Text(_error!,
                  style: GoogleFonts.inter(
                    fontSize: 13, fontWeight: FontWeight.w600,
                    color: AppColors.danger))),
              ])),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            child: GestureDetector(
              onTap: _saving ? null : _save,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: double.infinity, height: 54,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _saving
                        ? [AppColors.primary.withValues(alpha: 0.5),
                           AppColors.primaryMid.withValues(alpha: 0.5)]
                        : [AppColors.primary, AppColors.primaryMid]),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: _saving ? [] : [BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 14, offset: const Offset(0, 5))]),
                child: Center(
                  child: _saving
                      ? const SizedBox(width: 22, height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white))
                      : Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.lock_rounded, color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                          Text(count == 1 ? 'Save Product' : 'Save $count Products',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15, fontWeight: FontWeight.w900,
                              color: Colors.white, letterSpacing: -0.3)),
                        ])),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Draft card (collapsible row in bulk form) ─────────────────────────────────
class _DraftCard extends StatelessWidget {
  final _ProductDraft draft;
  final int index, total;
  final List<Map<String, dynamic>> categories;
  final List<String> units;
  final VoidCallback onRemove, onToggle;

  const _DraftCard({
    super.key, required this.draft, required this.index, required this.total,
    required this.categories, required this.units,
    required this.onRemove, required this.onToggle,
  });

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    decoration: BoxDecoration(
      color: AppColors.surface, borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
      boxShadow: [BoxShadow(
        color: AppColors.primary.withValues(alpha: 0.04),
        blurRadius: 8, offset: const Offset(0, 2))]),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      GestureDetector(
        onTap: onToggle,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          decoration: BoxDecoration(
            color: draft.expanded
                ? AppColors.primary.withValues(alpha: 0.04) : Colors.transparent,
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(16),
              bottom: draft.expanded ? Radius.zero : const Radius.circular(16))),
          child: Row(children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8)),
              child: Center(child: Text('${index + 1}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12, fontWeight: FontWeight.w900,
                  color: AppColors.primary)))),
            const SizedBox(width: 10),
            Expanded(
              child: draft.expanded
                  ? Text('Product ${index + 1}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13, fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary))
                  : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(draft.summaryName,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13, fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text('${draft.summarySell} · ${draft.summaryQty} ${draft.unit}',
                        style: GoogleFonts.inter(
                          fontSize: 11, color: AppColors.textMuted,
                          fontWeight: FontWeight.w500)),
                    ])),
            Icon(draft.expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
              size: 20, color: AppColors.textMuted),
            if (total > 1) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onRemove,
                child: Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.delete_outline_rounded,
                    size: 15, color: AppColors.danger))),
            ],
          ]),
        ),
      ),
      AnimatedSize(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        child: draft.expanded
            ? _DraftForm(draft: draft, categories: categories, units: units)
            : const SizedBox.shrink()),
    ]),
  );
}

// ── Draft form fields ─────────────────────────────────────────────────────────
class _DraftForm extends StatefulWidget {
  final _ProductDraft draft;
  final List<Map<String, dynamic>> categories;
  final List<String> units;
  const _DraftForm({required this.draft, required this.categories, required this.units});
  @override State<_DraftForm> createState() => _DraftFormState();
}

class _DraftFormState extends State<_DraftForm> {
  @override
  Widget build(BuildContext context) {
    final d = widget.draft;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _FLabel('Name *'), const SizedBox(height: 5),
        _FField(controller: d.name, hint: 'e.g. Cement 50kg',
          icon: Icons.inventory_2_rounded,
          textCapitalization: TextCapitalization.words),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(flex: 3, child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FLabel('SKU'), const SizedBox(height: 5),
              _FField(controller: d.sku, hint: 'Optional',
                icon: Icons.qr_code_rounded),
            ])),
          const SizedBox(width: 10),
          Expanded(flex: 2, child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FLabel('Unit'), const SizedBox(height: 5),
              _UnitPicker(value: d.unit, units: widget.units,
                onChanged: (v) { if (v != null) setState(() => d.unit = v); }),
            ])),
        ]),
        const SizedBox(height: 12),
        _FLabel('Category'), const SizedBox(height: 5),
        _CategoryPicker(categories: widget.categories, value: d.categoryId,
          onChanged: (v) => setState(() => d.categoryId = v)),
        const SizedBox(height: 12),
        _FLabel('Prices (TZS)'), const SizedBox(height: 5),
        Row(children: [
          Expanded(child: _FField(controller: d.buy, hint: 'Buying',
            icon: Icons.arrow_downward_rounded,
            keyboardType: TextInputType.number, prefix: 'Buy  ')),
          const SizedBox(width: 8),
          Expanded(child: _FField(controller: d.sell, hint: 'Selling *',
            icon: Icons.arrow_upward_rounded,
            keyboardType: TextInputType.number, prefix: 'Sell ')),
        ]),
        const SizedBox(height: 12),
        _FLabel('Opening Stock'), const SizedBox(height: 5),
        Row(children: [
          Expanded(child: _FField(controller: d.qty, hint: '0',
            icon: Icons.add_shopping_cart_rounded,
            keyboardType: TextInputType.number, prefix: 'Qty  ')),
          const SizedBox(width: 8),
          Expanded(child: _FField(controller: d.reorder, hint: '0',
            icon: Icons.notifications_active_rounded,
            keyboardType: TextInputType.number, prefix: 'Alert')),
        ]),
        const SizedBox(height: 5),
        Text('Alert level triggers Low Stock warning',
          style: GoogleFonts.inter(
            fontSize: 10, color: AppColors.textMuted,
            fontWeight: FontWeight.w500)),
      ]),
    );
  }
}

// ── Form helpers ──────────────────────────────────────────────────────────────
class _FLabel extends StatelessWidget {
  final String text;
  const _FLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
    style: GoogleFonts.plusJakartaSans(
      fontSize: 11.5, fontWeight: FontWeight.w800,
      color: AppColors.textMuted, letterSpacing: 0.3));
}

class _FField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final String? prefix;
  final TextCapitalization textCapitalization;

  const _FField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.prefix,
    this.textCapitalization = TextCapitalization.none,
  });

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: AppColors.bg,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.border)),
    child: Row(children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Icon(icon, size: 16, color: AppColors.primary.withValues(alpha: 0.7))),
      if (prefix != null)
        Text(prefix!,
          style: GoogleFonts.inter(
            fontSize: 11, fontWeight: FontWeight.w700,
            color: AppColors.textMuted)),
      Expanded(
        child: TextField(
          controller: controller,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          style: GoogleFonts.inter(
            fontSize: 14, fontWeight: FontWeight.w600,
            color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: AppColors.textMuted.withValues(alpha: 0.6),
              fontSize: 13),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              vertical: 13, horizontal: 4)),
        ),
      ),
    ]),
  );
}

class _UnitPicker extends StatelessWidget {
  final String value;
  final List<String> units;
  final ValueChanged<String?> onChanged;
  const _UnitPicker({required this.value, required this.units, required this.onChanged});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: AppColors.bg,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.border)),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: value,
        isExpanded: true,
        style: GoogleFonts.inter(
          fontSize: 13, fontWeight: FontWeight.w700,
          color: AppColors.textPrimary),
        icon: const Icon(Icons.expand_more_rounded,
          size: 18, color: AppColors.textMuted),
        items: units.map((u) => DropdownMenuItem(
          value: u,
          child: Text(u,
            style: GoogleFonts.inter(
              fontSize: 13, fontWeight: FontWeight.w600,
              color: AppColors.textPrimary)))).toList(),
        onChanged: onChanged,
      ),
    ),
  );
}

class _CategoryPicker extends StatelessWidget {
  final List<Map<String, dynamic>> categories;
  final int? value;
  final ValueChanged<int?> onChanged;
  const _CategoryPicker({required this.categories, required this.value,
                         required this.onChanged});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: AppColors.bg,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.border)),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<int?>(
        value: value,
        isExpanded: true,
        hint: Text('Select category',
          style: GoogleFonts.inter(
            fontSize: 13, color: AppColors.textMuted.withValues(alpha: 0.7))),
        style: GoogleFonts.inter(
          fontSize: 13, fontWeight: FontWeight.w700,
          color: AppColors.textPrimary),
        icon: const Icon(Icons.expand_more_rounded,
          size: 18, color: AppColors.textMuted),
        items: [
          DropdownMenuItem<int?>(
            value: null,
            child: Text('No category',
              style: GoogleFonts.inter(
                fontSize: 13, color: AppColors.textMuted))),
          ...categories.map((c) => DropdownMenuItem<int?>(
            value: c['id'] as int,
            child: Text(c['name'] as String,
              style: GoogleFonts.inter(
                fontSize: 13, fontWeight: FontWeight.w600,
                color: AppColors.textPrimary)))),
        ],
        onChanged: onChanged,
      ),
    ),
  );
}

// ── Adjust Stock Sheet (unchanged logic, minor style polish) ──────────────────
class _AdjustSheet extends StatefulWidget {
  final StockItem item;
  final void Function(double newQty) onSaved;
  const _AdjustSheet({required this.item, required this.onSaved});

  @override
  State<_AdjustSheet> createState() => _AdjustSheetState();
}

class _AdjustSheetState extends State<_AdjustSheet> {
  final _qtyCtrl   = TextEditingController();
  final _notesCtrl = TextEditingController();
  String  _type    = 'add';
  String  _reason  = 'Correction';
  bool    _saving  = false;
  String? _errorMsg;

  static const _reasons = [
    'Correction', 'Purchase', 'Return', 'Damage', 'Expired',
    'Theft/Loss', 'Initial Count', 'Other',
  ];

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  double get _qtyVal => double.tryParse(_qtyCtrl.text.trim()) ?? 0;

  double _computePreview(String text) {
    final q = double.tryParse(text.trim()) ?? 0;
    switch (_type) {
      case 'add':    return widget.item.qty + q;
      case 'remove': return (widget.item.qty - q).clamp(0, double.infinity);
      case 'set':    return q;
      default:       return widget.item.qty;
    }
  }

  Future<bool> _confirmWithPin() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      builder: (_) => const _PinConfirmSheet(),
    );
    return result == true;
  }

  Future<void> _save() async {
    final q = _qtyVal;
    if (_qtyCtrl.text.trim().isEmpty || (q <= 0 && _type != 'set')) {
      HapticFeedback.vibrate();
      setState(() => _errorMsg = 'Enter a valid quantity');
      return;
    }
    final hasPin = await PinService.hasPin();
    if (!mounted) return;
    if (hasPin) {
      final confirmed = await _confirmWithPin();
      if (!confirmed || !mounted) return;
    }
    setState(() { _saving = true; _errorMsg = null; });
    HapticFeedback.mediumImpact();
    try {
      final res = await ApiService.adjustStock(
        productId: widget.item.id,
        type: _type, qty: q,
        reason: _reason, notes: _notesCtrl.text.trim(),
      );
      if (!mounted) return;
      if (res['ok'] == true) {
        HapticFeedback.heavyImpact();
        final newQty = double.tryParse(res['new_qty']?.toString() ?? '') ??
            _computePreview(_qtyCtrl.text);
        widget.onSaved(newQty);
        Navigator.pop(context);
      } else {
        setState(() { _saving = false; _errorMsg = res['error']?.toString() ?? 'Adjustment failed'; });
      }
    } catch (e) {
      if (mounted) setState(() { _saving = false; _errorMsg = 'Network error'; });
    }
  }

  void _pickReason(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (ctx2, setS) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppColors.border, borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Text('Select Reason',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16, fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary))),
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: 16, right: 16,
                  bottom: MediaQuery.of(ctx2).padding.bottom + 20),
                child: Column(
                  children: _reasons.map((r) {
                    final sel = r == _reason;
                    return GestureDetector(
                      onTap: () { setState(() => _reason = r); Navigator.pop(ctx2); },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: sel
                              ? AppColors.primary.withValues(alpha: 0.08)
                              : AppColors.bg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: sel
                                ? AppColors.primary.withValues(alpha: 0.3)
                                : AppColors.border)),
                        child: Row(children: [
                          Icon(_reasonIcon(r), size: 18,
                            color: sel ? AppColors.primary : AppColors.textMuted),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(r,
                              style: GoogleFonts.inter(
                                fontSize: 14, fontWeight: FontWeight.w600,
                                color: sel ? AppColors.primary : AppColors.textPrimary))),
                          if (sel)
                            const Icon(Icons.check_circle_rounded,
                              size: 18, color: AppColors.primary),
                        ])),
                    );
                  }).toList()),
              )),
          ])),
      ));
  }

  IconData _reasonIcon(String r) {
    switch (r) {
      case 'Purchase':      return Icons.shopping_cart_rounded;
      case 'Return':        return Icons.assignment_return_rounded;
      case 'Damage':        return Icons.broken_image_rounded;
      case 'Expired':       return Icons.hourglass_disabled_rounded;
      case 'Theft/Loss':    return Icons.no_accounts_rounded;
      case 'Initial Count': return Icons.format_list_numbered_rounded;
      case 'Other':         return Icons.more_horiz_rounded;
      default:              return Icons.edit_note_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final item      = widget.item;
    final isOut     = item.isOutOfStock;
    final isLow     = item.isLowStock && !isOut;
    final statColor = isOut
        ? AppColors.danger : isLow ? AppColors.warning : AppColors.success;
    final typeColor = _type == 'add'
        ? AppColors.success : _type == 'remove' ? AppColors.danger : AppColors.accent;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: AppColors.border, borderRadius: BorderRadius.circular(2))),

          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.primaryMid],
                        begin: Alignment.topLeft, end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(16)),
                    child: Row(children: [
                      Container(
                        width: 46, height: 46,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(13)),
                        child: const Icon(Icons.inventory_2_rounded,
                          color: Colors.white, size: 22)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.name,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 15, fontWeight: FontWeight.w900,
                                color: Colors.white),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: statColor.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: statColor.withValues(alpha: 0.4))),
                              child: Text('${Fmt.num(item.qty)} ${item.unit}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12, fontWeight: FontWeight.w800,
                                  color: statColor))),
                          ])),
                    ])),

                  const SizedBox(height: 20),

                  _FLabel('Adjustment Type'),
                  const SizedBox(height: 8),
                  Row(children: [
                    _TypeBtn(label: 'Add',    icon: Icons.add_circle_outline_rounded,
                      color: AppColors.success, selected: _type == 'add',
                      onTap: () => setState(() => _type = 'add')),
                    const SizedBox(width: 8),
                    _TypeBtn(label: 'Remove', icon: Icons.remove_circle_outline_rounded,
                      color: AppColors.danger,  selected: _type == 'remove',
                      onTap: () => setState(() => _type = 'remove')),
                    const SizedBox(width: 8),
                    _TypeBtn(label: 'Set to', icon: Icons.edit_note_rounded,
                      color: AppColors.accent,  selected: _type == 'set',
                      onTap: () => setState(() => _type = 'set')),
                  ]),

                  const SizedBox(height: 18),
                  _FLabel('Quantity'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _qtyCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 20, fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: '0',
                      hintStyle: TextStyle(color: AppColors.textMuted),
                      suffixText: item.unit,
                      suffixStyle: GoogleFonts.inter(
                        fontSize: 14, fontWeight: FontWeight.w600,
                        color: AppColors.textMuted),
                      filled: true, fillColor: AppColors.bg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: AppColors.border)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: AppColors.border)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: typeColor, width: 2)),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16))),

                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _qtyCtrl,
                    builder: (_, val, __) {
                      if (val.text.trim().isEmpty) return const SizedBox.shrink();
                      final preview = _computePreview(val.text);
                      return Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: typeColor.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: typeColor.withValues(alpha: 0.2))),
                          child: Row(children: [
                            Icon(Icons.arrow_forward_rounded,
                              size: 14, color: typeColor),
                            const SizedBox(width: 8),
                            Text('New qty: ',
                              style: GoogleFonts.inter(
                                fontSize: 12, color: AppColors.textMuted,
                                fontWeight: FontWeight.w500)),
                            Text('${Fmt.num(preview)} ${item.unit}',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14, fontWeight: FontWeight.w900,
                                color: typeColor)),
                          ])));
                    }),

                  const SizedBox(height: 18),
                  _FLabel('Reason'),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => _pickReason(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.bg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border)),
                      child: Row(children: [
                        Icon(_reasonIcon(_reason), size: 18, color: AppColors.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(_reason,
                            style: GoogleFonts.inter(
                              fontSize: 14, fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary))),
                        const Icon(Icons.expand_more_rounded,
                          size: 20, color: AppColors.textMuted),
                      ]))),

                  const SizedBox(height: 18),
                  _FLabel('Notes (optional)'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _notesCtrl,
                    maxLines: 2,
                    style: GoogleFonts.inter(
                      fontSize: 14, color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Additional notes…',
                      hintStyle: TextStyle(color: AppColors.textMuted),
                      filled: true, fillColor: AppColors.bg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: AppColors.border)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: AppColors.border)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: AppColors.primary, width: 2)),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12))),
                ],
              ),
            ),
          ),

          if (_errorMsg != null)
            Container(
              margin: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.dangerBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.danger.withValues(alpha: 0.3))),
              child: Row(children: [
                const Icon(Icons.error_outline_rounded,
                  size: 16, color: AppColors.danger),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_errorMsg!,
                    style: GoogleFonts.inter(
                      fontSize: 13, fontWeight: FontWeight.w600,
                      color: AppColors.danger))),
              ])),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: GestureDetector(
              onTap: _saving ? null : _save,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: double.infinity, height: 54,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _saving
                        ? [AppColors.primary.withValues(alpha: 0.5),
                           AppColors.primaryMid.withValues(alpha: 0.5)]
                        : [AppColors.primary, AppColors.primaryMid]),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: _saving ? [] : [BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 12, offset: const Offset(0, 4))]),
                child: Center(
                  child: _saving
                      ? const SizedBox(
                          width: 22, height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white))
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_rounded,
                              color: Colors.white, size: 20),
                            const SizedBox(width: 8),
                            Text('Confirm Adjustment',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 15, fontWeight: FontWeight.w900,
                                color: Colors.white, letterSpacing: -0.3)),
                          ])),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── PIN Confirm Sheet (unchanged) ─────────────────────────────────────────────
class _PinConfirmSheet extends StatefulWidget {
  const _PinConfirmSheet();
  @override
  State<_PinConfirmSheet> createState() => _PinConfirmSheetState();
}

class _PinConfirmSheetState extends State<_PinConfirmSheet>
    with SingleTickerProviderStateMixin {
  String _pin = '';
  String? _error;
  int _attempts = 0;
  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 400));
    _shakeAnim = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -10.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -10.0, end: 10.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10.0, end: -6.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -6.0, end: 6.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 6.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _shakeCtrl.dispose(); super.dispose(); }

  void _onKey(String k) {
    if (_pin.length >= 4) return;
    setState(() { _pin += k; _error = null; });
    if (_pin.length == 4) _verify();
  }

  void _onDelete() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _verify() async {
    final ok = await PinService.verifyPin(_pin);
    if (!mounted) return;
    if (ok) {
      HapticFeedback.heavyImpact();
      Navigator.pop(context, true);
    } else {
      HapticFeedback.vibrate();
      _attempts++;
      setState(() {
        _pin   = '';
        _error = _attempts >= 3
            ? 'Wrong PIN ($_attempts attempts)'
            : 'Incorrect PIN — try again';
      });
      _shakeCtrl.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    child: SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 20),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          margin: const EdgeInsets.only(top: 12),
          width: 40, height: 4,
          decoration: BoxDecoration(
            color: AppColors.border, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 20),
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.primaryMid],
              begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.3),
              blurRadius: 12, offset: const Offset(0, 4))]),
          child: const Icon(Icons.lock_rounded, color: Colors.white, size: 24)),
        const SizedBox(height: 12),
        Text('Confirm with PIN',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 17, fontWeight: FontWeight.w900,
            color: AppColors.textPrimary, letterSpacing: -0.3)),
        const SizedBox(height: 4),
        Text('Enter your PIN to confirm this adjustment',
          style: GoogleFonts.inter(
            fontSize: 12, fontWeight: FontWeight.w500,
            color: AppColors.textMuted)),
        const SizedBox(height: 24),
        AnimatedBuilder(
          animation: _shakeAnim,
          builder: (_, child) => Transform.translate(
            offset: Offset(_shakeAnim.value, 0), child: child),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(4, (i) {
              final filled = i < _pin.length;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                width: 14, height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: filled ? AppColors.primary : AppColors.border,
                  border: Border.all(
                    color: filled ? AppColors.primary : AppColors.borderLight,
                    width: 1.5)));
            }))),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          child: _error != null
              ? Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(_error!,
                    style: GoogleFonts.inter(
                      fontSize: 12, fontWeight: FontWeight.w600,
                      color: AppColors.danger)))
              : const SizedBox.shrink()),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            children: [
              for (final row in [
                ['1','2','3'], ['4','5','6'],
                ['7','8','9'], ['','0','⌫'],
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: row.map((k) {
                      if (k.isEmpty) return const SizedBox(width: 76);
                      return _ConfirmKey(
                        label: k,
                        onTap: k == '⌫' ? _onDelete : () => _onKey(k));
                    }).toList())),
            ])),
      ])));
}

class _ConfirmKey extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _ConfirmKey({required this.label, required this.onTap});
  @override
  State<_ConfirmKey> createState() => _ConfirmKeyState();
}

class _ConfirmKeyState extends State<_ConfirmKey> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isDel = widget.label == '⌫';
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) { setState(() => _pressed = false); widget.onTap(); },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.88 : 1.0,
        duration: const Duration(milliseconds: 80),
        child: Container(
          width: 76, height: 62,
          decoration: BoxDecoration(
            color: _pressed
                ? AppColors.primary.withValues(alpha: 0.08)
                : AppColors.bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border)),
          child: Center(
            child: isDel
                ? const Icon(Icons.backspace_outlined,
                    size: 20, color: AppColors.textMuted)
                : Text(widget.label,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 22, fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary))))));
  }
}

class _TypeBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _TypeBtn({required this.label, required this.icon, required this.color,
                  required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : AppColors.bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color : AppColors.border,
            width: selected ? 1.5 : 1)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 18,
            color: selected ? color : AppColors.textMuted),
          const SizedBox(height: 4),
          Text(label,
            style: GoogleFonts.inter(
              fontSize: 11, fontWeight: FontWeight.w700,
              color: selected ? color : AppColors.textMuted)),
        ]))));
}
