import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
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
  const PosScreen({super.key, required this.user});
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
  Timer? _debounce;
  late AnimationController _cartBadgeCtrl;

  @override
  void initState() {
    super.initState();
    _cartBadgeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _loadProducts('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _cartBadgeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProducts(String q) async {
    setState(() => _loading = true);
    try {
      final products = await ApiService.searchProducts(q);
      final cats = ['All', ...{...products.map((p) => p.categoryName)}];
      if (mounted) setState(() { _products = products; _categories = cats; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
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
    HapticFeedback.lightImpact();
    setState(() {
      final idx = _cart.indexWhere((c) => c.product.id == p.id);
      if (idx >= 0) {
        if (_cart[idx].quantity < p.qty) {
          _cart[idx].quantity += 1;
        } else {
          _showSnack('Only ${p.qty.toStringAsFixed(0)} ${p.unit} in stock');
          return;
        }
      } else {
        if (!p.inStock) { _showSnack('Out of stock'); return; }
        _cart.add(CartItem(product: p));
      }
    });
    _cartBadgeCtrl.forward(from: 0);
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
      }
    });
  }

  int get _cartCount => _cart.fold(0, (s, c) => s + c.quantity.toInt());
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
        onRemove: _removeFromCart,
        onQtyChanged: _updateQty,
        onSaleComplete: (result) {
          setState(() => _cart.clear());
          Navigator.pop(context);
          Navigator.push(context,
            MaterialPageRoute(builder: (_) => ReceiptScreen(saleResult: result, user: widget.user)));
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18, fontWeight: FontWeight.w900,
                color: Colors.white, letterSpacing: -0.4)),
            Text('${widget.user.shopName}  ·  ${widget.user.name}',
              style: GoogleFonts.inter(
                fontSize: 11, color: Colors.white.withValues(alpha: 0.45),
                fontWeight: FontWeight.w500)),
          ]),
        ),
        if (_cart.isNotEmpty)
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
                const SizedBox(width: 5),
                Text('$_cartCount',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13, fontWeight: FontWeight.w900, color: Colors.white)),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  width: 1, height: 12,
                  color: Colors.white.withValues(alpha: 0.35)),
                Text('${widget.user.currency} ${_fmtNum(_cartTotal)}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
              ]),
            ),
          ),
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
    if (_loading) {
      return GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, childAspectRatio: 0.75,
          crossAxisSpacing: 10, mainAxisSpacing: 10),
        itemCount: 6,
        itemBuilder: (_, __) => Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border)),
          child: const _ShimmerCard(),
        ),
      );
    }
    final prods = _filtered;
    if (prods.isEmpty) {
      return Center(
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
              fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Text('Try a different search or category',
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
        ]),
      );
    }
    return GridView.builder(
      padding: EdgeInsets.fromLTRB(12, 12, 12, _cart.isNotEmpty ? 90 : 20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, childAspectRatio: 0.72,
        crossAxisSpacing: 10, mainAxisSpacing: 10),
      itemCount: prods.length,
      itemBuilder: (_, i) => _ProductCard(
        product: prods[i],
        cartQty: _cart.where((c) => c.product.id == prods[i].id)
            .fold(0.0, (s, c) => s + c.quantity),
        currency: widget.user.currency,
        onAdd: () => _addToCart(prods[i]),
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
  final VoidCallback onAdd;

  const _ProductCard({
    required this.product, required this.cartQty,
    required this.currency, required this.onAdd,
  });

  @override
  State<_ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<_ProductCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressCtrl;
  late Animation<double> _scaleAnim;
  bool _pressed = false;

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

    return GestureDetector(
      onTapDown: outOfStock ? null : (_) {
        setState(() => _pressed = true);
        _pressCtrl.forward();
      },
      onTapUp: outOfStock ? null : (_) {
        setState(() => _pressed = false);
        _pressCtrl.reverse();
        widget.onAdd();
      },
      onTapCancel: outOfStock ? null : () {
        setState(() => _pressed = false);
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
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar
                  Row(children: [
                    Container(
                      width: 52, height: 52,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: outOfStock
                              ? [const Color(0xFFe2e8f0), const Color(0xFFf1f5f9)]
                              : avatarColors,
                          begin: Alignment.topLeft, end: Alignment.bottomRight),
                        borderRadius: BorderRadius.circular(14)),
                      child: Center(
                        child: Text(widget.product.name.substring(0, 1).toUpperCase(),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 22, fontWeight: FontWeight.w900,
                            color: outOfStock ? AppColors.textMuted : Colors.white)),
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
                        child: Text('${widget.product.qty.toStringAsFixed(0)}',
                          style: GoogleFonts.inter(
                            fontSize: 10, fontWeight: FontWeight.w800,
                            color: widget.product.qty <= 5
                                ? AppColors.warning : AppColors.successDark))),
                  ]),
                  const SizedBox(height: 10),
                  // Name
                  Text(widget.product.name,
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13, fontWeight: FontWeight.w800,
                      color: outOfStock ? AppColors.textMuted : AppColors.textPrimary,
                      height: 1.25)),
                  const SizedBox(height: 3),
                  Text(widget.product.categoryName,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 10),
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
                  const SizedBox(height: 10),
                  // Price
                  Text('${widget.currency} ${_fmtNum(widget.product.sellingPrice)}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15, fontWeight: FontWeight.w900,
                      color: outOfStock ? AppColors.textMuted : AppColors.primary,
                      letterSpacing: -0.4)),
                  const SizedBox(height: 10),
                  // Add button
                  Container(
                    width: double.infinity,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: outOfStock
                          ? null
                          : LinearGradient(
                              colors: inCart
                                  ? [AppColors.primary, const Color(0xFF1a472a)]
                                  : [const Color(0xFFf0fdf4), const Color(0xFFdcfce7)],
                              begin: Alignment.topLeft, end: Alignment.bottomRight),
                      color: outOfStock ? AppColors.borderLight : null,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: outOfStock
                            ? AppColors.border
                            : inCart
                                ? AppColors.primary
                                : AppColors.success.withValues(alpha: 0.4))),
                    child: Center(
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(
                          outOfStock ? Icons.block_rounded : Icons.add_rounded,
                          size: 14,
                          color: outOfStock
                              ? AppColors.textMuted
                              : inCart ? Colors.white : AppColors.success),
                        const SizedBox(width: 5),
                        Text(
                          outOfStock ? 'Out of Stock' : inCart ? 'Add More' : 'Add to Cart',
                          style: GoogleFonts.inter(
                            fontSize: 11, fontWeight: FontWeight.w700,
                            color: outOfStock
                                ? AppColors.textMuted
                                : inCart ? Colors.white : AppColors.success)),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 12),
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
                    child: Text('${widget.cartQty.toInt()}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11, fontWeight: FontWeight.w900,
                        color: Colors.white))))),
            // Out of stock overlay
            if (outOfStock)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(18)))),
          ]),
        ),
      ),
    );
  }
}

