import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/animations.dart';
import '../widgets/common_widgets.dart';

class BranchesScreen extends StatefulWidget {
  const BranchesScreen({super.key});

  @override
  State<BranchesScreen> createState() => _BranchesScreenState();
}

class _BranchesScreenState extends State<BranchesScreen>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _branches = [];
  bool _loading = true;
  late AnimationController _listCtrl;

  @override
  void initState() {
    super.initState();
    _listCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 800));
    _load();
  }

  @override
  void dispose() {
    _listCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final branches = await ApiService.getBranchesManagement();
    if (!mounted) return;
    setState(() { _branches = branches; _loading = false; });
    _listCtrl.forward(from: 0);
  }

  void _openAdd() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BranchFormSheet(
        onSaved: () {
          _load();
          _showSnack('Branch added!', AppColors.success);
        },
      ),
    );
  }

  void _openEdit(Map<String, dynamic> branch) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BranchFormSheet(
        branch: branch,
        onSaved: () {
          _load();
          _showSnack('Branch updated!', AppColors.success);
        },
      ),
    );
  }

  Future<void> _toggleBranch(Map<String, dynamic> branch) async {
    final isActive = branch['is_active'].toString() == '1';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(isActive ? 'Deactivate Branch?' : 'Activate Branch?',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900, fontSize: 16)),
        content: Text(
          isActive
              ? '${branch['name']} will be hidden from users.'
              : 'Restore ${branch['name']} for use.',
          style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.inter(color: AppColors.textMuted))),
          TextButton(onPressed: () => Navigator.pop(context, true),
            child: Text(isActive ? 'Deactivate' : 'Activate',
              style: GoogleFonts.inter(
                color: isActive ? AppColors.danger : AppColors.success,
                fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final res = await ApiService.toggleBranch(int.parse(branch['id'].toString()));
    if (!mounted) return;
    if (res['ok'] == true) {
      _load();
      _showSnack(res['message'] ?? 'Done', AppColors.success);
    } else {
      _showSnack(res['error'] ?? 'Failed', AppColors.danger);
    }
  }

  Future<void> _deleteBranch(Map<String, dynamic> branch) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete Branch?',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900, fontSize: 16)),
        content: Text(
          'Delete "${branch['name']}"? This cannot be undone.',
          style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.inter(color: AppColors.textMuted))),
          TextButton(onPressed: () => Navigator.pop(context, true),
            child: Text('Delete',
              style: GoogleFonts.inter(color: AppColors.danger, fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final res = await ApiService.deleteBranch(int.parse(branch['id'].toString()));
    if (!mounted) return;
    if (res['ok'] == true) {
      _load();
      _showSnack(res['message'] ?? 'Deleted', AppColors.success);
    } else {
      _showSnack(res['error'] ?? 'Failed', AppColors.danger);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
        style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAdd,
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.add_business_rounded, size: 20),
        label: Text('Add Branch',
          style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w800)),
      ),
      body: Column(children: [
        // ── Header ──────────────────────────────────────────────────────────
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0C2518), AppColors.primary, Color(0xFF1A4A2E)],
              begin: Alignment.topLeft, end: Alignment.bottomRight)),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
              child: Row(children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.18))),
                    child: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white, size: 16))),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Branch Management',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 20, fontWeight: FontWeight.w900,
                        color: Colors.white, letterSpacing: -0.4)),
                    Text('Manage locations & outlets',
                      style: GoogleFonts.inter(
                        fontSize: 11, color: Colors.white.withValues(alpha: 0.5),
                        fontWeight: FontWeight.w500)),
                  ])),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20)),
                  child: Text('${_branches.length} branches',
                    style: GoogleFonts.inter(
                      fontSize: 11, fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.8)))),
              ]),
            ),
          ),
        ),

        // ── List ────────────────────────────────────────────────────────────
        Expanded(
          child: _loading
              ? ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: 4,
                  itemBuilder: (_, __) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: ShimmerBox(width: double.infinity, height: 100, radius: 16)))
              : _branches.isEmpty
                  ? const EmptyState(
                      title: 'No branches yet',
                      subtitle: 'Tap "+ Add Branch" to create your first location',
                      icon: Icons.store_rounded)
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: AppColors.primary,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                        itemCount: _branches.length,
                        itemBuilder: (_, i) => StaggeredItem(
                          index: i, controller: _listCtrl,
                          child: _BranchCard(
                            branch: _branches[i],
                            onEdit:   () => _openEdit(_branches[i]),
                            onToggle: () => _toggleBranch(_branches[i]),
                            onDelete: () => _deleteBranch(_branches[i]),
                          )),
                      )),
        ),
      ]),
    );
  }
}

