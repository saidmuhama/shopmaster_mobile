import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import 'receipt_screen.dart';

// Formats digits with commas as the user types (e.g. 25000 → 25,000)
class _MoneyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.isEmpty) return newValue.copyWith(text: '');
    final formatted = NumberFormat('#,###').format(int.parse(digits));
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

String _fmtMoney(double v) => NumberFormat('#,###').format(v.toInt());

class PosScreen extends StatefulWidget {
  final AuthUser user;
  final ValueNotifier<int>? tabNotifier;
  const PosScreen({super.key, required this.user, this.tabNotifier});
  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> with TickerProviderStateMixin {
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  final List<CartItem> _cart = [];

  List<PosProduct> _products = [];
  List<String> _categories = ['All'];
  String _selectedCat = 'All';
  bool _loading = false;
  bool _isWholesale = false;
  Timer? _debounce;
  late AnimationController _cartBadgeCtrl;

  @override
  void initState() {
    super.initState();
    _cartBadgeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _loadProducts('');
    widget.tabNotifier?.addListener(_onTabChange);
  }

  void _onTabChange() {
    if (mounted && !_loading) _loadProducts(_searchCtrl.text.trim());
  }

  @override
  void dispose() {
    widget.tabNotifier?.removeListener(_onTabChange);
    _debounce?.cancel();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _cartBadgeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProducts(String q) async {
    setState(() => _loading = true);
    try {
      final result = await ApiService.searchProductsRaw(q);
      final ok = result['ok'] == true;
      if (!ok && mounted) {
        final msg = result['error']?.toString() ?? 'Failed to load products';
        _showSnack(msg);
      }
      final products = ok
          ? (result['products'] as List).map((p) => PosProduct.fromJson(p)).toList()
          : <PosProduct>[];
      final cats = ['All', ...{...products.map((p) => p.categoryName)}];
      if (mounted) setState(() { _products = products; _categories = cats; _loading = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _showSnack('Network error: ${e.toString().split('\n').first}');
      }
    }
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 380), () => _loadProducts(v.trim()));
  }

  List<PosProduct> get _filtered {
    if (_selectedCat == 'All') return _products;
    return _products.where((p) => p.categoryName == _selectedCat).toList();
  }

  void _addToCart(PosProduct p) {
    if (!p.inStock) {
      _showSnack('${p.name} is out of stock');
      return;
    }
    HapticFeedback.lightImpact();
    setState(() {
      final idx = _cart.indexWhere((c) => c.product.id == p.id);
      if (idx >= 0) {
        _cart[idx].quantity += 1;
        if (_isWholesale && p.wholesalePrice > 0) {
          final minQty = p.minWholesaleQty;
          _cart[idx].price = (minQty == null || _cart[idx].quantity >= minQty)
              ? p.wholesalePrice : p.sellingPrice;
        }
      } else {
        final item = CartItem(product: p);
        if (_isWholesale && p.wholesalePrice > 0) {
          final minQty = p.minWholesaleQty;
          if (minQty == null || 1.0 >= minQty) item.price = p.wholesalePrice;
        }
        _cart.add(item);
      }
    });
    _cartBadgeCtrl.forward(from: 0);
  }

  void _toggleWholesale() {
    HapticFeedback.selectionClick();
    setState(() {
      _isWholesale = !_isWholesale;
      for (final item in _cart) {
        if (_isWholesale && item.product.wholesalePrice > 0) {
          final minQty = item.product.minWholesaleQty;
          item.price = (minQty == null || item.quantity >= minQty)
              ? item.product.wholesalePrice : item.product.sellingPrice;
        } else {
          item.price = item.product.sellingPrice;
        }
      }
    });
  }

  Future<void> _openStockAdjust(PosProduct p) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PosAdjustSheet(product: p, currency: widget.user.currency),
    );
    if (result != null && mounted) {
      _loadProducts(_searchCtrl.text);
      final newQty = (result['new_qty'] as num?)?.toDouble() ?? 0;
      if (newQty > 0) _showSnack('Stock updated — tap to add to cart');
    }
  }

  void _removeFromCart(int idx) {
    HapticFeedback.mediumImpact();
    setState(() => _cart.removeAt(idx));
  }

  void _updateQty(int idx, double qty) {
    setState(() {
      if (qty <= 0) {
        _cart.removeAt(idx);
      } else {
        _cart[idx].quantity = qty;
        if (_isWholesale && _cart[idx].product.wholesalePrice > 0) {
          final minQty = _cart[idx].product.minWholesaleQty;
          _cart[idx].price = (minQty == null || qty >= minQty)
              ? _cart[idx].product.wholesalePrice : _cart[idx].product.sellingPrice;
        }
      }
    });
  }

  int get _cartCount => _cart.length;
  double get _cartTotal => _cart.fold(0.0, (s, c) => s + c.total);

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
  }

  void _openCart() {
    if (_cart.isEmpty) { _showSnack('Cart is empty'); return; }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CartSheet(
        cart: _cart,
        user: widget.user,
        isWholesale: _isWholesale,
        onRemove: _removeFromCart,
        onQtyChanged: _updateQty,
        onSaleComplete: (result) {
          setState(() => _cart.clear());
          _loadProducts(''); // refresh stock quantities immediately
          Navigator.pop(context);
          Navigator.push(context,
            MaterialPageRoute(builder: (_) => ReceiptScreen(saleResult: result, user: widget.user))
          ).then((_) { if (mounted) _loadProducts(_searchCtrl.text.trim()); });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final resp = Responsive.of(context);
    // On large tablets: split-pane — products left, inline cart right
    if (resp.isLargeTablet) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        body: Row(children: [
          Expanded(
            flex: 3,
            child: Column(children: [
              _buildHeader(),
              _buildSearchAndCategories(),
              Expanded(child: _buildProductGrid()),
            ]),
          ),
          // Inline cart panel
          Container(
            width: 340,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(left: BorderSide(
                color: AppColors.border.withValues(alpha: 0.5)))),
            child: _cart.isEmpty
                ? _buildEmptyCartPanel()
                : _CartSheet(
                    cart: _cart,
                    user: widget.user,
                    isWholesale: _isWholesale,
                    isInlinePanel: true,
                    onRemove: _removeFromCart,
                    onQtyChanged: _updateQty,
                    onSaleComplete: (result) {
                      setState(() => _cart.clear());
                      _loadProducts('');
                      Navigator.push(context,
                        MaterialPageRoute(builder: (_) =>
                          ReceiptScreen(saleResult: result, user: widget.user))
                      ).then((_) { if (mounted) _loadProducts(_searchCtrl.text.trim()); });
                    },
                  ),
          ),
        ]),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(children: [
        _buildHeader(),
        _buildSearchAndCategories(),
        Expanded(child: _buildProductGrid()),
      ]),
      floatingActionButton: _cart.isNotEmpty ? _buildCartFab() : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildEmptyCartPanel() {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(18)),
          child: const Icon(Icons.shopping_cart_outlined,
            size: 30, color: AppColors.primary)),
        const SizedBox(height: 12),
        Text('Cart is empty',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14, fontWeight: FontWeight.w800,
            color: AppColors.textPrimary)),
        const SizedBox(height: 4),
        Text('Tap a product to add',
          style: GoogleFonts.inter(
            fontSize: 12, color: AppColors.textMuted)),
      ]),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF061410), Color(0xFF0F2D1A), Color(0xFF163522)],
          begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
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
          child: const Icon(Icons.point_of_sale_rounded, color: AppColors.accent, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Point of Sale',
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18, fontWeight: FontWeight.w900,
                color: Colors.white, letterSpacing: -0.4)),
            Text('${widget.user.shopName}  ·  ${widget.user.name}',
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 11, color: Colors.white.withValues(alpha: 0.45),
                fontWeight: FontWeight.w500)),
          ]),
        ),
        // Wholesale toggle
        GestureDetector(
          onTap: _toggleWholesale,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            decoration: BoxDecoration(
              color: _isWholesale
                  ? const Color(0xFF2563EB).withValues(alpha: 0.9)
                  : Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _isWholesale
                    ? const Color(0xFF2563EB)
                    : Colors.white.withValues(alpha: 0.22))),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(
                _isWholesale ? Icons.groups_rounded : Icons.person_rounded,
                size: 13, color: Colors.white.withValues(alpha: 0.9)),
              const SizedBox(width: 5),
              Text(_isWholesale ? 'Wholesale' : 'Retail',
                style: GoogleFonts.inter(
                  fontSize: 11, fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.9))),
            ]),
          ),
        ),
        if (_cart.isNotEmpty) ...[
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _openCart,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.accent, AppColors.accentDark],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.4),
                  blurRadius: 12, offset: const Offset(0, 3))]),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.shopping_cart_rounded, color: Colors.white, size: 15),
                const SizedBox(width: 6),
                Text('$_cartCount',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white)),
              ]),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _buildSearchAndCategories() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0a1e14), Color(0xFF0F2D1A)],
          begin: Alignment.topCenter, end: Alignment.bottomCenter)),
      child: Column(children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.13))),
            child: Row(children: [
              const Padding(
                padding: EdgeInsets.only(left: 14),
                child: Icon(Icons.search_rounded, color: Colors.white54, size: 18)),
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  focusNode: _searchFocus,
                  onChanged: _onSearchChanged,
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 14,
                    fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    hintText: 'Search products or scan SKU…',
                    hintStyle: GoogleFonts.inter(
                      color: Colors.white.withValues(alpha: 0.35), fontSize: 14),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: true,
                    fillColor: Colors.transparent,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
                    isDense: true),
                ),
              ),
              if (_searchCtrl.text.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    _searchCtrl.clear();
                    _loadProducts('');
                    _searchFocus.unfocus();
                  },
                  child: const Padding(
                    padding: EdgeInsets.only(right: 12),
                    child: Icon(Icons.close_rounded, color: Colors.white38, size: 17))),
            ]),
          ),
        ),
        // Category chips
        SizedBox(
          height: 44,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            itemCount: _categories.length,
            itemBuilder: (_, i) {
              final cat = _categories[i];
              final sel = cat == _selectedCat;
              return GestureDetector(
                onTap: () => setState(() => _selectedCat = cat),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.only(right: 7),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    color: sel ? AppColors.accent : Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: sel ? AppColors.accent : Colors.white.withValues(alpha: 0.14))),
                  child: Text(cat,
                    style: GoogleFonts.inter(
                      fontSize: 12, fontWeight: sel ? FontWeight.w800 : FontWeight.w500,
                      color: sel ? Colors.white : Colors.white.withValues(alpha: 0.55))),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
      ]),
    );
  }

  Widget _buildProductGrid() {
    final resp = Responsive.of(context);
    final cols = resp.posColumns;
    final spacing = resp.cardSpacing;
    final pad = resp.hPad - 4;
    final aspectRatio = resp.posCardRatio;

    if (_loading) {
      return RefreshIndicator(
        onRefresh: () => _loadProducts(_searchCtrl.text.trim()),
        color: AppColors.accent,
        child: GridView.builder(
          padding: EdgeInsets.all(pad),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols, childAspectRatio: aspectRatio,
            crossAxisSpacing: spacing, mainAxisSpacing: spacing),
          itemCount: cols * 2,
          itemBuilder: (_, __) => Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border)),
            child: const _ShimmerCard(),
          ),
        ),
      );
    }
    final prods = _filtered;
    if (prods.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _loadProducts(_searchCtrl.text.trim()),
        color: AppColors.accent,
        child: ListView(
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.22),
            Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(20)),
                  child: const Icon(Icons.inventory_2_outlined,
                    size: 36, color: AppColors.primary)),
                const SizedBox(height: 14),
                Text('No products found',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: resp.fs(15), fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                Text('Try a different search or category',
                  style: GoogleFonts.inter(
                    fontSize: resp.fs(12), color: AppColors.textMuted)),
              ]),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _loadProducts(_searchCtrl.text.trim()),
      color: AppColors.accent,
      child: GridView.builder(
        padding: EdgeInsets.fromLTRB(pad, pad, pad,
          _cart.isNotEmpty ? (resp.isTablet ? 20 : 90) : 20),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols, childAspectRatio: aspectRatio,
          crossAxisSpacing: spacing, mainAxisSpacing: spacing),
        itemCount: prods.length,
        itemBuilder: (_, i) => _ProductCard(
          product: prods[i],
          cartQty: _cart.where((c) => c.product.id == prods[i].id)
              .fold(0.0, (s, c) => s + c.quantity),
          currency: widget.user.currency,
          isWholesale: _isWholesale,
          isTablet: resp.isTablet,
          onAdd: () => _addToCart(prods[i]),
          onAdjust: () => _openStockAdjust(prods[i]),
        ),
      ),
    );
  }

  Widget _buildCartFab() {
    return GestureDetector(
      onTap: _openCart,
      child: Container(
        height: 60, width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primary, Color(0xFF1a472a)],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.45),
            blurRadius: 20, offset: const Offset(0, 6))]),
        child: Row(children: [
          const SizedBox(width: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(20)),
            child: Text('$_cartCount',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white)),
          ),
          const SizedBox(width: 12),
          Text('View Cart',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white,
              letterSpacing: -0.3)),
          const Spacer(),
          Column(mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('Total',
              style: GoogleFonts.inter(
                fontSize: 10, color: Colors.white.withValues(alpha: 0.55),
                fontWeight: FontWeight.w600)),
            Text('${widget.user.currency} ${_fmtNum(_cartTotal)}',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15, fontWeight: FontWeight.w900,
                color: AppColors.accent, letterSpacing: -0.3)),
          ]),
          const SizedBox(width: 20),
        ]),
      ),
    );
  }
}

