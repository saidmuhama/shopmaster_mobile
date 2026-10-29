import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../utils/formatter.dart';

// ─────────────────────────────────────────────────────────────────────────────
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
  bool _saving   = false;
  bool _sharing  = false;
  bool _printing = false;

  late AnimationController _checkCtrl;
  late AnimationController _slideCtrl;
  late Animation<Offset>   _slideAnim;
  late Animation<double>   _fadeAnim;

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
      if (mounted) { _checkCtrl.forward(); _slideCtrl.forward(); }
    });
  }

  @override
  void dispose() { _checkCtrl.dispose(); _slideCtrl.dispose(); super.dispose(); }

  // ── Data accessors ────────────────────────────────────────────────────────
  Map<String, dynamic> get _r => widget.saleResult;
  List<dynamic> get _items  => _r['cart'] as List? ?? [];
  double get _subtotal      => (_r['subtotal']  as num?)?.toDouble() ?? 0;
  double get _discount      => (_r['discount']  as num?)?.toDouble() ?? 0;
  double get _total         => (_r['total']     as num?)?.toDouble() ?? 0;
  double get _paidAmount    => (_r['paid_amount'] as num?)?.toDouble() ?? _total;
  double get _change        => (_r['change']    as num?)?.toDouble() ?? 0;
  String get _invoiceNo     => _r['invoice_no']?.toString() ?? '';
  String get _payMethod     => _r['payment_method']?.toString() ?? 'cash';
  String get _currency      => _r['currency']?.toString() ?? widget.user.currency;
  String get _shopName      => _r['shop_name']?.toString() ?? widget.user.shopName;
  String get _cashier       => _r['cashier']?.toString() ?? widget.user.name;
  String get _custName      => (_r['customer_name'] as String?)?.isNotEmpty == true
      ? _r['customer_name'] as String : 'Cash Customer';
  String get _custPhone     => (_r['customer_phone'] as String?)?.isNotEmpty == true
      ? _r['customer_phone'] as String : 'N/A';
  String? get _tin          => _r['tin'] as String?;
  String get _qrData        => '$_invoiceNo|$_currency ${_fmtN(_total)}|$_shopName';

  String _payLabel(String m) => const {
    'cash': 'Cash', 'mpesa': 'M-Pesa', 'tigopesa': 'Tigo Pesa',
    'airtel': 'Airtel Money', 'bank': 'Bank Transfer', 'credit': 'Credit',
  }[m] ?? m;

  String _now() {
    final d = DateTime.now();
    return '${d.day.toString().padLeft(2,'0')}-${d.month.toString().padLeft(2,'0')}-${d.year} '
        '${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';
  }

  // ── Screenshot capture ────────────────────────────────────────────────────
  Future<File?> _captureToFile(Directory dir) async {
    try {
      final bytes = await _screenshotCtrl.captureFromWidget(
        Material(color: Colors.white, child: Padding(
          padding: const EdgeInsets.all(16), child: _ThermalReceiptPaper(
            shopName: _shopName, tin: _tin, invoiceNo: _invoiceNo,
            dateStr: _now(), custName: _custName, custPhone: _custPhone,
            cashier: _cashier, items: _items, subtotal: _subtotal,
            discount: _discount, total: _total, paidAmount: _paidAmount,
            change: _change, payMethod: _payMethod, currency: _currency,
            qrData: _qrData, forPrint: false,
          ))),
        context: context, pixelRatio: 3.0,
        delay: const Duration(milliseconds: 300),
      );
      if (bytes.isEmpty) return null;
      final name = 'receipt_${_invoiceNo.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_')}.png';
      final file = File('${dir.path}/$name');
      await file.writeAsBytes(bytes);
      return file;
    } catch (e) { debugPrint('[receipt] $e'); return null; }
  }

  Future<void> _shareReceipt() async {
    setState(() => _sharing = true);
    try {
      final dir  = await getTemporaryDirectory();
      final file = await _captureToFile(dir);
      if (file == null) { _snack('Capture failed'); return; }
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png', name: file.uri.pathSegments.last)],
        subject: 'Receipt $_invoiceNo — $_shopName',
      );
    } catch (e) { _snack('Share error: $e'); }
    finally { if (mounted) setState(() => _sharing = false); }
  }

  Future<void> _saveReceipt() async {
    setState(() => _saving = true);
    try {
      final dir      = await getApplicationDocumentsDirectory();
      final saveDir  = Directory('${dir.path}/receipts');
      await saveDir.create(recursive: true);
      final file = await _captureToFile(saveDir);
      if (file == null) { _snack('Could not capture receipt'); return; }
      HapticFeedback.heavyImpact();
      _snack('Saved to Documents/receipts/', success: true);
    } catch (e) { _snack('Save failed: $e'); }
    finally { if (mounted) setState(() => _saving = false); }
  }

  // ── Bluetooth printing ────────────────────────────────────────────────────
  Future<void> _printReceipt() async {
    setState(() => _printing = true);
    try {
      final devices = await PrintBluetoothThermal.pairedBluetooths;
      if (!mounted) return;
      if (devices.isEmpty) {
        _snack('No paired Bluetooth printers found. Pair your printer in Android settings first.');
        return;
      }
      // Show device picker
      final chosen = await showModalBottomSheet<BluetoothInfo>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (_) => _PrinterPickerSheet(devices: devices),
      );
      if (chosen == null || !mounted) return;

      _snack('Connecting to ${chosen.name}…');
      final connected = await PrintBluetoothThermal.connect(
          macPrinterAddress: chosen.macAdress);
      if (!connected) { _snack('Could not connect to ${chosen.name}'); return; }

      final bytes = _buildEscPos();
      await PrintBluetoothThermal.writeBytes(bytes);
      await Future.delayed(const Duration(milliseconds: 500));
      await PrintBluetoothThermal.disconnect;
      _snack('Printed successfully!', success: true);
      HapticFeedback.heavyImpact();
    } catch (e) { _snack('Print error: $e'); }
    finally { if (mounted) setState(() => _printing = false); }
  }

  // ── ESC/POS byte builder (58mm = 32 chars) ────────────────────────────────
  List<int> _buildEscPos() {
    final b = <int>[];
    const lf = 0x0A;
    const w  = 32; // chars per line on 58mm paper

    void add(List<int> v) => b.addAll(v);
    void text(String s)   => b.addAll(s.codeUnits);
    void nl([int n = 1])  { for (var i = 0; i < n; i++) b.add(lf); }

    void center(String s, {int width = w}) {
      final pad = ((width - s.length) / 2).floor();
      text((' ' * pad.clamp(0, width)) + s.substring(0, s.length.clamp(0, width)));
      nl();
    }

    void leftRight(String l, String r, {int width = w}) {
      final gap = width - l.length - r.length;
      text(l + (' ' * gap.clamp(1, width)) + r.substring(0, r.length.clamp(0, width - l.length - 1)));
      nl();
    }

    String fmtLine(int idx, String name, String qty, String price, String total) {
      // Format: "#. Name          Qty  Price   Total"
      final num  = '${idx + 1}.';
      final qtyW = 3;
      final priceW = 7;
      final totalW = 8;
      final nameW = w - num.length - 1 - qtyW - priceW - totalW;
      final nm = name.length > nameW ? name.substring(0, nameW) : name.padRight(nameW);
      return '$num $nm${qty.padLeft(qtyW)}${price.padLeft(priceW)}${total.padLeft(totalW)}';
    }

    // Initialize
    add([0x1B, 0x40]);
    // Center align
    add([0x1B, 0x61, 0x01]);
    // Bold + double size
    add([0x1B, 0x45, 0x01, 0x1D, 0x21, 0x11]);
    text(_shopName.toUpperCase()); nl();
    // Reset size & bold
    add([0x1D, 0x21, 0x00, 0x1B, 0x45, 0x00]);
    if (_tin != null && _tin!.isNotEmpty) { center('TIN: $_tin'); }
    nl();

    // Dashed separator
    text('-' * w); nl();

    // Left align
    add([0x1B, 0x61, 0x00]);
    leftRight('Invoice No.', _invoiceNo);
    leftRight('Date', _now());
    leftRight('Customer', _custName.length > 16 ? '${_custName.substring(0, 13)}...' : _custName);
    leftRight('Phone', _custPhone);
    leftRight('Created by:', _cashier);
    text('-' * w); nl();

    // Items header
    final hdr = fmtLine(-1, 'Product', 'Qty', 'Price', 'Total');
    add([0x1B, 0x45, 0x01]); // bold
    text(hdr); nl();
    add([0x1B, 0x45, 0x00]); // bold off
    text('-' * w); nl();

    // Items
    for (var i = 0; i < _items.length; i++) {
      final item  = _items[i] as Map;
      final name  = item['name']?.toString() ?? '';
      final qty   = Fmt.qty((item['qty'] as num?)?.toDouble() ?? 1);
      final price = _fmtN((item['price'] as num?)?.toDouble() ?? 0);
      final total = _fmtN((item['total'] as num?)?.toDouble() ?? 0);
      text(fmtLine(i, name, qty, price, total)); nl();
    }
    text('-' * w); nl();

    // Totals — right align
    add([0x1B, 0x61, 0x02]);
    if (_discount > 0) {
      text('Subtotal: $_currency ${_fmtN(_subtotal)}'); nl();
      text('Discount: -$_currency ${_fmtN(_discount)}'); nl();
    }
    add([0x1B, 0x45, 0x01]); // bold
    text('Total: $_currency ${_fmtN(_total)}'); nl();
    add([0x1B, 0x45, 0x00]);
    text('${_payLabel(_payMethod)}: $_currency ${_fmtN(_paidAmount)}'); nl();
    text('Total Paid: $_currency ${_fmtN(_paidAmount)}'); nl();
    if (_change > 0) { text('Change: $_currency ${_fmtN(_change)}'); nl(); }

    // Footer
    add([0x1B, 0x61, 0x01]); // center
    nl();
    text('-' * w); nl();
    text('System by: mdspro.co.tz'); nl();

    // Feed & cut
    add([0x1B, 0x64, 0x04]); // feed 4 lines
    add([0x1D, 0x56, 0x01]); // partial cut
    return b;
  }

  void _snack(String msg, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: success ? AppColors.success : AppColors.danger,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 3),
    ));
  }

  // ── UI ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      body: Stack(children: [
        Positioned(top: 0, left: 0, right: 0, height: 180,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF061410), Color(0xFF0F2D1A)],
                begin: Alignment.topLeft, end: Alignment.bottomRight)))),
        SafeArea(child: Column(children: [
          _buildTopBar(),
          Expanded(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  child: Column(children: [
                    _buildSuccessBadge(),
                    const SizedBox(height: 14),

                    // The receipt paper
                    Screenshot(
                      controller: _screenshotCtrl,
                      child: _ThermalReceiptPaper(
                        shopName: _shopName, tin: _tin, invoiceNo: _invoiceNo,
                        dateStr: _now(), custName: _custName, custPhone: _custPhone,
                        cashier: _cashier, items: _items, subtotal: _subtotal,
                        discount: _discount, total: _total, paidAmount: _paidAmount,
                        change: _change, payMethod: _payMethod, currency: _currency,
                        qrData: _qrData, forPrint: false,
                      ),
                    ),

                    const SizedBox(height: 20),
                    _buildActionRow(),
                    const SizedBox(height: 12),
                    _buildNewSaleBtn(),
                  ]),
                ),
              ),
            ),
          ),
        ])),
      ]),
    );
  }

  Widget _buildTopBar() => Padding(
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
          child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 18))),
      const SizedBox(width: 12),
      Text('Receipt', style: GoogleFonts.plusJakartaSans(
        fontSize: 17, fontWeight: FontWeight.w900, color: Colors.white)),
    ]),
  );

  Widget _buildSuccessBadge() => AnimatedBuilder(
    animation: _checkCtrl,
    builder: (_, __) => Transform.scale(
      scale: Curves.elasticOut.transform(_checkCtrl.value.clamp(0.0, 1.0)),
      child: Container(
        width: 64, height: 64,
        decoration: BoxDecoration(
          color: AppColors.success, shape: BoxShape.circle,
          boxShadow: [BoxShadow(
            color: AppColors.success.withValues(alpha: 0.4),
            blurRadius: 20, spreadRadius: 3)]),
        child: const Icon(Icons.check_rounded, color: Colors.white, size: 34))),
  );

  Widget _buildActionRow() => Row(children: [
    _Btn(label: _saving  ? 'Saving…'  : 'Save',
         icon: Icons.download_rounded, loading: _saving,
         color: AppColors.primary, onTap: _saving  ? null : _saveReceipt),
    const SizedBox(width: 8),
    _Btn(label: _sharing ? 'Sharing…' : 'Share',
         icon: Icons.share_rounded, loading: _sharing,
         color: AppColors.accent,   onTap: _sharing ? null : _shareReceipt),
    const SizedBox(width: 8),
    _Btn(label: _printing ? 'Printing…' : 'Print',
         icon: Icons.print_rounded, loading: _printing,
         color: const Color(0xFF2563EB), onTap: _printing ? null : _printReceipt),
  ]);

  Widget _buildNewSaleBtn() => GestureDetector(
    onTap: () { HapticFeedback.lightImpact(); Navigator.popUntil(context, (r) => r.isFirst); },
    child: Container(
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 8, offset: const Offset(0, 2))]),
      child: Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.add_shopping_cart_rounded, color: AppColors.primary, size: 18),
        const SizedBox(width: 8),
        Text('New Sale', style: GoogleFonts.plusJakartaSans(
          fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.primary)),
      ]))),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Thermal receipt paper widget (used both on-screen and for screenshot)
