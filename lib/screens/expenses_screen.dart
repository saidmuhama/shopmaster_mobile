import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});
  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  List<Map<String, dynamic>> _expenses   = [];
  List<Map<String, dynamic>> _categories = [];
  String   _filter = 'month';
  double   _total  = 0;
  int      _count  = 0;
  bool     _loading = true;

  static const _filters = [
    ('today', 'Today'),
    ('week',  'This Week'),
    ('month', 'This Month'),
    ('all',   'All Time'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.getExpenses(filter: _filter);
      if (!mounted) return;
      setState(() {
        _expenses = List<Map<String, dynamic>>.from(res['expenses'] ?? []);
        _total    = (res['total'] as num?)?.toDouble() ?? 0;
        _count    = (res['count'] as num?)?.toInt()   ?? 0;
      });
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadCategories() async {
    if (_categories.isNotEmpty) return;
    try {
      final res = await ApiService.getExpenseCategories();
      if (mounted) setState(() => _categories = res);
    } catch (_) {}
  }

  String _fmtMoney(dynamic v) =>
      'TZS ${NumberFormat('#,###').format((v as num?)?.toDouble() ?? 0)}';

  String _fmtDate(String? raw) {
    if (raw == null) return '';
    try {
      return DateFormat('d MMM yyyy').format(DateTime.parse(raw));
    } catch (_) { return raw; }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: NestedScrollView(
        headerSliverBuilder: (ctx, inner) => [
          SliverAppBar(
            pinned: true,
            expandedHeight: 140,
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            systemOverlayStyle: SystemUiOverlayStyle.light,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              title: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Expenses',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 20, fontWeight: FontWeight.w900,
                      color: Colors.white, letterSpacing: -0.3)),
                  Text(_fmtMoney(_total),
                    style: GoogleFonts.inter(
                      fontSize: 12, color: Colors.white.withValues(alpha: 0.75))),
                ],
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0A1F10), Color(0xFF0F2D1A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
          ),
        ],
        body: Column(children: [
          // Filter chips
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: _filters.map((f) {
                final sel = _filter == f.$1;
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      if (_filter == f.$1) return;
                      setState(() => _filter = f.$1);
                      _load();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: sel ? AppColors.primary : const Color(0xFFF3F4F6),
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
          ),

          // Summary strip
          if (!_loading) _SummaryStrip(total: _total, count: _count, filter: _filter),

          // List
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _expenses.isEmpty
                    ? _EmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                        itemCount: _expenses.length,
                        itemBuilder: (_, i) => _ExpenseCard(
                          expense: _expenses[i],
                          fmtMoney: _fmtMoney,
                          fmtDate: _fmtDate,
                        ),
                      ),
          ),
        ]),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await _loadCategories();
          if (!mounted) return;
          final added = await showModalBottomSheet<bool>(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => _AddExpenseSheet(categories: _categories),
          );
          if (added == true) _load();
        },
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: Text('Add Expense',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}

// ── Summary strip ─────────────────────────────────────────────────────────────
class _SummaryStrip extends StatelessWidget {
  final double total;
  final int count;
  final String filter;
  const _SummaryStrip({required this.total, required this.count, required this.filter});

  @override
  Widget build(BuildContext context) {
    final label = switch (filter) {
      'today' => "Today's Expenses",
      'week'  => "This Week's Expenses",
      'all'   => "All Expenses",
      _       => "This Month's Expenses",
    };
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F2D1A), Color(0xFF1a4730)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(
          color: AppColors.primary.withValues(alpha: 0.25),
          blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.receipt_long_rounded,
              color: Colors.white, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
            style: GoogleFonts.inter(
              fontSize: 11, color: Colors.white.withValues(alpha: 0.7))),
          const SizedBox(height: 2),
          Text('TZS ${NumberFormat('#,###').format(total.toInt())}',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20)),
            child: Text('$count items',
              style: GoogleFonts.inter(
                fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
          ),
        ]),
      ]),
    );
  }
}

// ── Expense card ──────────────────────────────────────────────────────────────
class _ExpenseCard extends StatelessWidget {
  final Map<String, dynamic> expense;
  final String Function(dynamic) fmtMoney;
  final String Function(String?) fmtDate;
  const _ExpenseCard({
    required this.expense, required this.fmtMoney, required this.fmtDate});