// ── Shimmer placeholder card ────────────────────────────────────────────────────
class _ShimmerCard extends StatefulWidget {
  const _ShimmerCard();
  @override
  State<_ShimmerCard> createState() => _ShimmerCardState();
}

class _ShimmerCardState extends State<_ShimmerCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _anim,
    builder: (_, __) => Padding(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(height: 52, width: 52,
          decoration: BoxDecoration(
            color: AppColors.borderLight.withValues(alpha: _anim.value),
            borderRadius: BorderRadius.circular(14))),
        const SizedBox(height: 12),
        Container(height: 12, width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.borderLight.withValues(alpha: _anim.value),
            borderRadius: BorderRadius.circular(4))),
        const SizedBox(height: 6),
        Container(height: 10, width: 80,
          decoration: BoxDecoration(
            color: AppColors.borderLight.withValues(alpha: _anim.value * 0.7),
            borderRadius: BorderRadius.circular(4))),
        const Spacer(),
        Container(height: 14, width: 100,
          decoration: BoxDecoration(
            color: AppColors.borderLight.withValues(alpha: _anim.value),
            borderRadius: BorderRadius.circular(4))),
        const SizedBox(height: 10),
        Container(height: 36, width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.borderLight.withValues(alpha: _anim.value * 0.6),
            borderRadius: BorderRadius.circular(10))),
      ]),
    ),
  );
}

// ── Product card ──────────────────────────────────────────────────────────────
class _ProductCard extends StatefulWidget {
  final PosProduct product;
  final double cartQty;
  final String currency;
  final bool isWholesale;
  final bool isTablet;
  final VoidCallback onAdd;
  final VoidCallback onAdjust;

  const _ProductCard({
    required this.product, required this.cartQty,
    required this.currency, required this.onAdd,
    required this.onAdjust,
    this.isWholesale = false,
    this.isTablet = false,
  });