// ── Cart Bottom Sheet ─────────────────────────────────────────────────────────
class _CartSheet extends StatefulWidget {
  final List<CartItem> cart;
  final AuthUser user;
  final Function(int) onRemove;
  final Function(int, double) onQtyChanged;
  final Function(Map<String, dynamic>) onSaleComplete;

  const _CartSheet({
    required this.cart, required this.user,
    required this.onRemove, required this.onQtyChanged,
    required this.onSaleComplete,
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

  static const _methods = [
    ('cash',      'Cash',          Icons.payments_rounded),
    ('mpesa',     'M-Pesa',        Icons.phone_android_rounded),
    ('tigopesa',  'Tigo Pesa',     Icons.phone_android_rounded),
    ('airtel',    'Airtel',        Icons.phone_android_rounded),
    ('bank',      'Bank',          Icons.account_balance_rounded),
    ('credit',    'Credit',        Icons.credit_card_rounded),
  ];

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

  @override
  void initState() {
    super.initState();
    _cashCtrl.text = _fmtMoney(_total);
  }

  @override
  void dispose() {
    _discountCtrl.dispose(); _cashCtrl.dispose();
    _custNameCtrl.dispose(); _custPhoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkout() async {
    if (widget.cart.isEmpty) return;
    setState(() => _loading = true);
    try {
      final paidAmount = _payMethod == 'cash' ? _cashReceived : _total;
      final result = await ApiService.createSale(
        items: widget.cart,
        paymentMethod: _payMethod,
        paidAmount: paidAmount,
        discount: _discount,
        customerName: _custNameCtrl.text.trim(),
        customerPhone: _custPhoneCtrl.text.trim(),
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
    return DraggableScrollableSheet(
      initialChildSize: 0.94,
      maxChildSize: 0.97,
      minChildSize: 0.5,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        child: Column(children: [
          // ── Dark premium header ──────────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF061410), AppColors.primary, Color(0xFF163522)],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            child: Column(children: [
              // Handle
              Center(
                child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Row(children: [
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
                    onRemove: () => setState(() { widget.onRemove(i); _syncCash(); }),
                    onInc: () => setState(() { widget.onQtyChanged(i, item.quantity + 1); _syncCash(); }),
                    onDec: () => setState(() { widget.onQtyChanged(i, item.quantity - 1); _syncCash(); }),
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
                // Payment method grid
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 2.2,
                  children: _methods.map((entry) {
                    final (id, label, icon) = entry;
                    final sel = _payMethod == id;
                    return GestureDetector(
                      onTap: () => setState(() {
                        _payMethod = id;
                        if (id == 'cash') {
                          _cashCtrl.text = _fmtMoney(_total);
                        }
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        decoration: BoxDecoration(
                          color: sel ? AppColors.primary : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: sel
                                ? AppColors.primary
                                : AppColors.border,
                            width: sel ? 1.5 : 1),
                          boxShadow: sel ? [BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.2),
                            blurRadius: 8, offset: const Offset(0, 2))] : [],
                        ),
                        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(icon, size: 13,
                            color: sel ? Colors.white : AppColors.textMuted),
                          const SizedBox(width: 5),
                          Text(label, style: GoogleFonts.inter(
                            fontSize: 11, fontWeight: FontWeight.w700,
                            color: sel ? Colors.white : AppColors.textSecondary)),
                        ]),
                      ),
                    );
                  }).toList(),
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
      ),
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
  final VoidCallback onRemove, onInc, onDec;

  const _CartItemRow({
    required this.item, required this.currency,
    required this.onRemove, required this.onInc, required this.onDec,
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
            const SizedBox(height: 2),
            Text('$currency ${_fmtNum(item.price)} / ${item.product.unit}',
              style: GoogleFonts.inter(
                fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w500)),
          ]),
        ),
        const SizedBox(width: 8),
        // Qty controls
        Row(mainAxisSize: MainAxisSize.min, children: [
          _qtyBtn(Icons.remove_rounded, onDec, item.quantity <= 1),
          Container(
            width: 36, alignment: Alignment.center,
            child: Text('${item.quantity.toInt()}',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15, fontWeight: FontWeight.w900,
                color: AppColors.textPrimary))),
          _qtyBtn(Icons.add_rounded, onInc, false),
        ]),
        const SizedBox(width: 10),
        // Total + delete
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${_fmtNum(item.total)}',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14, fontWeight: FontWeight.w900,
              color: AppColors.primary, letterSpacing: -0.3)),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: AppColors.dangerBg,
                borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.delete_outline_rounded,
                size: 14, color: AppColors.danger))),
        ]),
      ]),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap, bool isDim) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30, height: 30,
        decoration: BoxDecoration(
          color: isDim ? AppColors.borderLight : AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: isDim ? AppColors.border : AppColors.primary.withValues(alpha: 0.2))),
        child: Icon(icon, size: 13,
          color: isDim ? AppColors.textMuted : AppColors.primary)),
    );
  }
}

String _fmtNum(double v) {
  if (v == v.truncateToDouble()) return v.toInt().toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
  return v.toStringAsFixed(0).replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
}