  @override
  Widget build(BuildContext context) {
    final catName = expense['category_name'] as String? ?? 'Uncategorized';
    final method  = (expense['payment_method'] as String? ?? 'cash');
    final note    = expense['note'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12)),
          child: Icon(Icons.payments_rounded,
              color: AppColors.primary, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(expense['title'] as String? ?? '',
            style: GoogleFonts.inter(
              fontSize: 14, fontWeight: FontWeight.w700,
              color: AppColors.textPrimary)),
          const SizedBox(height: 3),
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6)),
              child: Text(catName,
                style: GoogleFonts.inter(
                  fontSize: 10, fontWeight: FontWeight.w600,
                  color: AppColors.primary)),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(6)),
              child: Text(method,
                style: GoogleFonts.inter(
                  fontSize: 10, fontWeight: FontWeight.w600,
                  color: AppColors.textMuted)),
            ),
          ]),
          if (note != null && note.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(note,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 11, color: AppColors.textMuted)),
          ],
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(fmtMoney(expense['amount']),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14, fontWeight: FontWeight.w900,
              color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Text(fmtDate(expense['expense_date'] as String?),
            style: GoogleFonts.inter(
              fontSize: 11, color: AppColors.textMuted)),
        ]),
      ]),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(20)),
          child: Icon(Icons.receipt_long_outlined,
              size: 32, color: AppColors.primary.withValues(alpha: 0.5)),
        ),
        const SizedBox(height: 16),
        Text('No expenses found',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16, fontWeight: FontWeight.w700,
            color: AppColors.textPrimary)),
        const SizedBox(height: 6),
        Text('Tap + Add Expense to record one',
          style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
      ]),
    );
  }
}