  @override
  State<_ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<_ProductCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressCtrl;
  late Animation<double> _scaleAnim;
  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 120));
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _pressCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _pressCtrl.dispose(); super.dispose(); }

  // Generate a deterministic gradient for each product based on initial letter
  List<Color> _avatarColors(String name) {
    final palettes = [
      [const Color(0xFF0F2D1A), const Color(0xFF1a4a2e)],  // green
      [const Color(0xFF1E3A5F), const Color(0xFF2563EB)],  // blue
      [const Color(0xFF6B21A8), const Color(0xFF9333EA)],  // purple
      [const Color(0xFFB45309), const Color(0xFFD97706)],  // amber
      [const Color(0xFF0F766E), const Color(0xFF14B8A6)],  // teal
      [const Color(0xFF9F1239), const Color(0xFFE11D48)],  // rose
      [const Color(0xFF1D4ED8), const Color(0xFF3B82F6)],  // indigo
      [const Color(0xFF15803D), const Color(0xFF22C55E)],  // emerald
    ];
    final i = (name.codeUnits.first) % palettes.length;
    return palettes[i];
  }

  @override
  Widget build(BuildContext context) {
    final inCart = widget.cartQty > 0;
    final outOfStock = !widget.product.inStock;
    final avatarColors = _avatarColors(widget.product.name);
    final stockPct = widget.product.qty > 0
        ? (widget.product.qty / (widget.product.qty + 20)).clamp(0.0, 1.0)
        : 0.0;
    final hasImage = widget.product.imageUrl.isNotEmpty;
    final minWs = widget.product.minWholesaleQty;
    // wsActive: wholesale pricing actually in effect (min qty met or no min)
    final wsActive = widget.isWholesale && widget.product.wholesalePrice > 0
        && (minWs == null || widget.cartQty >= minWs);
    // showMinHint: in wholesale mode but min qty not yet reached
    final showMinHint = widget.isWholesale && widget.product.wholesalePrice > 0
        && minWs != null && widget.cartQty < minWs;
    // displayPrice = the price actually being charged — matches what the cart will use.
    // wsActive means min qty is met (or no min set), so wholesale applies.
    // When wholesale mode is on but min qty not yet reached, show retail (what's charged).
    final displayPrice = wsActive
        ? widget.product.wholesalePrice
        : widget.product.sellingPrice;

    return GestureDetector(
      onTapDown: (_) {
        _pressCtrl.forward();
      },
      onTapUp: (_) {
        _pressCtrl.reverse();
        if (widget.product.inStock) {
          widget.onAdd();
        } else {
          widget.onAdjust();
        }
      },
      onTapCancel: () {
        _pressCtrl.reverse();
      },
      child: AnimatedBuilder(
        animation: _scaleAnim,
        builder: (_, child) => Transform.scale(scale: _scaleAnim.value, child: child),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: inCart
                  ? AppColors.primary.withValues(alpha: 0.6)
                  : outOfStock
                      ? AppColors.border
                      : AppColors.border,
              width: inCart ? 1.5 : 1),
            boxShadow: inCart
                ? [BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.18),
                    blurRadius: 14, offset: const Offset(0, 4))]
                : AppShadows.sm,
          ),
          child: Stack(children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                widget.isTablet ? 10 : 12,
                widget.isTablet ? 10 : 14,
                widget.isTablet ? 10 : 12, 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar / image
                  Row(children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(widget.isTablet ? 11 : 14),
                      child: SizedBox(
                        width: widget.isTablet ? 42 : 52,
                        height: widget.isTablet ? 42 : 52,
                        child: hasImage
                            ? CachedNetworkImage(
                                imageUrl: widget.product.imageUrl,
                                fit: BoxFit.cover,
                                memCacheWidth: 104,
                                placeholder: (_, __) => Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: avatarColors,
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight)),
                                  child: Center(
                                    child: Text(
                                      widget.product.name.substring(0, 1).toUpperCase(),
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 22, fontWeight: FontWeight.w900,
                                        color: Colors.white)))),
                                errorWidget: (_, __, ___) => Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: outOfStock
                                          ? [const Color(0xFFe2e8f0), const Color(0xFFf1f5f9)]
                                          : avatarColors,
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight)),
                                  child: Center(
                                    child: Text(
                                      widget.product.name.substring(0, 1).toUpperCase(),
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 22, fontWeight: FontWeight.w900,
                                        color: outOfStock ? AppColors.textMuted : Colors.white)))),
                              )
                            : Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: outOfStock
                                        ? [const Color(0xFFe2e8f0), const Color(0xFFf1f5f9)]
                                        : avatarColors,
                                    begin: Alignment.topLeft, end: Alignment.bottomRight)),
                                child: Center(
                                  child: Text(widget.product.name.substring(0, 1).toUpperCase(),
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 22, fontWeight: FontWeight.w900,
                                      color: outOfStock ? AppColors.textMuted : Colors.white)))),
                      ),
                    ),
                    const Spacer(),
                    if (outOfStock)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.dangerBg,
                          borderRadius: BorderRadius.circular(8)),
                        child: Text('Out',
                          style: GoogleFonts.inter(
                            fontSize: 9, fontWeight: FontWeight.w800,
                            color: AppColors.danger)))
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: widget.product.qty <= 5
                              ? AppColors.warningBg
                              : const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(8)),
                        child: Text(_fmtNum(widget.product.qty),
                          style: GoogleFonts.inter(
                            fontSize: 10, fontWeight: FontWeight.w800,
                            color: widget.product.qty <= 5
                                ? AppColors.warning : AppColors.successDark))),
                  ]),
                  SizedBox(height: widget.isTablet ? 7 : 10),
                  // Name
                  Text(widget.product.name,
                    maxLines: widget.isTablet ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: widget.isTablet ? 11 : 13,
                      fontWeight: FontWeight.w800,
                      color: outOfStock ? AppColors.textMuted : AppColors.textPrimary,
                      height: 1.25)),
                  const SizedBox(height: 2),
                  Text(widget.product.categoryName,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: widget.isTablet ? 9 : 10,
                      color: AppColors.textMuted, fontWeight: FontWeight.w500)),
                  SizedBox(height: widget.isTablet ? 7 : 10),
                  // Stock bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Stack(children: [
                      Container(height: 3, color: AppColors.borderLight),
                      FractionallySizedBox(
                        widthFactor: stockPct,
                        child: Container(
                          height: 3,
                          decoration: BoxDecoration(
                            color: outOfStock
                                ? AppColors.danger
                                : stockPct < 0.3 ? AppColors.warning : AppColors.success,
                            borderRadius: BorderRadius.circular(4))),
                      ),
                    ]),
                  ),
                  SizedBox(height: widget.isTablet ? 7 : 10),
                  // Price
                  Row(children: [
                    Expanded(
                      child: Text('${widget.currency} ${_fmtNum(displayPrice)}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: widget.isTablet ? 13 : 15,
                          fontWeight: FontWeight.w900,
                          color: outOfStock
                              ? AppColors.textMuted
                              : wsActive
                                  ? const Color(0xFF2563EB)
                                  : AppColors.primary,
                          letterSpacing: -0.4)),
                    ),
                    if (wsActive)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.3))),
                        child: Text('W',
                          style: GoogleFonts.inter(
                            fontSize: 8, fontWeight: FontWeight.w900,
                            color: const Color(0xFF2563EB)))),
                  ]),
                  if (showMinHint) ...[
                    const SizedBox(height: 3),
                    Row(children: [
                      const Icon(Icons.bolt_rounded, size: 9,
                        color: Color(0xFF2563EB)),
                      const SizedBox(width: 3),
                      Expanded(child: Text(
                        widget.cartQty > 0
                            ? 'WS: ${widget.currency} ${_fmtNum(widget.product.wholesalePrice)} · add ${_fmtNum(minWs - widget.cartQty)} more'
                            : 'WS: ${widget.currency} ${_fmtNum(widget.product.wholesalePrice)} · min ${_fmtNum(minWs)} units',
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 9, fontWeight: FontWeight.w600,
                          color: const Color(0xFF2563EB)))),
                    ]),
                  ],
                  SizedBox(height: widget.isTablet ? 7 : 10),
                  // Add button
                  Container(
                    width: double.infinity,
                    height: widget.isTablet ? 30 : 36,
                    decoration: BoxDecoration(
                      gradient: outOfStock
                          ? const LinearGradient(
                              colors: [Color(0xFFfff7ed), Color(0xFFffedd5)],
                              begin: Alignment.topLeft, end: Alignment.bottomRight)
                          : LinearGradient(
                              colors: inCart
                                  ? [AppColors.primary, const Color(0xFF1a472a)]
                                  : [const Color(0xFFf0fdf4), const Color(0xFFdcfce7)],
                              begin: Alignment.topLeft, end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: outOfStock
                            ? AppColors.accent.withValues(alpha: 0.45)
                            : inCart
                                ? AppColors.primary
                                : AppColors.success.withValues(alpha: 0.4))),
                    child: Center(
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(
                          outOfStock ? Icons.tune_rounded : Icons.add_rounded,
                          size: 14,
                          color: outOfStock
                              ? AppColors.accentDark
                              : inCart ? Colors.white : AppColors.success),
                        const SizedBox(width: 5),
                        Text(
                          outOfStock ? 'Adjust Stock' : inCart ? 'Add More' : 'Add to Cart',
                          style: GoogleFonts.inter(
                            fontSize: widget.isTablet ? 10 : 11,
                            fontWeight: FontWeight.w700,
                            color: outOfStock
                                ? AppColors.accentDark
                                : inCart ? Colors.white : AppColors.success)),
                      ]),
                    ),
                  ),
                  SizedBox(height: widget.isTablet ? 8 : 12),
                ],
              ),
            ),
            // Cart quantity badge
            if (inCart)
              Positioned(top: 10, right: 10,
                child: Container(
                  width: 24, height: 24,
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(
                      color: AppColors.accent.withValues(alpha: 0.4),
                      blurRadius: 6, offset: const Offset(0, 2))]),
                  child: Center(
                    child: Text(_fmtNum(widget.cartQty),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11, fontWeight: FontWeight.w900,
                        color: Colors.white))))),
            // Out of stock: subtle amber tint (card stays interactive)
            if (outOfStock)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(18)))),
          ]),
        ),
      ),
    );
  }
}

// ── Split payment row helper ──────────────────────────────────────────────────
class _SplitPayRow {
  String method;
  final TextEditingController ctrl;
  _SplitPayRow({required this.method, String amount = ''})
      : ctrl = TextEditingController(text: amount);
  void dispose() => ctrl.dispose();
  double get amount => double.tryParse(ctrl.text.replaceAll(',', '')) ?? 0;
}

// ── Cart Bottom Sheet ─────────────────────────────────────────────────────────
class _CartSheet extends StatefulWidget {
  final List<CartItem> cart;
  final AuthUser user;
  final bool isWholesale;
  final bool isInlinePanel;
  final Function(int) onRemove;
  final Function(int, double) onQtyChanged;
  final Function(Map<String, dynamic>) onSaleComplete;

  const _CartSheet({
    required this.cart, required this.user,
    required this.onRemove, required this.onQtyChanged,
    required this.onSaleComplete,
    this.isWholesale = false,
    this.isInlinePanel = false,
  });

  @override
  State<_CartSheet> createState() => _CartSheetState();
}

class _CartSheetState extends State<_CartSheet> {
  final _discountCtrl = TextEditingController(text: '0');
  final _cashCtrl = TextEditingController();
  final _custNameCtrl = TextEditingController();
  final _custPhoneCtrl = TextEditingController();
  String _payMethod = 'cash';
  bool _loading = false;
  List<_SplitPayRow> _splitRows = [];