// ─────────────────────────────────────────────────────────────────────────────
class _ThermalReceiptPaper extends StatelessWidget {
  final String  shopName;
  final String? tin;
  final String  invoiceNo;
  final String  dateStr;
  final String  custName;
  final String  custPhone;
  final String  cashier;
  final List<dynamic> items;
  final double  subtotal;
  final double  discount;
  final double  total;
  final double  paidAmount;
  final double  change;
  final String  payMethod;
  final String  currency;
  final String  qrData;
  final bool    forPrint;

  const _ThermalReceiptPaper({
    required this.shopName,
    required this.tin,
    required this.invoiceNo,
    required this.dateStr,
    required this.custName,
    required this.custPhone,
    required this.cashier,
    required this.items,
    required this.subtotal,
    required this.discount,
    required this.total,
    required this.paidAmount,
    required this.change,
    required this.payMethod,
    required this.currency,
    required this.qrData,
    required this.forPrint,
  });

  String _payLabel(String m) => const {
    'cash': 'Cash', 'mpesa': 'M-Pesa', 'tigopesa': 'Tigo Pesa',
    'airtel': 'Airtel Money', 'bank': 'Bank Transfer', 'credit': 'Credit',
  }[m] ?? m;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        boxShadow: forPrint ? [] : [
          BoxShadow(color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 20, offset: const Offset(0, 4))
        ],
        border: Border.all(color: const Color(0xFFE5E7EB), width: 0.8),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // ── Header: shop name + TIN ─────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
          child: Column(children: [
            Text(shopName.toUpperCase(),
              textAlign: TextAlign.center,
              style: GoogleFonts.ibmPlexMono(
                fontSize: 15, fontWeight: FontWeight.w700,
                color: Colors.black, letterSpacing: 0.5)),
            if (tin != null && tin!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('TIN: $tin',
                textAlign: TextAlign.center,
                style: GoogleFonts.ibmPlexMono(
                  fontSize: 11, color: const Color(0xFF444444))),
            ],
          ]),
        ),

        _DashedLine(),

        // ── Meta info ──────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Column(children: [
            _MetaRow('Invoice No.', invoiceNo),
            _MetaRow('Date', dateStr),
            _MetaRow('Customer', custName),
            _MetaRow('Phone', 'Mobile: $custPhone'),
            _MetaRow('Created by:', cashier),
          ]),
        ),

        _DashedLine(),

        // ── Items table ────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
          child: Column(children: [
            // Table header
            _TableRow(
              index: '#',
              name: 'Product',
              qty: 'Qty',
              price: 'Price',
              total: 'Total',
              isHeader: true,
            ),
            _DashedLine(dashed: true),
            ...List.generate(items.length, (i) {
              final item  = items[i] as Map;
              final name  = item['name']?.toString() ?? '';
              final qtyVal = (item['qty'] as num?)?.toDouble() ?? 1;
              final price = (item['price'] as num?)?.toDouble() ?? 0;
              final tot   = (item['total'] as num?)?.toDouble() ?? (qtyVal * price);
              return Column(children: [
                _TableRow(
                  index: '${i + 1}.',
                  name: name,
                  qty: Fmt.qty(qtyVal),
                  price: _fmtN(price),
                  total: _fmtN(tot),
                  isHeader: false,
                ),
                if (i < items.length - 1) _DashedLine(dashed: true),
              ]);
            }),
          ]),
        ),

        _DashedLine(),

        // ── Bottom: QR + Totals ─────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            // QR code
            QrImageView(
              data: qrData,
              version: QrVersions.auto,
              size: 90,
              backgroundColor: Colors.white,
              errorStateBuilder: (_, __) => const SizedBox(width: 90, height: 90),
            ),
            const SizedBox(width: 12),
            // Totals
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                if (discount > 0) ...[
                  _TotalRow('Subtotal:', '$currency ${_fmtN(subtotal)}', bold: false),
                  _TotalRow('Discount:', '-$currency ${_fmtN(discount)}', bold: false, color: AppColors.danger),
                ],
                _TotalRow('Total:', '$currency ${_fmtN(total)}', bold: true),
                _TotalRow('${_payLabel(payMethod)}:', '$currency ${_fmtN(paidAmount)}', bold: false),
                _TotalRow('Total Paid:', '$currency ${_fmtN(paidAmount)}', bold: false),
                if (change > 0)
                  _TotalRow('Change:', '$currency ${_fmtN(change)}', bold: false),
              ]),
            ),
          ]),
        ),

        _DashedLine(),

        // ── Footer ─────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text('System by: mdspro.co.tz',
            textAlign: TextAlign.center,
            style: GoogleFonts.ibmPlexMono(
              fontSize: 10, color: const Color(0xFF666666))),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared receipt sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _DashedLine extends StatelessWidget {
  final bool dashed;
  const _DashedLine({this.dashed = false});

  @override
  Widget build(BuildContext context) {
    if (!dashed) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 0),
        child: CustomPaint(
          size: const Size(double.infinity, 1),
          painter: _DashPainter(
              dash: 4, gap: 3, color: const Color(0xFFAAAAAA))),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0),
      child: CustomPaint(
        size: const Size(double.infinity, 1),
        painter: _DashPainter(
            dash: 3, gap: 2, color: const Color(0xFFCCCCCC))),
    );
  }
}

