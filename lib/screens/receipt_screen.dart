import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';

class ReceiptScreen extends StatefulWidget {
  final Map<String, dynamic> saleResult;
  final AuthUser user;

  const ReceiptScreen({super.key, required this.saleResult, required this.user});

  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen>
    with TickerProviderStateMixin {
  final _screenshotCtrl = ScreenshotController();
  bool _saving = false;
  bool _sharing = false;
  late AnimationController _checkCtrl;
  late AnimationController _slideCtrl;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _checkCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _slideCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic));
    _fadeAnim = CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut);

    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) {
        _checkCtrl.forward();
        _slideCtrl.forward();
      }
    });
  }

  @override
  void dispose() {
    _checkCtrl.dispose();
    _slideCtrl.dispose();
    super.dispose();
  }

  Map<String, dynamic> get _r => widget.saleResult;
  List<dynamic> get _items => _r['cart'] as List? ?? [];
  double get _subtotal => (_r['subtotal'] as num?)?.toDouble() ?? 0;
  double get _discount => (_r['discount'] as num?)?.toDouble() ?? 0;
  double get _total => (_r['total'] as num?)?.toDouble() ?? 0;
  double get _change => (_r['change'] as num?)?.toDouble() ?? 0;
  String get _invoiceNo => _r['invoice_no']?.toString() ?? '';
  String get _payMethod => _r['payment_method']?.toString() ?? 'cash';
  String get _currency => _r['currency']?.toString() ?? widget.user.currency;
  String get _shopName => _r['shop_name']?.toString() ?? widget.user.shopName;
  String get _cashier => _r['cashier']?.toString() ?? widget.user.name;
  String? get _custName =>
      (_r['customer_name'] as String?)?.isNotEmpty == true ? _r['customer_name'] as String : null;

  // ── Build a standalone receipt widget for off-screen capture ─────────────
  Widget _receiptWidget() => Material(
    color: Colors.white,
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: _buildReceiptCard(),
    ),
  );

  // ── Capture off-screen, independent of animations/scroll ─────────────────
  Future<File?> _captureToFile(Directory dir) async {
    try {
      final bytes = await _screenshotCtrl.captureFromWidget(
        _receiptWidget(),
        context: context,           // provides Directionality, MediaQuery, Theme
        pixelRatio: 2.0,
        delay: const Duration(milliseconds: 300),
      );
      if (bytes.isEmpty) return null;
      final fileName = 'receipt_${_invoiceNo.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_')}.png';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes);
      debugPrint('[receipt] saved ${bytes.length} bytes → ${file.path}');
      return file;
    } catch (e) {
      debugPrint('[receipt capture] $e');
      return null;
    }
  }

  Future<void> _shareReceipt() async {
    setState(() => _sharing = true);
    try {
      final dir = await getTemporaryDirectory();
      final file = await _captureToFile(dir);
      if (file == null) { _showSnack('Capture failed — try Save'); return; }

      // On iOS only pass files — combining text+files breaks UIActivityViewController
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png', name: file.uri.pathSegments.last)],
        subject: 'Receipt $_invoiceNo — $_shopName',
      );
    } catch (e) {
      debugPrint('[share error] $e');
      if (mounted) _showSnack('Share error: $e');
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _saveReceipt() async {
    setState(() => _saving = true);
    try {
      final dir = await getApplicationDocumentsDirectory();
      final receiptsDir = Directory('${dir.path}/receipts');
      await receiptsDir.create(recursive: true);
      final file = await _captureToFile(receiptsDir);
      if (file == null) { _showSnack('Could not capture receipt'); return; }
      HapticFeedback.heavyImpact();
      if (mounted) _showSnack('Saved to Documents/receipts/', success: true);
    } catch (e) {
      if (mounted) _showSnack('Save failed: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showSnack(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: success ? AppColors.success : AppColors.danger,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
    ));
  }

  String _payLabel(String method) {
    const labels = {
      'cash': 'Cash', 'mpesa': 'M-Pesa', 'tigopesa': 'Tigo Pesa',
      'airtel': 'Airtel Money', 'bank': 'Bank Transfer', 'credit': 'Credit',
    };
    return labels[method] ?? method;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(children: [
        // Gradient header strip
        Positioned(top: 0, left: 0, right: 0, height: 200,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF061410), Color(0xFF0F2D1A)],
                begin: Alignment.topLeft, end: Alignment.bottomRight)),
          )),

        SafeArea(
          child: Column(children: [
            _buildTopBar(),
            Expanded(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    child: Column(children: [
                      _buildSuccessBadge(),
                      const SizedBox(height: 16),
                      _buildReceiptCard(),
                      const SizedBox(height: 20),
                      _buildActionButtons(),
                      const SizedBox(height: 16),
                      _buildNewSaleButton(),
                    ]),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  // ── Top bar ───────────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Row(children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2))),
            child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 18),
          ),
        ),
        const SizedBox(width: 12),
        Text('Receipt',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 17, fontWeight: FontWeight.w900, color: Colors.white)),
      ]),
    );
  }

  // ── Success badge ─────────────────────────────────────────────────────────
  Widget _buildSuccessBadge() {
    return AnimatedBuilder(
      animation: _checkCtrl,
      builder: (_, __) => Transform.scale(
        scale: Curves.elasticOut.transform(_checkCtrl.value.clamp(0.0, 1.0)),
        child: Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
            color: AppColors.success,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(
              color: AppColors.success.withValues(alpha: 0.4),
              blurRadius: 24, spreadRadius: 4)]),
          child: const Icon(Icons.check_rounded, color: Colors.white, size: 38),
        ),
      ),
    );
  }

  // ── Receipt card ──────────────────────────────────────────────────────────
  Widget _buildReceiptCard() {
    return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: AppShadows.lg,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Header
          Container(
            padding: const EdgeInsets.all(22),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF061410), Color(0xFF0F2D1A), Color(0xFF163522)],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
            child: Column(children: [
              Text(_shopName,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
              const SizedBox(height: 4),
              Text('Sales Receipt',
                style: GoogleFonts.inter(
                  fontSize: 11, color: Colors.white.withValues(alpha: 0.5),
                  letterSpacing: 1.5, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                _receiptMeta('Invoice', _invoiceNo),
                _receiptMeta('Date', _formatDate(DateTime.now())),
                _receiptMeta('Cashier', _cashier.split(' ').first),
              ]),
            ]),
          ),

          // Dashed divider
          _dashedDivider(),

          // Customer row
          if (_custName != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 4),
              child: Row(children: [
                const Icon(Icons.person_outline_rounded, size: 14, color: AppColors.textMuted),
                const SizedBox(width: 6),
                Text('Customer: ', style: GoogleFonts.inter(
                  fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w500)),
                Text(_custName!, style: GoogleFonts.inter(
                  fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
              ]),
            ),

          // Items
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
            child: Column(children: [
              // Header row
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  Expanded(child: Text('Item',
                    style: GoogleFonts.inter(
                      fontSize: 10, fontWeight: FontWeight.w700,
                      color: AppColors.textMuted, letterSpacing: 0.5))),
                  SizedBox(width: 36, child: Text('Qty',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 10, fontWeight: FontWeight.w700,
                      color: AppColors.textMuted, letterSpacing: 0.5))),
                  SizedBox(width: 70, child: Text('Price',
                    textAlign: TextAlign.right,
                    style: GoogleFonts.inter(
                      fontSize: 10, fontWeight: FontWeight.w700,
                      color: AppColors.textMuted, letterSpacing: 0.5))),
                  SizedBox(width: 76, child: Text('Total',
                    textAlign: TextAlign.right,
                    style: GoogleFonts.inter(
                      fontSize: 10, fontWeight: FontWeight.w700,
                      color: AppColors.textMuted, letterSpacing: 0.5))),
                ]),
              ),
              const Divider(height: 1, color: AppColors.border),
              const SizedBox(height: 8),
              ..._items.map<Widget>((item) {
                final name = item['name']?.toString() ?? '';
                final qty = (item['qty'] as num?)?.toDouble() ?? 1;
                final price = (item['price'] as num?)?.toDouble() ?? 0;
                final total = (item['total'] as num?)?.toDouble() ?? (qty * price);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(children: [
                    Expanded(child: Text(name,
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 12, fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary))),
                    SizedBox(width: 36, child: Text('${qty.toInt()}',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 12, color: AppColors.textSecondary))),
                    SizedBox(width: 70, child: Text(_fmtNum(price),
                      textAlign: TextAlign.right,
                      style: GoogleFonts.inter(
                        fontSize: 11, color: AppColors.textSecondary))),
                    SizedBox(width: 76, child: Text(_fmtNum(total),
                      textAlign: TextAlign.right,
                      style: GoogleFonts.inter(
                        fontSize: 12, fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary))),
                  ]),
                );
              }),
            ]),
          ),

          // Dashed divider
          _dashedDivider(),

          // Totals section
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
            child: Column(children: [
              if (_discount > 0) ...[
                _totalRow('Subtotal', _subtotal),
                const SizedBox(height: 6),
                _totalRow('Discount', -_discount, isNeg: true),
                const SizedBox(height: 10),
                const Divider(height: 1, color: AppColors.border),
                const SizedBox(height: 10),
              ],
              Row(children: [
                Text('TOTAL',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15, fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary, letterSpacing: -0.3)),
                const Spacer(),
                Text('$_currency ${_fmtNum(_total)}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20, fontWeight: FontWeight.w900,
                    color: AppColors.primary)),
              ]),
              const SizedBox(height: 12),

              // Payment info chips
              Row(children: [
                _chip(_payLabel(_payMethod), Icons.payments_rounded, AppColors.infoBg, AppColors.info),
                if (_change > 0) ...[
                  const SizedBox(width: 8),
                  _chip('Change: $_currency ${_fmtNum(_change)}',
                    Icons.change_circle_outlined, AppColors.successBg, AppColors.successDark),
                ],
              ]),
            ]),
          ),

          // Footer
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
              border: Border(top: BorderSide(color: AppColors.border))),
            child: Column(children: [
              Text('Thank you for your purchase!',
                style: GoogleFonts.inter(
                  fontSize: 12, fontWeight: FontWeight.w600,
                  color: AppColors.textMuted)),
              const SizedBox(height: 2),
              Text('Powered by MDSPro',
                style: GoogleFonts.inter(
                  fontSize: 10, color: AppColors.textMuted.withValues(alpha: 0.6))),
            ]),
          ),
        ]),
    );
  }

  // ── Action buttons ────────────────────────────────────────────────────────
  Widget _buildActionButtons() {
    return Row(children: [
      Expanded(
        child: _actionBtn(
          label: _saving ? 'Saving…' : 'Save',
          icon: Icons.download_rounded,
          loading: _saving,
          onTap: _saving ? null : _saveReceipt,
          color: AppColors.primary,
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: _actionBtn(
          label: _sharing ? 'Sharing…' : 'Share',
          icon: Icons.share_rounded,
          loading: _sharing,
          onTap: _sharing ? null : _shareReceipt,
          color: AppColors.accent,
        ),
      ),
    ]);
  }

  Widget _actionBtn({
    required String label,
    required IconData icon,
    required bool loading,
    required VoidCallback? onTap,
    required Color color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: 12, offset: const Offset(0, 4))]),
        child: Center(
          child: loading
              ? const SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(icon, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text(label, style: GoogleFonts.plusJakartaSans(
                    fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
                ]),
        ),
      ),
    );
  }

  // ── New sale button ───────────────────────────────────────────────────────
  Widget _buildNewSaleButton() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.popUntil(context, (route) => route.isFirst);
      },
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: AppShadows.sm,
        ),
        child: Center(
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.add_shopping_cart_rounded,
              color: AppColors.primary, size: 18),
            const SizedBox(width: 8),
            Text('New Sale',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14, fontWeight: FontWeight.w800,
                color: AppColors.primary)),
          ]),
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  Widget _receiptMeta(String label, String value) => Column(children: [
    Text(label, style: GoogleFonts.inter(
      fontSize: 9, color: Colors.white.withValues(alpha: 0.4),
      letterSpacing: 0.5, fontWeight: FontWeight.w600)),
    const SizedBox(height: 3),
    Text(value, style: GoogleFonts.plusJakartaSans(
      fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white)),
  ]);

  Widget _dashedDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(children: List.generate(40, (_) => Expanded(
        child: Container(
          height: 1,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          color: AppColors.border,
        ),
      ))),
    );
  }

  Widget _totalRow(String label, double value, {bool isNeg = false}) =>
      Row(children: [
        Text(label, style: GoogleFonts.inter(
          fontSize: 13, color: AppColors.textSecondary)),
        const Spacer(),
        Text('${isNeg ? '-' : ''}$_currency ${_fmtNum(value.abs())}',
          style: GoogleFonts.inter(
            fontSize: 13, fontWeight: FontWeight.w700,
            color: isNeg ? AppColors.danger : AppColors.textPrimary)),
      ]);

  Widget _chip(String label, IconData icon, Color bg, Color fg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: fg),
      const SizedBox(width: 4),
      Text(label, style: GoogleFonts.inter(
        fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
    ]),
  );

  String _formatDate(DateTime d) =>
      '${d.day}/${d.month}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

String _fmtNum(double v) {
  if (v == v.truncateToDouble()) return v.toInt().toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
  return v.toStringAsFixed(0).replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
}