  // Dynamic — loaded from API; keyed as (slug, label, color)
  List<(String, String, Color)> _methods = const [
    ('cash',   'Cash',   Color(0xFF22c55e)),
    ('mpesa',  'M-Pesa', Color(0xFFef4444)),
    ('credit', 'Credit', Color(0xFFf59e0b)),
  ];

  static Color _hexToColor(String hex) {
    final h = hex.replaceAll('#', '');
    if (h.length != 6) return const Color(0xFF6b7280);
    return Color(int.parse('FF$h', radix: 16));
  }

  static IconData _iconFor(String slug) {
    if (slug == 'cash')    return Icons.payments_rounded;
    if (slug == 'bank' || slug == 'cheque') return Icons.account_balance_rounded;
    if (slug == 'credit')  return Icons.credit_card_rounded;
    if (slug == 'wallet')  return Icons.account_balance_wallet_rounded;
    if (slug.contains('pesa') || slug.contains('airtel') || slug.contains('mpesa'))
      return Icons.phone_android_rounded;
    return Icons.payments_outlined;
  }

  @override
  void initState() {
    super.initState();
    _cashCtrl.text = _fmtMoney(_total);
    _loadMethods();
  }

  Future<void> _loadMethods() async {
    try {
      final data = await ApiService.getPaymentMethods();
      if (!mounted) return;
      setState(() {
        _methods = data.map((m) {
          final slug  = (m['slug']  as String?) ?? 'cash';
          final name  = (m['name']  as String?) ?? slug;
          final color = _hexToColor((m['color'] as String?) ?? '#6b7280');
          return (slug, name, color);
        }).toList();
      });
    } catch (_) {}
  }

  double get _subtotal => widget.cart.fold(0, (s, c) => s + c.total);
  double get _discount =>
      double.tryParse(_discountCtrl.text.replaceAll(',', '')) ?? 0;
  double get _total => (_subtotal - _discount).clamp(0, double.infinity);
  double get _cashReceived =>
      double.tryParse(_cashCtrl.text.replaceAll(',', '')) ?? _total;
  double get _change => (_cashReceived - _total).clamp(0, double.infinity);

  void _syncCash() {
    if (_payMethod == 'cash') {
      _cashCtrl.text = _fmtMoney(_total);
    }
  }

  double get _splitTotal => _splitRows.fold(0.0, (s, r) => s + r.amount);
  double get _splitRemaining => _total - _splitTotal;

  void _initSplitRows() {
    for (final r in _splitRows) r.dispose();
    final m0 = _methods.isNotEmpty ? _methods[0].$1 : 'cash';
    final m1 = _methods.length > 1  ? _methods[1].$1 : 'mpesa';
    _splitRows = [
      _SplitPayRow(method: m0, amount: _fmtMoney(_total)),
      _SplitPayRow(method: m1, amount: '0'),
    ];
  }

  @override
  void dispose() {
    _discountCtrl.dispose(); _cashCtrl.dispose();
    _custNameCtrl.dispose(); _custPhoneCtrl.dispose();
    for (final r in _splitRows) r.dispose();
    super.dispose();
  }