// ── Add expense sheet ─────────────────────────────────────────────────────────
class _AddExpenseSheet extends StatefulWidget {
  final List<Map<String, dynamic>> categories;
  const _AddExpenseSheet({required this.categories});
  @override
  State<_AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends State<_AddExpenseSheet> {
  final _formKey   = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _amtCtrl   = TextEditingController();
  final _noteCtrl  = TextEditingController();
  final _catCtrl   = TextEditingController(); // for new category inline

  late List<Map<String, dynamic>> _cats;
  int?   _catId;
  String _date   = DateFormat('yyyy-MM-dd').format(DateTime.now());
  String _method = 'cash';
  bool   _saving = false;
  bool   _addingCat = false;
  String? _error;

  static const _methods = ['cash', 'mpesa', 'tigo_pesa', 'airtel', 'bank'];

  @override
  void initState() {
    super.initState();
    _cats = List.from(widget.categories);
  }

  @override
  void dispose() {
    _titleCtrl.dispose(); _amtCtrl.dispose();
    _noteCtrl.dispose();  _catCtrl.dispose();
    super.dispose();
  }

  Future<void> _addCategoryInline() async {
    final name = _catCtrl.text.trim();
    if (name.isEmpty) return;
    try {
      final res = await ApiService.addExpenseCategory(name);
      if (!mounted) return;
      if (res['ok'] == true) {
        final newCat = {'id': res['id'], 'name': res['name']};
        setState(() {
          _cats.add(newCat);
          _catId = res['id'] as int?;
          _catCtrl.clear();
          _addingCat = false;
        });
      } else {
        setState(() => _error = res['error']);
      }
    } catch (_) {
      setState(() => _error = 'Failed to create category.');
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_catId == null) {
      setState(() => _error = 'Please select a category.');
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      final amount = double.tryParse(_amtCtrl.text.replaceAll(',', '')) ?? 0;
      final res = await ApiService.addExpense(
        title:         _titleCtrl.text.trim(),
        categoryId:    _catId!,
        amount:        amount,
        date:          _date,
        paymentMethod: _method,
        note:          _noteCtrl.text.trim(),
      );
      if (!mounted) return;
      if (res['ok'] == true) {
        Navigator.pop(context, true);
      } else {
        setState(() => _error = res['error'] ?? 'Failed to save expense.');
      }
    } catch (_) {
      setState(() => _error = 'Connection error.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Container(
      margin: EdgeInsets.only(top: mq.padding.top + 40),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      child: Column(children: [
        // Handle
        const SizedBox(height: 10),
        Container(
          width: 36, height: 4,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 14),

        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.add_card_rounded,
                  color: AppColors.primary, size: 20)),
            const SizedBox(width: 12),
            Text('Record Expense',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 17, fontWeight: FontWeight.w900,
                color: AppColors.textPrimary)),
            const Spacer(),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.close_rounded,
                    size: 16, color: Color(0xFF6B7280))),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        const Divider(height: 1, color: Color(0xFFF3F4F6)),

        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20, 16, 20, mq.viewInsets.bottom + 24),
            child: Form(
              key: _formKey,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Error
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.danger.withValues(alpha: 0.25))),
                    child: Row(children: [
                      Icon(Icons.error_outline_rounded, size: 16, color: AppColors.danger),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_error!,
                          style: GoogleFonts.inter(
                            fontSize: 12, color: AppColors.danger))),
                    ]),
                  ),
                  const SizedBox(height: 14),
                ],

                // Title
                _SheetField(
                  ctrl: _titleCtrl,
                  label: 'Expense Title',
                  hint: 'e.g. Office rent, Fuel',
                  icon: Icons.label_outline_rounded,
                  validator: (v) => (v?.trim().isEmpty ?? true) ? 'Title required' : null,
                ),
                const SizedBox(height: 14),

                // Amount
                _SheetField(
                  ctrl: _amtCtrl,
                  label: 'Amount (TZS)',
                  hint: '0',
                  icon: Icons.payments_outlined,
                  keyboard: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (v) {
                    final n = double.tryParse(v?.replaceAll(',', '') ?? '');
                    if (n == null || n <= 0) return 'Enter a valid amount';
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Category picker
                _label('Category'),
                const SizedBox(height: 7),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE5E7EB))),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int?>(
                      value: _catId,
                      isExpanded: true,
                      hint: Text('Select category',
                        style: GoogleFonts.inter(
                          fontSize: 14, color: const Color(0xFFB4BAC5))),
                      icon: const Icon(Icons.keyboard_arrow_down_rounded,
                          size: 18, color: Color(0xFF9CA3AF)),
                      style: GoogleFonts.inter(
                          fontSize: 14, color: AppColors.textPrimary),
                      items: [
                        ..._cats.map((c) => DropdownMenuItem<int?>(
                          value: c['id'] as int?,
                          child: Text(c['name'] as String? ?? ''))),
                        DropdownMenuItem<int?>(
                          value: -1,
                          child: Row(children: [
                            const Icon(Icons.add_rounded, size: 14, color: Color(0xFF059669)),
                            const SizedBox(width: 6),
                            Text('Add new category',
                              style: GoogleFonts.inter(
                                fontSize: 13, fontWeight: FontWeight.w600,
                                color: const Color(0xFF059669))),
                          ]),
                        ),
                      ],
                      onChanged: (v) {
                        if (v == -1) {
                          setState(() { _addingCat = true; _catId = null; });
                        } else {
                          setState(() { _catId = v; _addingCat = false; });
                        }
                      },
                    ),
                  ),
                ),

                // Inline new category
                if (_addingCat) ...[
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                      child: _SheetField(
                        ctrl: _catCtrl,
                        label: 'New Category Name',
                        hint: 'e.g. Utilities',
                        icon: Icons.category_outlined,
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _addCategoryInline,
                      child: Container(
                        height: 52,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(14)),
                        child: const Icon(Icons.check_rounded,
                            color: Colors.white, size: 20),
                      ),
                    ),
                  ]),
                ],
                const SizedBox(height: 14),

                // Date picker
                _label('Date'),
                const SizedBox(height: 7),
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.tryParse(_date) ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                      builder: (ctx, child) => Theme(
                        data: Theme.of(ctx).copyWith(
                          colorScheme: ColorScheme.light(primary: AppColors.primary)),
                        child: child!),
                    );
                    if (picked != null) {
                      setState(() => _date = DateFormat('yyyy-MM-dd').format(picked));
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE5E7EB))),
                    child: Row(children: [
                      Icon(Icons.calendar_today_rounded,
                          size: 18, color: AppColors.primary),
                      const SizedBox(width: 10),
                      Text(DateFormat('d MMMM yyyy')
                          .format(DateTime.tryParse(_date) ?? DateTime.now()),
                        style: GoogleFonts.inter(
                          fontSize: 14, fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary)),
                    ]),
                  ),
                ),
                const SizedBox(height: 14),

                // Payment method
                _label('Payment Method'),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 8,
                  children: _methods.map((m) {
                    final sel = _method == m;
                    return GestureDetector(
                      onTap: () => setState(() => _method = m),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: sel ? AppColors.primary : const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(10)),
                        child: Text(m.replaceAll('_', ' ').toUpperCase(),
                          style: GoogleFonts.inter(
                            fontSize: 11, fontWeight: FontWeight.w700,
                            color: sel ? Colors.white : AppColors.textMuted)),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),

                // Note
                _SheetField(
                  ctrl: _noteCtrl,
                  label: 'Note (optional)',
                  hint: 'Additional details…',
                  icon: Icons.notes_rounded,
                  maxLines: 2,
                ),
                const SizedBox(height: 24),

                // Save button
                GestureDetector(
                  onTap: _saving ? null : _save,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 54,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.35),
                        blurRadius: 14, offset: const Offset(0, 6))],
                    ),
                    child: Center(
                      child: _saving
                          ? const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.save_rounded,
                                    color: Colors.white, size: 18),
                                const SizedBox(width: 8),
                                Text('Save Expense',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 15, fontWeight: FontWeight.w800,
                                    color: Colors.white)),
                              ],
                            ),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

// ── Sheet helpers ─────────────────────────────────────────────────────────────
Widget _label(String text) => Text(text,
  style: GoogleFonts.inter(
    fontSize: 11, fontWeight: FontWeight.w700,
    color: const Color(0xFF6B7280), letterSpacing: 0.2));

class _SheetField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label, hint;
  final IconData icon;
  final TextInputType? keyboard;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;
  final int maxLines;

  const _SheetField({
    required this.ctrl,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboard,
    this.inputFormatters,
    this.validator,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _label(label),
      const SizedBox(height: 7),
      TextFormField(
        controller: ctrl,
        keyboardType: keyboard,
        inputFormatters: inputFormatters,
        validator: validator,
        maxLines: maxLines,
        style: GoogleFonts.inter(
          fontSize: 14, fontWeight: FontWeight.w500,
          color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.inter(
              fontSize: 13, color: const Color(0xFFB4BAC5)),
          prefixIcon: Icon(icon, size: 18, color: const Color(0xFF9CA3AF)),
          filled: true,
          fillColor: const Color(0xFFF9FAFB),
          contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: AppColors.primary, width: 1.8)),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: AppColors.danger)),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: AppColors.danger, width: 1.8)),
        ),
      ),
    ]);
  }
}