class _DashPainter extends CustomPainter {
  final double dash, gap;
  final Color color;
  const _DashPainter({required this.dash, required this.gap, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color ..strokeWidth = 0.8;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset((x + dash).clamp(0, size.width), 0), p);
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

class _MetaRow extends StatelessWidget {
  final String label, value;
  const _MetaRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 100,
          child: Text(label,
            style: GoogleFonts.ibmPlexMono(
              fontSize: 10.5, color: const Color(0xFF222222)))),
        Expanded(
          child: Text(value,
            textAlign: TextAlign.right,
            style: GoogleFonts.ibmPlexMono(
              fontSize: 10.5, color: const Color(0xFF222222)))),
      ]),
    );
  }
}

class _TableRow extends StatelessWidget {
  final String index, name, qty, price, total;
  final bool isHeader;
  const _TableRow({
    required this.index, required this.name, required this.qty,
    required this.price, required this.total, required this.isHeader});

  @override
  Widget build(BuildContext context) {
    final style = GoogleFonts.ibmPlexMono(
      fontSize: isHeader ? 10.5 : 10.5,
      fontWeight: isHeader ? FontWeight.w700 : FontWeight.w400,
      color: const Color(0xFF111111),
    );
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // # col
        _Cell(child: Text(index, style: style), width: 26, center: true,
            leftBorder: true),
        // Product col
        Expanded(child: _Cell(child: Text(name, style: style, maxLines: 2,
            overflow: TextOverflow.ellipsis), leftBorder: true)),
        // Qty col
        _Cell(child: Text(qty, style: style, textAlign: TextAlign.center),
            width: 32, center: true, leftBorder: true),
        // Price col
        _Cell(child: Text(price, style: style, textAlign: TextAlign.right),
            width: 60, leftBorder: true),
        // Total col
        _Cell(child: Text(total, style: style, textAlign: TextAlign.right),
            width: 60, leftBorder: true, rightBorder: true),
      ]),
    );
  }
}