  Future<void> _editQty(int idx) async {
    final item = widget.cart[idx];
    final ctrl = TextEditingController(text: _fmtNum(item.quantity));
    final newQty = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Set Quantity',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16, fontWeight: FontWeight.w800,
            color: AppColors.textPrimary)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(item.product.name,
            style: GoogleFonts.inter(
              fontSize: 13, color: AppColors.textMuted,
              fontWeight: FontWeight.w500)),
          const SizedBox(height: 14),
          TextField(
            controller: ctrl,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'[-]'))],
            style: GoogleFonts.plusJakartaSans(
              fontSize: 22, fontWeight: FontWeight.w900,
              color: AppColors.textPrimary, letterSpacing: -0.5),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              suffixText: item.product.unit,
              suffixStyle: GoogleFonts.inter(
                fontSize: 13, color: AppColors.textMuted,
                fontWeight: FontWeight.w600),
              filled: true,
              fillColor: const Color(0xFFF5F7FA),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: AppColors.primary.withValues(alpha: 0.5))),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
            ),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
              style: GoogleFonts.inter(color: AppColors.textMuted))),
          ElevatedButton(
            onPressed: () {
              final v = double.tryParse(ctrl.text.replaceAll(',', ''));
              if (v != null && v > 0) Navigator.pop(ctx, v);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10))),
            child: Text('Set',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800))),
        ],
      ),
    );
    if (newQty != null && mounted) {
      setState(() { widget.onQtyChanged(idx, newQty); _syncCash(); });
    }
  }

  Future<void> _editPrice(int idx) async {
    final item = widget.cart[idx];
    final newPrice = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PriceEditSheet(
        productName: item.product.name,
        currentPrice: item.price,
        originalPrice: item.product.sellingPrice,
        currency: widget.user.currency,
      ),
    );
    if (newPrice != null && mounted) {
      setState(() {
        widget.cart[idx].price = newPrice;
        _syncCash();
      });
    }
  }

  Future<void> _checkout() async {
    if (widget.cart.isEmpty) return;

    // Wholesale min qty validation: if in wholesale mode, warn about items
    // that don't meet the minimum quantity for wholesale pricing.
    if (widget.isWholesale) {
      final belowMin = <({String name, double qty, double minQty})>[];
      for (final item in widget.cart) {
        final minQty = item.product.minWholesaleQty;
        if (minQty != null && item.quantity < minQty && item.product.wholesalePrice > 0) {
          // Ensure item is priced at retail (not wholesale)
          item.price = item.product.sellingPrice;
          belowMin.add((name: item.product.name, qty: item.quantity, minQty: minQty));
        }
      }
      if (belowMin.isNotEmpty) {
        if (!mounted) return;
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: Row(children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(9)),
                child: const Icon(Icons.warning_amber_rounded,
                  color: Color(0xFFD97706), size: 18)),
              const SizedBox(width: 10),
              Expanded(child: Text('Minimum Qty Not Met',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15, fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary))),
            ]),
            content: Column(mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('These items will be charged at retail price:',
                style: GoogleFonts.inter(
                  fontSize: 13, color: AppColors.textMuted)),
              const SizedBox(height: 10),
              ...belowMin.map((e) => Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFD97706).withValues(alpha: 0.3))),
                child: Row(children: [
                  const Icon(Icons.inventory_2_outlined,
                    size: 14, color: Color(0xFFD97706)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(e.name,
                    style: GoogleFonts.inter(
                      fontSize: 12, fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary))),
                  Text('${_fmtNum(e.qty)} / ${_fmtNum(e.minQty)}',
                    style: GoogleFonts.inter(
                      fontSize: 11, color: const Color(0xFFD97706),
                      fontWeight: FontWeight.w600)),
                ]),
              )),
              const SizedBox(height: 6),
              Text('Continue at retail price?',
                style: GoogleFonts.inter(
                  fontSize: 13, color: AppColors.textMuted)),
            ]),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('Cancel',
                  style: GoogleFonts.inter(color: AppColors.textMuted))),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
                child: Text('Continue',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800))),
            ],
          ),
        );
        if (confirmed != true) {
          if (mounted) setState(() {});
          return;
        }
        if (mounted) setState(() {});
      }
    }

    List<Map<String, dynamic>>? splitPayments;
    double paidAmount;
    if (_payMethod == 'split') {
      final valid = _splitRows.where((r) => r.amount > 0).toList();
      if (valid.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Add at least one payment amount'),
          backgroundColor: AppColors.danger, behavior: SnackBarBehavior.floating));
        return;
      }
      splitPayments = valid.map((r) => {'method': r.method, 'amount': r.amount}).toList();
      paidAmount = valid.fold(0.0, (s, r) => s + r.amount);
    } else {
      paidAmount = _payMethod == 'cash' ? _cashReceived : _total;
    }
    setState(() => _loading = true);
    try {
      final result = await ApiService.createSale(
        items: widget.cart,
        paymentMethod: _payMethod,
        paidAmount: paidAmount,
        discount: _discount,
        customerName: _custNameCtrl.text.trim(),
        customerPhone: _custPhoneCtrl.text.trim(),
        payments: splitPayments,
      );
      if (!mounted) return;
      if (result['ok'] == true) {
        HapticFeedback.heavyImpact();
        widget.onSaleComplete({
          ...result,
          'cart': widget.cart.map((c) => {
            'name': c.product.name,
            'qty': c.quantity,
            'unit': c.product.unit,
            'price': c.price,
            'total': c.total,
          }).toList(),
          'subtotal': _subtotal,
          'discount': _discount,
          'payment_method': _payMethod,
          'customer_name': _custNameCtrl.text.trim(),
          'currency': widget.user.currency,
          'shop_name': widget.user.shopName,
          'cashier': widget.user.name,
        });
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(result['error'] ?? 'Sale failed'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Connection error. Please try again.'),
        backgroundColor: AppColors.danger,
        behavior: SnackBarBehavior.floating));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Inline panel on large tablets — no draggable sheet, just Column
    if (widget.isInlinePanel) {
      return _buildInnerContent(context, null);
    }
    return DraggableScrollableSheet(
      initialChildSize: 0.94,
      maxChildSize: 0.97,
      minChildSize: 0.5,
      builder: (_, scrollCtrl) => _buildInnerContent(context, scrollCtrl),
    );
  }

  Widget _buildInnerContent(BuildContext context, ScrollController? scrollCtrl) {
    final isInline = widget.isInlinePanel;
    return Container(
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: isInline
              ? BorderRadius.zero
              : const BorderRadius.vertical(top: Radius.circular(28))),
        child: Column(children: [
          // ── Dark premium header ──────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF061410), AppColors.primary, Color(0xFF163522)],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: isInline
                  ? BorderRadius.zero
                  : const BorderRadius.vertical(top: Radius.circular(28))),
            padding: EdgeInsets.fromLTRB(
              20, isInline ? (MediaQuery.of(context).padding.top + 14) : 14, 20, 20),
            child: Column(children: [
              // Handle (only for modal)
              if (!isInline) ...[
                Center(child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 16),
              ],
              Row(children: [
                if (!isInline)
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.15))),
                    child: const Icon(Icons.arrow_back_rounded,
                      color: Colors.white, size: 18)),
                ),
                if (!isInline) const SizedBox(width: 12),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Text('Cart',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 20, fontWeight: FontWeight.w900,
                          color: Colors.white, letterSpacing: -0.5)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.accent.withValues(alpha: 0.35))),
                        child: Text('${widget.cart.length} items',
                          style: GoogleFonts.inter(
                            fontSize: 11, fontWeight: FontWeight.w800,
                            color: AppColors.accent))),
                    ]),
                    const SizedBox(height: 2),
                    Text('Review and confirm your sale',
                      style: GoogleFonts.inter(
                        fontSize: 11, fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.4))),
                  ]),
                ),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('${widget.user.currency} ${_fmtNum(_total)}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 20, fontWeight: FontWeight.w900,
                      color: AppColors.accent, letterSpacing: -0.5)),
                  Text('total',
                    style: GoogleFonts.inter(
                      fontSize: 10, color: Colors.white.withValues(alpha: 0.4),
                      fontWeight: FontWeight.w600)),
                ]),
              ]),
            ]),
          ),

          // ── Scrollable form ────────────────────────────────────────────────
          Expanded(
            child: ListView(
              controller: scrollCtrl,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              children: [
                // Cart items
                ...List.generate(widget.cart.length, (i) {
                  final item = widget.cart[i];
                  return _CartItemRow(
                    item: item,
                    currency: widget.user.currency,
                    isWholesale: widget.isWholesale,
                    onRemove: () => setState(() { widget.onRemove(i); _syncCash(); }),
                    onInc: () => setState(() { widget.onQtyChanged(i, item.quantity + 1); _syncCash(); }),
                    onDec: () => setState(() { widget.onQtyChanged(i, item.quantity - 1); _syncCash(); }),
                    onQtyTap: () => _editQty(i),
                    onPriceEdit: () => _editPrice(i),
                  );
                }),

                const SizedBox(height: 16),
                _divider('Customer'),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _inputField(_custNameCtrl, 'Customer name',
                    Icons.person_outline_rounded)),
                  const SizedBox(width: 10),
                  Expanded(child: _inputField(_custPhoneCtrl, 'Phone number',
                    Icons.phone_outlined, type: TextInputType.phone)),
                ]),

                const SizedBox(height: 16),
                _divider('Discount'),
                const SizedBox(height: 10),
                _inputField(_discountCtrl, 'Discount amount (TZS)',
                  Icons.local_offer_outlined,
                  type: TextInputType.number,
                  money: true,
                  onChanged: (_) => setState(() {
                    _cashCtrl.text = _fmtMoney(_total);
                  })),

                const SizedBox(height: 16),
                _divider('Payment Method'),
                const SizedBox(height: 10),
                // Payment method grid — dynamic from tenant settings + split
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 2.2,
                  children: [
                    ..._methods.map((entry) {
                      final (slug, label, color) = entry;
                      final sel = _payMethod == slug;
                      return GestureDetector(
                        onTap: () => setState(() {
                          _payMethod = slug;
                          if (slug == 'cash') _cashCtrl.text = _fmtMoney(_total);
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          decoration: BoxDecoration(
                            color: sel ? color : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: sel ? color : AppColors.border,
                              width: sel ? 1.5 : 1),
                            boxShadow: sel ? [BoxShadow(
                              color: color.withValues(alpha: 0.25),
                              blurRadius: 8, offset: const Offset(0, 2))] : [],
                          ),
                          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(_iconFor(slug), size: 13,
                              color: sel ? Colors.white : AppColors.textMuted),
                            const SizedBox(width: 5),
                            Flexible(child: Text(label,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 11, fontWeight: FontWeight.w700,
                                color: sel ? Colors.white : AppColors.textSecondary))),
                          ]),
                        ),
                      );
                    }),
                    // Split payment chip
                    GestureDetector(
                      onTap: () => setState(() {
                        _payMethod = 'split';
                        _initSplitRows();
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        decoration: BoxDecoration(
                          color: _payMethod == 'split'
                              ? const Color(0xFF7C3AED) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _payMethod == 'split'
                                ? const Color(0xFF7C3AED) : AppColors.border,
                            width: _payMethod == 'split' ? 1.5 : 1),
                          boxShadow: _payMethod == 'split' ? [BoxShadow(
                            color: const Color(0xFF7C3AED).withValues(alpha: 0.25),
                            blurRadius: 8, offset: const Offset(0, 2))] : [],
                        ),
                        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.call_split_rounded, size: 13,
                            color: _payMethod == 'split' ? Colors.white : AppColors.textMuted),
                          const SizedBox(width: 5),
                          Text('Split',
                            style: GoogleFonts.inter(
                              fontSize: 11, fontWeight: FontWeight.w700,
                              color: _payMethod == 'split'
                                  ? Colors.white : AppColors.textSecondary)),
                        ]),
                      ),
                    ),
                  ],
                ),

                // Cash received (only for cash)
                if (_payMethod == 'cash') ...[
                  const SizedBox(height: 16),
                  _divider('Cash Received'),
                  const SizedBox(height: 10),
                  _inputField(_cashCtrl, 'Amount received',
                    Icons.payments_rounded,
                    type: TextInputType.number,
                    money: true,
                    onChanged: (_) => setState(() {})),
                  if (_change > 0) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFDCFCE7), Color(0xFFBBF7D0)]),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.success.withValues(alpha: 0.4))),
                      child: Row(children: [
                        Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.success,
                            borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.change_circle_outlined,
                            color: Colors.white, size: 18)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                            Text('Change to Give',
                              style: GoogleFonts.inter(
                                fontSize: 11, fontWeight: FontWeight.w600,
                                color: AppColors.successDark)),
                            Text('${widget.user.currency} ${_fmtNum(_change)}',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 18, fontWeight: FontWeight.w900,
                                color: AppColors.successDark, letterSpacing: -0.4)),
                          ]),
                        ),
                      ]),
                    ),
                  ],
                ],

                // Split payment rows
                if (_payMethod == 'split') ...[
                  const SizedBox(height: 16),
                  _divider('Split Payments'),
                  const SizedBox(height: 10),
                  ...List.generate(_splitRows.length, (i) {
                    final row = _splitRows[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border)),
                      child: Row(children: [
                        DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _methods.any((m) => m.$1 == row.method)
                                ? row.method : _methods.first.$1,
                            isDense: true,
                            style: GoogleFonts.inter(
                              fontSize: 12, fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary),
                            items: _methods.map((m) => DropdownMenuItem(
                              value: m.$1,
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(_iconFor(m.$1), size: 12, color: m.$3),
                                const SizedBox(width: 4),
                                Text(m.$2, style: GoogleFonts.inter(
                                  fontSize: 12, fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary)),
                              ]),
                            )).toList(),
                            onChanged: (v) => setState(() => row.method = v!),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: row.ctrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [_MoneyInputFormatter()],
                            textAlign: TextAlign.right,
                            onChanged: (_) => setState(() {}),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14, fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary),
                            decoration: InputDecoration(
                              prefixText: '${widget.user.currency} ',
                              prefixStyle: GoogleFonts.inter(
                                fontSize: 11, color: AppColors.textMuted,
                                fontWeight: FontWeight.w600),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              filled: true, fillColor: Colors.transparent,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 8),
                              isDense: true),
                          ),
                        ),
                        if (_splitRows.length > 2)
                          GestureDetector(
                            onTap: () => setState(() {
                              _splitRows[i].dispose();
                              _splitRows.removeAt(i);
                            }),
                            child: Container(
                              width: 28, height: 28,
                              margin: const EdgeInsets.only(left: 4),
                              decoration: BoxDecoration(
                                color: AppColors.dangerBg,
                                borderRadius: BorderRadius.circular(8)),
                              child: const Icon(Icons.close_rounded,
                                size: 14, color: AppColors.danger))),
                      ]),
                    );
                  }),
                  GestureDetector(
                    onTap: () => setState(() {
                      final method = _methods.isNotEmpty ? _methods[0].$1 : 'cash';
                      _splitRows.add(_SplitPayRow(method: method, amount: '0'));
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(12),
                        color: const Color(0xFFF9FAFB)),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.add_rounded, size: 14, color: AppColors.textMuted),
                        const SizedBox(width: 6),
                        Text('Add Payment Method',
                          style: GoogleFonts.inter(
                            fontSize: 12, fontWeight: FontWeight.w700,
                            color: AppColors.textMuted)),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: _splitRemaining.abs() < 0.5
                          ? const Color(0xFFDCFCE7)
                          : _splitRemaining > 0
                              ? const Color(0xFFFFF7ED)
                              : const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _splitRemaining.abs() < 0.5
                            ? AppColors.success.withValues(alpha: 0.4)
                            : _splitRemaining > 0
                                ? AppColors.warning.withValues(alpha: 0.4)
                                : AppColors.success.withValues(alpha: 0.4))),
                    child: Row(children: [
                      Icon(
                        _splitRemaining.abs() < 0.5
                            ? Icons.check_circle_outline_rounded
                            : _splitRemaining > 0
                                ? Icons.info_outline_rounded
                                : Icons.change_circle_outlined,
                        size: 16,
                        color: _splitRemaining.abs() < 0.5
                            ? AppColors.successDark
                            : _splitRemaining > 0
                                ? AppColors.warning
                                : AppColors.successDark),
                      const SizedBox(width: 8),
                      Expanded(child: Text(
                        _splitRemaining.abs() < 0.5
                            ? 'Fully paid'
                            : _splitRemaining > 0
                                ? 'Remaining: ${widget.user.currency} ${_fmtNum(_splitRemaining)}'
                                : 'Change: ${widget.user.currency} ${_fmtNum(-_splitRemaining)}',
                        style: GoogleFonts.inter(
                          fontSize: 12, fontWeight: FontWeight.w700,
                          color: _splitRemaining.abs() < 0.5
                              ? AppColors.successDark
                              : _splitRemaining > 0
                                  ? AppColors.warning
                                  : AppColors.successDark))),
                      Text('${widget.user.currency} ${_fmtNum(_splitTotal)}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14, fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary)),
                    ]),
                  ),
                ],

                const SizedBox(height: 16),

                // Summary card
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0F2D1A), Color(0xFF1a4a2e)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.25),
                      blurRadius: 16, offset: const Offset(0, 6))]),
                  child: Column(children: [
                    _darkSummaryRow('Items', '${widget.cart.length}'),
                    const SizedBox(height: 8),
                    _darkSummaryRow('Subtotal',
                      '${widget.user.currency} ${_fmtNum(_subtotal)}'),
                    if (_discount > 0) ...[
                      const SizedBox(height: 8),
                      _darkSummaryRow('Discount',
                        '- ${widget.user.currency} ${_fmtNum(_discount)}',
                        valueColor: const Color(0xFF4ADE80)),
                    ],
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Container(
                        height: 1,
                        color: Colors.white.withValues(alpha: 0.12))),
                    Row(children: [
                      Text('Total',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15, fontWeight: FontWeight.w700,
                          color: Colors.white.withValues(alpha: 0.7))),
                      const Spacer(),
                      Text('${widget.user.currency} ${_fmtNum(_total)}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 24, fontWeight: FontWeight.w900,
                          color: AppColors.accent, letterSpacing: -0.6)),
                    ]),
                  ]),
                ),

                const SizedBox(height: 100),
              ],
            ),
          ),

          // ── Confirm button ─────────────────────────────────────────────────
          Container(
            padding: EdgeInsets.fromLTRB(16, 12, 16,
              MediaQuery.of(context).padding.bottom + 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(
                color: Colors.black.withValues(alpha: 0.07),
                blurRadius: 16, offset: const Offset(0, -4))]),
            child: GestureDetector(
              onTap: _loading ? null : _checkout,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 58,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _loading
                        ? [AppColors.primaryMid, AppColors.primaryMid]
                        : [AppColors.accent, AppColors.accentDark],
                    begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: _loading ? [] : [BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.4),
                    blurRadius: 20, offset: const Offset(0, 6))]),
                child: Center(
                  child: _loading
                      ? const SizedBox(width: 24, height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white))
                      : Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.check_circle_rounded,
                            color: Colors.white, size: 22),
                          const SizedBox(width: 10),
                          Text('Confirm Sale',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16, fontWeight: FontWeight.w900,
                              color: Colors.white, letterSpacing: -0.3)),
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 10),
                            width: 1, height: 18,
                            color: Colors.white.withValues(alpha: 0.35)),
                          Text('${widget.user.currency} ${_fmtNum(_total)}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15, fontWeight: FontWeight.w800,
                              color: Colors.white.withValues(alpha: 0.9))),
                        ]),
                ),
              ),
            ),
          ),
        ]),
    );
  }

  Widget _divider(String title) => Row(children: [
    Text(title.toUpperCase(),
      style: GoogleFonts.inter(
        fontSize: 10, fontWeight: FontWeight.w800,
        color: AppColors.textMuted, letterSpacing: 0.8)),
    const SizedBox(width: 10),
    Expanded(child: Container(height: 1, color: AppColors.border)),
  ]);

  Widget _inputField(TextEditingController ctrl, String hint, IconData icon,
      {TextInputType? type, bool money = false, ValueChanged<String>? onChanged}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border)),
      child: Row(children: [
        Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Icon(icon, size: 16, color: AppColors.textMuted)),
        Expanded(
          child: TextField(
            controller: ctrl,
            keyboardType: type,
            inputFormatters: money ? [_MoneyInputFormatter()] : null,
            onChanged: onChanged,
            style: GoogleFonts.inter(
              fontSize: 13, fontWeight: FontWeight.w600,
              color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: true,
              fillColor: Colors.transparent,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
              isDense: true),
          ),
        ),
      ]),
    );
  }

  Widget _darkSummaryRow(String label, String value, {Color? valueColor}) => Row(children: [
    Text(label, style: GoogleFonts.inter(
      fontSize: 13, fontWeight: FontWeight.w500,
      color: Colors.white.withValues(alpha: 0.55))),
    const Spacer(),
    Text(value, style: GoogleFonts.plusJakartaSans(
      fontSize: 13, fontWeight: FontWeight.w800,
      color: valueColor ?? Colors.white.withValues(alpha: 0.85))),
  ]);
}