// ── Branch card ───────────────────────────────────────────────────────────────
class _BranchCard extends StatelessWidget {
  final Map<String, dynamic> branch;
  final VoidCallback onEdit, onToggle, onDelete;

  const _BranchCard({
    required this.branch,
    required this.onEdit, required this.onToggle, required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isActive  = branch['is_active'].toString() == '1';
    final isMain    = branch['is_main'].toString() == '1';
    final name      = branch['name'] as String? ?? '';
    final code      = branch['code'] as String? ?? '';
    final city      = branch['city'] as String? ?? '';
    final address   = branch['address'] as String? ?? '';
    final phone     = branch['phone'] as String? ?? '';
    final userCount = int.tryParse(branch['user_count']?.toString() ?? '0') ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? AppColors.border : AppColors.danger.withValues(alpha: 0.2)),
        boxShadow: [BoxShadow(
          color: AppColors.primary.withValues(alpha: 0.04),
          blurRadius: 8, offset: const Offset(0, 2))]),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isMain
                      ? [AppColors.accent.withValues(alpha: 0.25),
                         AppColors.accent.withValues(alpha: 0.12)]
                      : [AppColors.primary.withValues(alpha: 0.15),
                         AppColors.primary.withValues(alpha: 0.07)]),
                borderRadius: BorderRadius.circular(14)),
              child: Icon(
                isMain ? Icons.store_rounded : Icons.storefront_outlined,
                color: isMain ? AppColors.accent : AppColors.primary, size: 22)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(name,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14, fontWeight: FontWeight.w800,
                      color: isActive ? AppColors.textPrimary : AppColors.textMuted),
                    maxLines: 1, overflow: TextOverflow.ellipsis)),
                  if (isMain)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20)),
                      child: Text('Main',
                        style: GoogleFonts.inter(
                          fontSize: 9, fontWeight: FontWeight.w800,
                          color: AppColors.accentDark))),
                  if (!isActive) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.dangerBg,
                        borderRadius: BorderRadius.circular(20)),
                      child: Text('Inactive',
                        style: GoogleFonts.inter(
                          fontSize: 9, fontWeight: FontWeight.w800,
                          color: AppColors.danger))),
                  ],
                ]),
                const SizedBox(height: 3),
                Row(children: [
                  if (code.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6)),
                      child: Text(code,
                        style: GoogleFonts.inter(
                          fontSize: 9, fontWeight: FontWeight.w800,
                          color: AppColors.primary))),
                    const SizedBox(width: 6),
                  ],
                  Icon(Icons.people_outline_rounded, size: 11, color: AppColors.textMuted),
                  const SizedBox(width: 3),
                  Text('$userCount ${userCount == 1 ? 'user' : 'users'}',
                    style: GoogleFonts.inter(
                      fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
                ]),
                if (city.isNotEmpty || address.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      [if (address.isNotEmpty) address, if (city.isNotEmpty) city].join(', '),
                      style: GoogleFonts.inter(
                        fontSize: 11, color: AppColors.textMuted,
                        fontWeight: FontWeight.w500),
                      maxLines: 1, overflow: TextOverflow.ellipsis)),
                if (phone.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(children: [
                      Icon(Icons.phone_outlined, size: 10, color: AppColors.textMuted),
                      const SizedBox(width: 3),
                      Text(phone,
                        style: GoogleFonts.inter(
                          fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w500)),
                    ])),
              ])),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            _BranchIconBtn(icon: Icons.edit_rounded, color: AppColors.primary, onTap: onEdit),
            const SizedBox(width: 6),
            if (!isMain) ...[
              _BranchIconBtn(
                icon: isActive ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: isActive ? AppColors.warning : AppColors.success,
                onTap: onToggle),
              const SizedBox(width: 6),
              _BranchIconBtn(icon: Icons.delete_outline_rounded, color: AppColors.danger, onTap: onDelete),
            ],
          ]),
        ]),
      ),
    );
  }
}

class _BranchIconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _BranchIconBtn({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 32, width: 38,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2))),
      child: Icon(icon, size: 15, color: color)),
  );
}

// ── Branch form sheet (add + edit) ────────────────────────────────────────────
class _BranchFormSheet extends StatefulWidget {
  final Map<String, dynamic>? branch;
  final VoidCallback onSaved;
  const _BranchFormSheet({this.branch, required this.onSaved});

  @override
  State<_BranchFormSheet> createState() => _BranchFormSheetState();
}