class _Cell extends StatelessWidget {
  final Widget child;
  final double? width;
  final bool leftBorder;
  final bool rightBorder;
  final bool center;
  const _Cell({
    required this.child, this.width, this.leftBorder = false,
    this.rightBorder = false, this.center = false});

  @override
  Widget build(BuildContext context) {
    Widget w = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
      child: center ? Center(child: child) : child,
    );
    if (width != null) w = SizedBox(width: width, child: w);
    return Container(
      decoration: BoxDecoration(
        border: Border(
          left: leftBorder
              ? const BorderSide(color: Color(0xFFAAAAAA), width: 0.7,
                  style: BorderStyle.solid)
              : BorderSide.none,
          right: rightBorder
              ? const BorderSide(color: Color(0xFFAAAAAA), width: 0.7,
                  style: BorderStyle.solid)
              : BorderSide.none,
        ),
      ),
      child: w,
    );
  }
}

class _TotalRow extends StatelessWidget {
  final String label, value;
  final bool bold;
  final Color? color;
  const _TotalRow(this.label, this.value, {required this.bold, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        Text(label, style: GoogleFonts.ibmPlexMono(
          fontSize: 10.5,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
          color: color ?? const Color(0xFF222222))),
        const SizedBox(width: 6),
        Text(value, style: GoogleFonts.ibmPlexMono(
          fontSize: bold ? 12 : 10.5,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
          color: color ?? const Color(0xFF111111))),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bluetooth printer picker sheet
// ─────────────────────────────────────────────────────────────────────────────
class _PrinterPickerSheet extends StatelessWidget {
  final List<BluetoothInfo> devices;
  const _PrinterPickerSheet({required this.devices});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 36, height: 4,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),
        Row(children: [
          Container(width: 38, height: 38,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.print_rounded,
                color: AppColors.primary, size: 20)),
          const SizedBox(width: 12),
          Text('Select Printer',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 17, fontWeight: FontWeight.w900,
              color: AppColors.textPrimary)),
        ]),
        const SizedBox(height: 16),
        ...devices.map((d) => GestureDetector(
          onTap: () => Navigator.pop(context, d),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE5E7EB))),
            child: Row(children: [
              Container(width: 40, height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.bluetooth_rounded,
                    color: AppColors.primary, size: 20)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(d.name, style: GoogleFonts.inter(
                    fontSize: 14, fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
                  Text(d.macAdress, style: GoogleFonts.inter(
                    fontSize: 11, color: AppColors.textMuted)),
                ])),
              const Icon(Icons.arrow_forward_ios_rounded,
                  size: 14, color: AppColors.textMuted),
            ]),
          ),
        )),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared action button
// ─────────────────────────────────────────────────────────────────────────────
class _Btn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool loading;
  final Color color;
  final VoidCallback? onTap;
  const _Btn({
    required this.label, required this.icon, required this.loading,
    required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 50,
          decoration: BoxDecoration(
            color: onTap == null ? color.withValues(alpha: 0.5) : color,
            borderRadius: BorderRadius.circular(14),
            boxShadow: onTap == null ? [] : [BoxShadow(
              color: color.withValues(alpha: 0.35),
              blurRadius: 10, offset: const Offset(0, 4))]),
          child: Center(
            child: loading
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(icon, color: Colors.white, size: 16),
                    const SizedBox(width: 5),
                    Text(label, style: GoogleFonts.plusJakartaSans(
                      fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
                  ]),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
String _fmtN(double v) => NumberFormat('#,###').format(v.toInt());