// ── Cart item row ─────────────────────────────────────────────────────────────
class _CartItemRow extends StatelessWidget {
  final CartItem item;
  final String currency;
  final bool isWholesale;
  final VoidCallback onRemove, onInc, onDec, onQtyTap, onPriceEdit;

  const _CartItemRow({
    required this.item, required this.currency,
    this.isWholesale = false,
    required this.onRemove, required this.onInc, required this.onDec,
    required this.onQtyTap, required this.onPriceEdit,
  });

  // same color hashing as product card
  Color _avatarColor(String name) {
    final colors = [
      AppColors.primary, const Color(0xFF2563EB), const Color(0xFF9333EA),
      const Color(0xFFD97706), const Color(0xFF14B8A6), const Color(0xFFE11D48),
    ];
    return colors[name.codeUnits.first % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final col = _avatarColor(item.product.name);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.sm),
      child: Row(children: [
        // Avatar
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: col.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: col.withValues(alpha: 0.25))),
          child: Center(
            child: Text(item.product.name.substring(0, 1).toUpperCase(),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18, fontWeight: FontWeight.w900, color: col))),
        ),
        const SizedBox(width: 10),
        // Name + price per unit
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.product.name,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13, fontWeight: FontWeight.w800,
                color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            Builder(builder: (ctx) {
              final wsPrice = item.product.wholesalePrice;
              final retailPrice = item.product.sellingPrice;
              final isWsApplied = isWholesale && wsPrice > 0 && (item.price - wsPrice).abs() < 0.01;
              final isRetailFallback = isWholesale && wsPrice > 0 && (item.price - retailPrice).abs() < 0.01;
              final isManualEdit = item.price != retailPrice && !isWsApplied;

              final badgeColor = isWsApplied
                  ? const Color(0xFF2563EB)
                  : isRetailFallback
                      ? const Color(0xFFD97706)
                      : isManualEdit ? AppColors.accent : AppColors.textMuted;
              final badgeBg = isWsApplied
                  ? const Color(0xFFEFF6FF)
                  : isRetailFallback
                      ? const Color(0xFFFFF7ED)
                      : isManualEdit
                          ? AppColors.accent.withValues(alpha: 0.1)
                          : AppColors.bg;
              final label = isWsApplied ? 'Wholesale'
                  : isRetailFallback ? 'Retail rate'
                  : isManualEdit ? 'edited' : null;

              // Price badge (compact: icon + price only) + label outside badge
              return Row(children: [
                GestureDetector(
                  onTap: onPriceEdit,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: badgeColor.withValues(alpha: 0.4))),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.edit_rounded, size: 10, color: badgeColor),
                      const SizedBox(width: 4),
                      Text('$currency ${_fmtNum(item.price)}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11, fontWeight: FontWeight.w800, color: badgeColor)),
                    ]),
                  ),
                ),
                if (label != null) ...[
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text('($label)',
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 9, fontWeight: FontWeight.w600,
                        color: badgeColor.withValues(alpha: 0.8)))),
                ],
              ]);
            }),
          ]),
        ),
        const SizedBox(width: 6),
        // Qty controls
        Row(mainAxisSize: MainAxisSize.min, children: [
          _qtyBtn(Icons.remove_rounded, onDec, item.quantity <= 0.001),
          GestureDetector(
            onTap: onQtyTap,
            child: Container(
              width: 36, height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.15))),
              child: Text(_fmtNum(item.quantity),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12, fontWeight: FontWeight.w900,
                  color: AppColors.primary)))),
          _qtyBtn(Icons.add_rounded, onInc, false),
        ]),
        const SizedBox(width: 6),
        // Total + delete
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(_fmtNum(item.total),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13, fontWeight: FontWeight.w900,
              color: AppColors.primary, letterSpacing: -0.3)),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 26, height: 26,
              decoration: BoxDecoration(
                color: AppColors.dangerBg,
                borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.delete_outline_rounded,
                size: 13, color: AppColors.danger))),
        ]),
      ]),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap, bool isDim) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28, height: 32,
        decoration: BoxDecoration(
          color: isDim ? AppColors.borderLight : AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDim ? AppColors.border : AppColors.primary.withValues(alpha: 0.2))),
        child: Icon(icon, size: 12,
          color: isDim ? AppColors.textMuted : AppColors.primary)),
    );
  }
}