class _BranchFormSheetState extends State<_BranchFormSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _codeCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _cityCtrl;
  late final TextEditingController _phoneCtrl;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.branch != null;

  @override
  void initState() {
    super.initState();
    final b = widget.branch;
    _nameCtrl    = TextEditingController(text: b?['name']    as String? ?? '');
    _codeCtrl    = TextEditingController(text: b?['code']    as String? ?? '');
    _addressCtrl = TextEditingController(text: b?['address'] as String? ?? '');
    _cityCtrl    = TextEditingController(text: b?['city']    as String? ?? '');
    _phoneCtrl   = TextEditingController(text: b?['phone']   as String? ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _codeCtrl.dispose();
    _addressCtrl.dispose(); _cityCtrl.dispose(); _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) { setState(() => _error = 'Branch name is required'); return; }
    setState(() { _saving = true; _error = null; });
    HapticFeedback.mediumImpact();
    try {
      final Map<String, dynamic> res;
      if (_isEdit) {
        res = await ApiService.updateBranch(
          branchId: int.parse(widget.branch!['id'].toString()),
          name: name, code: _codeCtrl.text.trim(),
          address: _addressCtrl.text.trim(),
          city: _cityCtrl.text.trim(), phone: _phoneCtrl.text.trim(),
        );
      } else {
        res = await ApiService.addBranch(
          name: name, code: _codeCtrl.text.trim(),
          address: _addressCtrl.text.trim(),
          city: _cityCtrl.text.trim(), phone: _phoneCtrl.text.trim(),
        );
      }
      if (!mounted) return;
      if (res['ok'] == true) {
        HapticFeedback.heavyImpact();
        Navigator.pop(context);
        widget.onSaved();
      } else {
        setState(() { _saving = false; _error = res['error'] ?? 'Failed'; });
      }
    } catch (_) {
      if (mounted) setState(() { _saving = false; _error = 'Network error'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, Color(0xFF1A4A2E)]),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              boxShadow: [BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.25),
                blurRadius: 12, offset: const Offset(0, 4))]),
            child: Row(children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(11)),
                child: Icon(_isEdit ? Icons.edit_rounded : Icons.add_business_rounded,
                  color: Colors.white, size: 20)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_isEdit ? 'Edit Branch' : 'Add New Branch',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16, fontWeight: FontWeight.w900,
                    color: Colors.white, letterSpacing: -0.3)),
                Text(_isEdit ? widget.branch!['name'] as String : 'Create a new location',
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
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _BranchLabel('Branch Name *'), const SizedBox(height: 6),
                _BranchField(_nameCtrl, 'e.g. Ubungo Branch', Icons.storefront_outlined,
                  cap: TextCapitalization.words),
                const SizedBox(height: 14),

                Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _BranchLabel('Branch Code'), const SizedBox(height: 6),
                    _BranchField(_codeCtrl, 'e.g. UBG-01', Icons.qr_code_rounded),
                  ])),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _BranchLabel('City'), const SizedBox(height: 6),
                    _BranchField(_cityCtrl, 'e.g. Dar es Salaam', Icons.location_city_rounded,
                      cap: TextCapitalization.words),
                  ])),
                ]),
                const SizedBox(height: 14),

                _BranchLabel('Address (optional)'), const SizedBox(height: 6),
                _BranchField(_addressCtrl, 'Street or area', Icons.place_outlined,
                  cap: TextCapitalization.sentences),
                const SizedBox(height: 14),

                _BranchLabel('Phone (optional)'), const SizedBox(height: 6),
                _BranchField(_phoneCtrl, '+255 7XX XXX XXX', Icons.phone_outlined,
                  type: TextInputType.phone),
                const SizedBox(height: 10),
              ]),
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
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600,
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
                          const Icon(Icons.check_rounded, color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                          Text(_isEdit ? 'Save Changes' : 'Create Branch',
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

// ── Form helpers ──────────────────────────────────────────────────────────────
class _BranchLabel extends StatelessWidget {
  final String text;
  const _BranchLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
    style: GoogleFonts.plusJakartaSans(
      fontSize: 11.5, fontWeight: FontWeight.w800,
      color: AppColors.textMuted, letterSpacing: 0.3));
}

class _BranchField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType? type;
  final TextCapitalization cap;
  const _BranchField(this.controller, this.hint, this.icon,
    {this.type, this.cap = TextCapitalization.none});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: AppColors.bg, borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.border)),
    child: Row(children: [
      Padding(padding: const EdgeInsets.only(left: 12),
        child: Icon(icon, size: 16,
          color: AppColors.primary.withValues(alpha: 0.7))),
      Expanded(child: TextField(
        controller: controller,
        keyboardType: type,
        textCapitalization: cap,
        style: GoogleFonts.inter(
          fontSize: 14, fontWeight: FontWeight.w600,
          color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: AppColors.textMuted.withValues(alpha: 0.6), fontSize: 13),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 13, horizontal: 10)))),
    ]),
  );
}