String _fmtNum(double v) {
  if (v == v.truncateToDouble()) return NumberFormat('#,##0', 'en_US').format(v.toInt());
  return NumberFormat('#,##0.###', 'en_US').format(v);
}

// ── POS Quick Stock Adjust sheet ─────────────────────────────────────────────
class _PosAdjustSheet extends StatefulWidget {
  final PosProduct product;
  final String currency;
  const _PosAdjustSheet({required this.product, required this.currency});

  @override
  State<_PosAdjustSheet> createState() => _PosAdjustSheetState();
}

class _PosAdjustSheetState extends State<_PosAdjustSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _qtyCtrl   = TextEditingController();
  final _notesCtrl = TextEditingController();
  String  _reason  = 'Purchase';
  bool    _saving  = false;
  String? _err;
  List<Map<String, dynamic>> _history = [];
  bool _histLoading = true;

  static const _reasons = [
    'Purchase', 'Return', 'Correction', 'Initial Count', 'Damage', 'Other',
  ];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _loadHistory();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _qtyCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    try {
      final rows = await ApiService.getStockMovements(productId: widget.product.id, limit: 30);
      if (mounted) setState(() { _history = rows; _histLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _histLoading = false);
    }
  }

  Future<void> _save() async {
    final qty = double.tryParse(_qtyCtrl.text.trim()) ?? 0;
    if (qty <= 0) {
      setState(() => _err = 'Enter a valid quantity to add');
      return;
    }
    setState(() { _saving = true; _err = null; });
    HapticFeedback.mediumImpact();
    try {
      final res = await ApiService.adjustStock(
        productId: widget.product.id,
        type: 'add', qty: qty,
        reason: _reason, notes: _notesCtrl.text.trim(),
      );
      if (!mounted) return;
      if (res['ok'] == true) {
        HapticFeedback.heavyImpact();
        // Pass through; caller checks res['pending'] to decide whether to update UI
        Navigator.pop(context, res);
      } else {
        setState(() { _saving = false; _err = res['error']?.toString() ?? 'Adjustment failed'; });
      }
    } catch (_) {
      if (mounted) setState(() { _saving = false; _err = 'Network error'; });
    }
  }

  static Color _typeColor(String type) {
    switch (type) {
      case 'purchase':     return const Color(0xFF15803d);
      case 'sale':         return const Color(0xFFb91c1c);
      case 'adjustment':   return const Color(0xFF1d4ed8);
      case 'return':       return const Color(0xFFb45309);
      case 'transfer_in':  return const Color(0xFF0e7490);
      case 'transfer_out': return const Color(0xFF6b7280);
      default:             return const Color(0xFF6b7280);
    }
  }

  static String _typeLabel(String type) => type.replaceAll('_', ' ').toUpperCase();

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: Column(children: [
        // ── Header ──────────────────────────────────────────────────────────
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF061410), AppColors.primary, Color(0xFF163522)],
              begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          child: Column(children: [
            Center(child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Row(children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: AppColors.accent.withValues(alpha: 0.3))),
                child: const Icon(Icons.tune_rounded, color: AppColors.accent, size: 20)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Adjust Stock',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 17, fontWeight: FontWeight.w900,
                    color: Colors.white, letterSpacing: -0.4)),
                Text(widget.product.name,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 11, color: Colors.white.withValues(alpha: 0.5),
                    fontWeight: FontWeight.w500)),
              ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('Current Stock',
                  style: GoogleFonts.inter(
                    fontSize: 10, color: Colors.white.withValues(alpha: 0.4),
                    fontWeight: FontWeight.w600)),
                Text('${_fmtNum(widget.product.qty)} ${widget.product.unit}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18, fontWeight: FontWeight.w900,
                    color: widget.product.inStock ? AppColors.accent : const Color(0xFFf87171),
                    letterSpacing: -0.5)),
              ]),
            ]),
            const SizedBox(height: 14),
            // Tab bar
            TabBar(
              controller: _tabs,
              indicatorColor: AppColors.accent,
              indicatorWeight: 2.5,
              labelColor: AppColors.accent,
              unselectedLabelColor: Colors.white.withValues(alpha: 0.45),
              labelStyle: GoogleFonts.plusJakartaSans(
                fontSize: 12, fontWeight: FontWeight.w800),
              unselectedLabelStyle: GoogleFonts.inter(
                fontSize: 12, fontWeight: FontWeight.w500),
              tabs: const [
                Tab(text: 'Add Stock'),
                Tab(text: 'History'),
              ],
            ),
          ]),
        ),

        // ── Tab content ──────────────────────────────────────────────────────
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              // ── Add Stock tab ──────────────────────────────────────────────
              SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20, 20, 20, bottom + 20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // OOS banner
                  if (!widget.product.inStock) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFfff7ed),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.accent.withValues(alpha: 0.3))),
                      child: Row(children: [
                        const Icon(Icons.warning_amber_rounded,
                          size: 16, color: AppColors.accent),
                        const SizedBox(width: 8),
                        Expanded(child: Text(
                          'This product is out of stock. Add stock before selling.',
                          style: GoogleFonts.inter(
                            fontSize: 12, fontWeight: FontWeight.w600,
                            color: AppColors.accentDark))),
                      ]),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Qty input
                  Text('Quantity to Add',
                    style: GoogleFonts.inter(
                      fontSize: 11, fontWeight: FontWeight.w700,
                      color: AppColors.textMuted, letterSpacing: 0.5)),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _err != null
                            ? AppColors.danger
                            : AppColors.primary.withValues(alpha: 0.25)),
                      boxShadow: [BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.06),
                        blurRadius: 8, offset: const Offset(0, 2))]),
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        child: Text('+',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18, fontWeight: FontWeight.w900,
                            color: AppColors.success))),
                      Container(width: 1, height: 20, color: AppColors.border),
                      Expanded(
                        child: TextField(
                          controller: _qtyCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'[-]'))],
                          autofocus: true,
                          onChanged: (_) { if (_err != null) setState(() => _err = null); },
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 22, fontWeight: FontWeight.w900,
                            color: AppColors.primary, letterSpacing: -0.5),
                          decoration: InputDecoration(
                            hintText: '0',
                            hintStyle: GoogleFonts.plusJakartaSans(
                              fontSize: 22, fontWeight: FontWeight.w900,
                              color: AppColors.borderLight),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            filled: true,
                            fillColor: Colors.transparent,
                            suffixText: widget.product.unit,
                            suffixStyle: GoogleFonts.inter(
                              fontSize: 13, fontWeight: FontWeight.w700,
                              color: AppColors.textMuted),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 14),
                            isDense: true),
                        ),
                      ),
                    ]),
                  ),
                  if (_err != null) ...[
                    const SizedBox(height: 6),
                    Text(_err!, style: GoogleFonts.inter(
                      fontSize: 11, color: AppColors.danger, fontWeight: FontWeight.w600)),
                  ],

                  const SizedBox(height: 16),
                  // Reason chips
                  Text('Reason',
                    style: GoogleFonts.inter(
                      fontSize: 11, fontWeight: FontWeight.w700,
                      color: AppColors.textMuted, letterSpacing: 0.5)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 7, runSpacing: 7,
                    children: _reasons.map((r) {
                      final sel = r == _reason;
                      return GestureDetector(
                        onTap: () => setState(() => _reason = r),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: sel ? AppColors.primary : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: sel ? AppColors.primary : AppColors.border,
                              width: sel ? 1.5 : 1)),
                          child: Text(r,
                            style: GoogleFonts.inter(
                              fontSize: 12, fontWeight: FontWeight.w700,
                              color: sel ? Colors.white : AppColors.textSecondary)),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 16),
                  // Optional notes
                  Text('Notes (optional)',
                    style: GoogleFonts.inter(
                      fontSize: 11, fontWeight: FontWeight.w700,
                      color: AppColors.textMuted, letterSpacing: 0.5)),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border)),
                    child: TextField(
                      controller: _notesCtrl,
                      maxLines: 2,
                      style: GoogleFonts.inter(
                        fontSize: 13, fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'e.g. Delivered from supplier',
                        hintStyle: GoogleFonts.inter(
                          fontSize: 13, color: AppColors.textMuted),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: true,
                        fillColor: Colors.transparent,
                        contentPadding: const EdgeInsets.all(12),
                        isDense: true),
                    ),
                  ),

                  const SizedBox(height: 24),
                  // Save button
                  GestureDetector(
                    onTap: _saving ? null : _save,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 54,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _saving
                              ? [AppColors.primaryMid, AppColors.primaryMid]
                              : [AppColors.primary, const Color(0xFF1a472a)],
                          begin: Alignment.topLeft, end: Alignment.bottomRight),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: _saving ? [] : [BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.35),
                          blurRadius: 14, offset: const Offset(0, 5))]),
                      child: Center(child: _saving
                          ? const SizedBox(width: 22, height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: Colors.white))
                          : Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.add_circle_rounded,
                                color: Colors.white, size: 20),
                              const SizedBox(width: 8),
                              Text('Add Stock',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 15, fontWeight: FontWeight.w900,
                                  color: Colors.white)),
                            ])),
                    ),
                  ),
                ]),
              ),

              // ── History tab ────────────────────────────────────────────────
              _histLoading
                  ? const Center(child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.primary))
                  : _history.isEmpty
                      ? Center(child: Column(
                          mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.history_rounded,
                              size: 40, color: AppColors.borderLight),
                            const SizedBox(height: 10),
                            Text('No adjustment history',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14, fontWeight: FontWeight.w700,
                                color: AppColors.textMuted)),
                          ]))
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                          itemCount: _history.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (_, i) {
                            final m   = _history[i];
                            final col = _typeColor(m['type'] as String? ?? '');
                            final before = (m['before_qty'] as num).toDouble();
                            final after  = (m['after_qty'] as num).toDouble();
                            final delta  = after - before;
                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.border),
                                boxShadow: AppShadows.sm),
                              child: Row(children: [
                                Container(
                                  width: 36, height: 36,
                                  decoration: BoxDecoration(
                                    color: col.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: col.withValues(alpha: 0.25))),
                                  child: Icon(
                                    delta >= 0
                                        ? Icons.arrow_upward_rounded
                                        : Icons.arrow_downward_rounded,
                                    size: 16, color: col)),
                                const SizedBox(width: 10),
                                Expanded(child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: col.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(6)),
                                        child: Text(
                                          _typeLabel(m['type'] as String? ?? ''),
                                          style: GoogleFonts.inter(
                                            fontSize: 9, fontWeight: FontWeight.w800,
                                            color: col))),
                                      const SizedBox(width: 6),
                                      Flexible(child: Text(
                                        m['branch_name'] as String? ?? '—',
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.inter(
                                          fontSize: 10, fontWeight: FontWeight.w600,
                                          color: AppColors.textMuted))),
                                    ]),
                                    const SizedBox(height: 4),
                                    Row(children: [
                                      Text(_fmtNum(before),
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 13, fontWeight: FontWeight.w700,
                                          color: AppColors.textMuted)),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 5),
                                        child: Icon(Icons.arrow_forward_rounded,
                                          size: 13, color: AppColors.textMuted)),
                                      Text(_fmtNum(after),
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 13, fontWeight: FontWeight.w900,
                                          color: AppColors.primary)),
                                      const Spacer(),
                                      Text(
                                        '${delta >= 0 ? '+' : ''}${_fmtNum(delta.abs())}',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 14, fontWeight: FontWeight.w900,
                                          color: delta >= 0
                                              ? AppColors.success
                                              : AppColors.danger)),
                                    ]),
                                    if ((m['note'] as String?)?.isNotEmpty == true) ...[
                                      const SizedBox(height: 3),
                                      Text(m['note'] as String,
                                        maxLines: 1, overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.inter(
                                          fontSize: 11, color: AppColors.textMuted,
                                          fontWeight: FontWeight.w500)),
                                    ],
                                  ]),
                                ),
                                const SizedBox(width: 8),
                                Column(crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                  Text(
                                    _fmtDate(m['created_at'] as String? ?? ''),
                                    style: GoogleFonts.inter(
                                      fontSize: 10, color: AppColors.textMuted,
                                      fontWeight: FontWeight.w500)),
                                  const SizedBox(height: 2),
                                  Text(
                                    m['adjusted_by'] as String? ?? '—',
                                    style: GoogleFonts.inter(
                                      fontSize: 10, fontWeight: FontWeight.w700,
                                      color: AppColors.primary)),
                                ]),
                              ]),
                            );
                          },
                        ),
            ],
          ),
        ),
      ]),
    );
  }
}

String _fmtDate(String iso) {
  if (iso.length < 10) return iso;
  try {
    final d = DateTime.parse(iso);
    final months = ['','Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${d.day} ${months[d.month]}';
  } catch (_) { return iso.substring(0, 10); }
}

// ── Price edit sheet ──────────────────────────────────────────────────────────
class _PriceEditSheet extends StatefulWidget {
  final String productName;
  final double currentPrice;
  final double originalPrice;
  final String currency;

  const _PriceEditSheet({
    required this.productName, required this.currentPrice,
    required this.originalPrice, required this.currency,
  });

  @override
  State<_PriceEditSheet> createState() => _PriceEditSheetState();
}

class _PriceEditSheetState extends State<_PriceEditSheet> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: _fmtMoney(widget.currentPrice));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  void _confirm() {
    final v = double.tryParse(_ctrl.text.replaceAll(',', ''));
    if (v == null || v <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Enter a valid price'),
        backgroundColor: AppColors.danger,
        behavior: SnackBarBehavior.floating));
      return;
    }
    Navigator.pop(context, v);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Handle + header
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF061410), AppColors.primary, Color(0xFF163522)],
              begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
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
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: AppColors.accent.withValues(alpha: 0.3))),
                child: const Icon(Icons.edit_rounded, color: AppColors.accent, size: 19)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Edit Price',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 17, fontWeight: FontWeight.w900,
                    color: Colors.white, letterSpacing: -0.4)),
                Text(widget.productName,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 11, color: Colors.white.withValues(alpha: 0.45),
                    fontWeight: FontWeight.w500)),
              ])),
              // Reset to original
              if (widget.currentPrice != widget.originalPrice)
                GestureDetector(
                  onTap: () {
                    _ctrl.text = widget.originalPrice.toInt().toString();
                    setState(() {});
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.2))),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.refresh_rounded, size: 12,
                        color: Colors.white.withValues(alpha: 0.7)),
                      const SizedBox(width: 4),
                      Text('Reset',
                        style: GoogleFonts.inter(
                          fontSize: 11, fontWeight: FontWeight.w700,
                          color: Colors.white.withValues(alpha: 0.7))),
                    ]),
                  ),
                ),
            ]),
          ]),
        ),

        Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [

        // Original price hint
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.12))),
          child: Row(children: [
            Icon(Icons.info_outline_rounded, size: 14, color: AppColors.primary.withValues(alpha: 0.6)),
            const SizedBox(width: 8),
            Text('Standard price: ${widget.currency} ${_fmtNum(widget.originalPrice)}',
              style: GoogleFonts.inter(
                fontSize: 12, fontWeight: FontWeight.w600,
                color: AppColors.textSecondary)),
          ]),
        ),
        const SizedBox(height: 16),

        // Price input
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
            boxShadow: [BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.08),
              blurRadius: 8, offset: const Offset(0, 2))]),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Text(widget.currency,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13, fontWeight: FontWeight.w800,
                  color: AppColors.textMuted))),
            Container(width: 1, height: 20, color: AppColors.border),
            Expanded(
              child: TextField(
                controller: _ctrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: false),
                inputFormatters: [_MoneyInputFormatter()],
                autofocus: true,
                onSubmitted: (_) => _confirm(),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22, fontWeight: FontWeight.w900,
                  color: AppColors.primary, letterSpacing: -0.5),
                decoration: InputDecoration(
                  hintText: '0',
                  hintStyle: GoogleFonts.plusJakartaSans(
                    fontSize: 22, fontWeight: FontWeight.w900,
                    color: AppColors.borderLight),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: true,
                  fillColor: Colors.transparent,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  isDense: true),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 20),

        // Buttons
        Row(children: [
          Expanded(
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border)),
                child: Center(child: Text('Cancel',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14, fontWeight: FontWeight.w800,
                    color: AppColors.textSecondary)))),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: GestureDetector(
              onTap: _confirm,
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.accent, AppColors.accentDark],
                    begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.35),
                    blurRadius: 12, offset: const Offset(0, 4))]),
                child: Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.check_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 7),
                  Text('Apply Price',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white)),
                ])),
              ),
            ),
          ),
        ]),
        ])), // end Padding body + inner Column
      ]),
    );
  }
}
