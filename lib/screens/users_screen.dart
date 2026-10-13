import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/animations.dart';
import '../widgets/common_widgets.dart';

// Mobile-relevant modules grouped for permissions UI
const _kModuleGroups = <String, List<(String, String)>>{
  'Sales': [
    ('pos',           'New Sale (POS)'),
    ('sales_history', 'Sales History'),
    ('invoices',      'Invoices'),
    ('sales_orders',  'Pre-Sales Orders'),
  ],
  'Inventory': [
    ('products', 'Products'),
    ('stock',    'Stock Management'),
    ('purchases','Purchases'),
    ('low_stock','Low Stock Alerts'),
    ('transfers','Transfers'),
  ],
  'Business': [
    ('customers', 'Customers'),
    ('expenses',  'Expenses'),
    ('credits',   'Credit & Debts'),
    ('payments',  'Payments'),
  ],
  'Reports': [
    ('report_sales',     'Sales Analytics'),
    ('report_stock',     'Inventory Report'),
    ('report_pnl',       'P&L Statement'),
    ('report_customers', 'Top Customers'),
    ('report_debts',     'Debts Report'),
  ],
};

// All module keys in one flat list
List<String> get _allModuleKeys =>
    _kModuleGroups.values.expand((g) => g.map((e) => e.$1)).toList();

class UsersScreen extends StatefulWidget {
  final String currentRole;
  const UsersScreen({super.key, required this.currentRole});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _users = [];
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
    final users = await ApiService.getUsers();
    if (!mounted) return;
    setState(() { _users = users; _loading = false; });
    _listCtrl.forward(from: 0);
  }

  void _openAdd() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddUserSheet(
        currentRole: widget.currentRole,
        onSaved: () {
          _load();
          _showSnack('User added successfully!', AppColors.success);
        },
      ),
    );
  }

  void _openPermissions(Map<String, dynamic> user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PermissionsSheet(
        user: user,
        onSaved: () {
          _load();
          _showSnack('Permissions updated!', AppColors.success);
        },
      ),
    );
  }

  Future<void> _toggleStatus(Map<String, dynamic> user) async {
    final isActive = user['is_active'].toString() == '1';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(isActive ? 'Deactivate User?' : 'Activate User?',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w900, fontSize: 16)),
        content: Text(
          isActive
              ? '${user['name']} will no longer be able to log in.'
              : 'Restore login access for ${user['name']}.',
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
    final res = await ApiService.toggleUserStatus(int.parse(user['id'].toString()));
    if (!mounted) return;
    if (res['ok'] == true) {
      _load();
      _showSnack(res['message'] ?? 'Done', AppColors.success);
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

  Color _roleColor(String role) {
    switch (role) {
      case 'owner':         return const Color(0xFF7C3AED);
      case 'manager':       return AppColors.primary;
      case 'cashier':       return AppColors.accent;
      case 'accountant':    return const Color(0xFF0891B2);
      case 'stock_manager': return const Color(0xFF059669);
      default:              return AppColors.textMuted;
    }
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'stock_manager': return 'Stock Mgr';
      default: return role[0].toUpperCase() + role.substring(1);
    }
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
        icon: const Icon(Icons.person_add_rounded, size: 20),
        label: Text('Add User',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13, fontWeight: FontWeight.w800)),
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
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.18))),
                    child: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white, size: 16))),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Users & Permissions',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 20, fontWeight: FontWeight.w900,
                        color: Colors.white, letterSpacing: -0.4)),
                    Text('Manage staff access',
                      style: GoogleFonts.inter(
                        fontSize: 11, color: Colors.white.withValues(alpha: 0.5),
                        fontWeight: FontWeight.w500)),
                  ])),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20)),
                  child: Text('${_users.length} users',
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
                  itemCount: 5,
                  itemBuilder: (_, __) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: ShimmerBox(width: double.infinity, height: 88, radius: 16)))
              : _users.isEmpty
                  ? const EmptyState(
                      title: 'No users yet',
                      subtitle: 'Tap "+ Add User" to add your first staff member',
                      icon: Icons.people_outline_rounded)
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: AppColors.primary,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                        itemCount: _users.length,
                        itemBuilder: (_, i) => StaggeredItem(
                          index: i, controller: _listCtrl,
                          child: _UserCard(
                            user: _users[i],
                            roleColor: _roleColor(_users[i]['role'] ?? ''),
                            roleLabel: _roleLabel(_users[i]['role'] ?? ''),
                            onPermissions: () => _openPermissions(_users[i]),
                            onToggle: () => _toggleStatus(_users[i]),
                          )),
                      )),
        ),
      ]),
    );
  }
}

// ── User card ─────────────────────────────────────────────────────────────────
class _UserCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final Color roleColor;
  final String roleLabel;
  final VoidCallback onPermissions, onToggle;

  const _UserCard({
    required this.user, required this.roleColor, required this.roleLabel,
    required this.onPermissions, required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final isActive   = user['is_active'].toString() == '1';
    final configured = user['is_configured'].toString() == '1';
    final permCount  = int.tryParse(user['perm_count']?.toString() ?? '0') ?? 0;
    final name       = user['name'] as String? ?? '';
    final email      = user['email'] as String? ?? '';
    final branch     = user['branch_name'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? AppColors.border : AppColors.danger.withValues(alpha: 0.2)),
        boxShadow: [BoxShadow(
          color: (isActive ? AppColors.primary : AppColors.danger).withValues(alpha: 0.04),
          blurRadius: 8, offset: const Offset(0, 2))]),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(children: [
          Row(children: [
            // Avatar
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [roleColor.withValues(alpha: 0.25),
                           roleColor.withValues(alpha: 0.12)]),
                borderRadius: BorderRadius.circular(14)),
              child: Center(
                child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18, fontWeight: FontWeight.w900,
                    color: roleColor)))),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Text(name,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14, fontWeight: FontWeight.w800,
                        color: isActive ? AppColors.textPrimary : AppColors.textMuted),
                      maxLines: 1, overflow: TextOverflow.ellipsis)),
                  if (!isActive)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.dangerBg,
                        borderRadius: BorderRadius.circular(20)),
                      child: Text('Inactive',
                        style: GoogleFonts.inter(
                          fontSize: 9, fontWeight: FontWeight.w800,
                          color: AppColors.danger))),
                ]),
                const SizedBox(height: 4),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: roleColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20)),
                    child: Text(roleLabel,
                      style: GoogleFonts.inter(
                        fontSize: 10, fontWeight: FontWeight.w800,
                        color: roleColor))),
                  if (branch.isNotEmpty) ...[
                    const SizedBox(width: 5),
                    Flexible(child: Text('· $branch',
                      style: GoogleFonts.inter(
                        fontSize: 10, color: AppColors.textMuted,
                        fontWeight: FontWeight.w500),
                      maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ],
                ]),
                const SizedBox(height: 2),
                Text(email,
                  style: GoogleFonts.inter(
                    fontSize: 11, color: AppColors.textMuted,
                    fontWeight: FontWeight.w500),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              ])),
          ]),

          const SizedBox(height: 12),
          // Permissions badge + action buttons
          Row(children: [
            GestureDetector(
              onTap: onPermissions,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: configured
                      ? AppColors.primary.withValues(alpha: 0.07)
                      : AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: configured
                        ? AppColors.primary.withValues(alpha: 0.2)
                        : AppColors.warning.withValues(alpha: 0.3))),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(
                    configured ? Icons.verified_user_rounded : Icons.shield_outlined,
                    size: 13,
                    color: configured ? AppColors.primary : AppColors.warning),
                  const SizedBox(width: 5),
                  Text(
                    configured ? '$permCount modules' : 'Set permissions',
                    style: GoogleFonts.inter(
                      fontSize: 11, fontWeight: FontWeight.w700,
                      color: configured ? AppColors.primary : AppColors.warning)),
                ]),
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: onToggle,
              child: Container(
                width: 36, height: 32,
                decoration: BoxDecoration(
                  color: isActive
                      ? AppColors.danger.withValues(alpha: 0.07)
                      : AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isActive
                        ? AppColors.danger.withValues(alpha: 0.2)
                        : AppColors.success.withValues(alpha: 0.3))),
                child: Icon(
                  isActive ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  size: 16,
                  color: isActive ? AppColors.danger : AppColors.success)),
            ),
          ]),
        ]),
      ),
    );
  }
}

// ── Add User Sheet ────────────────────────────────────────────────────────────
class _AddUserSheet extends StatefulWidget {
  final String currentRole;
  final VoidCallback onSaved;
  const _AddUserSheet({required this.currentRole, required this.onSaved});

  @override
  State<_AddUserSheet> createState() => _AddUserSheetState();
}

class _AddUserSheetState extends State<_AddUserSheet> {
  final _nameCtrl  = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();

  String  _role     = 'cashier';
  int?    _branchId;
  List<Map<String, dynamic>> _branches = [];
  bool    _saving   = false;
  bool    _loading  = true;
  bool    _showPass = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBranches();
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _emailCtrl.dispose();
    _phoneCtrl.dispose(); _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadBranches() async {
    final b = await ApiService.getManagementBranches();
    if (mounted) setState(() { _branches = b; _loading = false; });
  }

  List<String> get _allowedRoles => widget.currentRole == 'owner'
      ? ['cashier', 'accountant', 'stock_manager', 'manager']
      : ['cashier', 'accountant', 'stock_manager'];

  Future<void> _save() async {
    final name  = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final pass  = _passCtrl.text.trim();
    if (name.isEmpty)  { setState(() => _error = 'Name is required'); return; }
    if (email.isEmpty) { setState(() => _error = 'Email is required'); return; }
    if (pass.length < 6) { setState(() => _error = 'Password must be at least 6 characters'); return; }
    setState(() { _saving = true; _error = null; });
    HapticFeedback.mediumImpact();
    try {
      final res = await ApiService.addUser(
        name: name, email: email,
        phone: _phoneCtrl.text.trim(),
        role: _role, password: pass,
        branchId: _branchId,
      );
      if (!mounted) return;
      if (res['ok'] == true) {
        HapticFeedback.heavyImpact();
        Navigator.pop(context);
        widget.onSaved();
      } else {
        setState(() { _saving = false; _error = res['error'] ?? 'Failed to add user'; });
      }
    } catch (_) {
      if (mounted) setState(() { _saving = false; _error = 'Network error'; });
    }
  }

  String _roleLabel(String r) {
    switch (r) {
      case 'stock_manager': return 'Stock Manager';
      case 'accountant':    return 'Accountant';
      case 'manager':       return 'Manager';
      case 'cashier':       return 'Cashier';
      default: return r;
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
          // Header
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
                child: const Icon(Icons.person_add_rounded, color: Colors.white, size: 20)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Add New User',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16, fontWeight: FontWeight.w900,
                    color: Colors.white, letterSpacing: -0.3)),
                Text('Create a staff account',
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
            const Padding(padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(color: AppColors.primary)),

          if (!_loading)
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _FL('Full Name *'), const SizedBox(height: 6),
                  _FF(_nameCtrl, 'e.g. John Mwangi', Icons.person_outline_rounded,
                    cap: TextCapitalization.words),
                  const SizedBox(height: 14),

                  _FL('Email Address *'), const SizedBox(height: 6),
                  _FF(_emailCtrl, 'user@example.com', Icons.email_outlined,
                    type: TextInputType.emailAddress),
                  const SizedBox(height: 14),

                  _FL('Phone (optional)'), const SizedBox(height: 6),
                  _FF(_phoneCtrl, '+255 7XX XXX XXX', Icons.phone_outlined,
                    type: TextInputType.phone),
                  const SizedBox(height: 14),

                  // Role + Branch row
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _FL('Role'), const SizedBox(height: 6),
                        _DropField(
                          value: _role,
                          items: _allowedRoles.map((r) =>
                            DropdownMenuItem(value: r, child: Text(_roleLabel(r),
                              style: GoogleFonts.inter(fontSize: 13,
                                fontWeight: FontWeight.w600)))).toList(),
                          onChanged: (v) { if (v != null) setState(() => _role = v); },
                        ),
                      ])),
                    const SizedBox(width: 10),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _FL('Branch'), const SizedBox(height: 6),
                        _DropField<int?>(
                          value: _branchId,
                          items: [
                            DropdownMenuItem<int?>(value: null,
                              child: Text('All branches',
                                style: GoogleFonts.inter(fontSize: 13,
                                  color: AppColors.textMuted))),
                            ..._branches.map((b) => DropdownMenuItem<int?>(
                              value: b['id'] as int,
                              child: Text(b['name'] as String,
                                style: GoogleFonts.inter(fontSize: 13,
                                  fontWeight: FontWeight.w600),
                                maxLines: 1, overflow: TextOverflow.ellipsis))),
                          ],
                          onChanged: (v) => setState(() => _branchId = v),
                        ),
                      ])),
                  ]),
                  const SizedBox(height: 14),

                  _FL('Password *'), const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.bg, borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border)),
                    child: Row(children: [
                      const Padding(padding: EdgeInsets.only(left: 12),
                        child: Icon(Icons.lock_outline_rounded,
                          size: 16, color: AppColors.primary)),
                      Expanded(child: TextField(
                        controller: _passCtrl,
                        obscureText: !_showPass,
                        style: GoogleFonts.inter(
                          fontSize: 14, fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Min 6 characters',
                          hintStyle: TextStyle(
                            color: AppColors.textMuted.withValues(alpha: 0.6),
                            fontSize: 13),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 13, horizontal: 10)))),
                      GestureDetector(
                        onTap: () => setState(() => _showPass = !_showPass),
                        child: Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: Icon(
                            _showPass ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                            size: 18, color: AppColors.textMuted))),
                    ]),
                  ),
                  const SizedBox(height: 6),
                  Text('User can change password after logging in',
                    style: GoogleFonts.inter(
                      fontSize: 10.5, color: AppColors.textMuted)),
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
                          Text('Create User',
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

// ── Permissions Sheet ─────────────────────────────────────────────────────────
class _PermissionsSheet extends StatefulWidget {
  final Map<String, dynamic> user;
  final VoidCallback onSaved;
  const _PermissionsSheet({required this.user, required this.onSaved});

  @override
  State<_PermissionsSheet> createState() => _PermissionsSheetState();
}

class _PermissionsSheetState extends State<_PermissionsSheet> {
  Set<String> _granted = {};
  bool _loading = true;
  bool _saving  = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = int.parse(widget.user['id'].toString());
    final res = await ApiService.getUserPermissions(userId);
    if (!mounted) return;
    if (res['ok'] == true) {
      final granted = (res['granted'] as List? ?? []).cast<String>();
      setState(() { _granted = granted.toSet(); _loading = false; });
    } else {
      setState(() { _loading = false; });
    }
  }

  void _toggleAll(List<String> keys, bool value) {
    setState(() {
      if (value) {
        _granted.addAll(keys);
      } else {
        _granted.removeAll(keys);
      }
    });
  }

  Future<void> _save() async {
    setState(() { _saving = true; _error = null; });
    HapticFeedback.mediumImpact();
    try {
      final userId = int.parse(widget.user['id'].toString());
      final res = await ApiService.updatePermissions(
        userId: userId,
        modules: _granted.toList(),
      );
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
    final name = widget.user['name'] as String? ?? '';
    final role = widget.user['role'] as String? ?? '';

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E3A5F), Color(0xFF2563EB)]),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              boxShadow: [BoxShadow(
                color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                blurRadius: 12, offset: const Offset(0, 4))]),
            child: Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12)),
                child: Center(
                  child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16, fontWeight: FontWeight.w900,
                      color: Colors.white)))),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15, fontWeight: FontWeight.w900,
                      color: Colors.white)),
                  Text('${role[0].toUpperCase()}${role.substring(1)} · ${_granted.length} modules granted',
                    style: GoogleFonts.inter(
                      fontSize: 11, color: Colors.white.withValues(alpha: 0.65))),
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
            const Padding(padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(color: Color(0xFF2563EB))),

          if (!_loading)
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Column(
                  children: _kModuleGroups.entries.map((entry) {
                    final groupName = entry.key;
                    final modules   = entry.value;
                    final keys      = modules.map((m) => m.$1).toList();
                    final allOn     = keys.every((k) => _granted.contains(k));
                    final anyOn     = keys.any((k) => _granted.contains(k));

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border)),
                      child: Column(children: [
                        // Group header with select-all toggle
                        GestureDetector(
                          onTap: () => _toggleAll(keys, !allOn),
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                            decoration: BoxDecoration(
                              color: anyOn
                                  ? const Color(0xFF2563EB).withValues(alpha: 0.05)
                                  : Colors.transparent,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(14))),
                            child: Row(children: [
                              Text(groupName,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12, fontWeight: FontWeight.w900,
                                  color: anyOn
                                      ? const Color(0xFF2563EB)
                                      : AppColors.textMuted,
                                  letterSpacing: 0.3)),
                              const SizedBox(width: 8),
                              Text('${keys.where((k) => _granted.contains(k)).length}/${keys.length}',
                                style: GoogleFonts.inter(
                                  fontSize: 10, fontWeight: FontWeight.w700,
                                  color: AppColors.textMuted)),
                              const Spacer(),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 38, height: 22,
                                decoration: BoxDecoration(
                                  color: allOn
                                      ? const Color(0xFF2563EB)
                                      : AppColors.border,
                                  borderRadius: BorderRadius.circular(11)),
                                child: AnimatedAlign(
                                  duration: const Duration(milliseconds: 200),
                                  alignment: allOn
                                      ? Alignment.centerRight
                                      : Alignment.centerLeft,
                                  child: Container(
                                    width: 18, height: 18, margin: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(
                                      color: Colors.white, shape: BoxShape.circle),
                                  ))),
                            ]),
                          ),
                        ),
                        // Module rows
                        ...modules.map((m) {
                          final key   = m.$1;
                          final label = m.$2;
                          final on    = _granted.contains(key);
                          return GestureDetector(
                            onTap: () => setState(() {
                              if (on) _granted.remove(key); else _granted.add(key);
                            }),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 11),
                              decoration: BoxDecoration(
                                border: Border(
                                  top: BorderSide(color: AppColors.borderLight))),
                              child: Row(children: [
                                Icon(Icons.radio_button_checked_rounded,
                                  size: 14,
                                  color: on
                                      ? const Color(0xFF2563EB)
                                      : AppColors.borderLight),
                                const SizedBox(width: 10),
                                Expanded(child: Text(label,
                                  style: GoogleFonts.inter(
                                    fontSize: 13, fontWeight: FontWeight.w600,
                                    color: on
                                        ? AppColors.textPrimary
                                        : AppColors.textMuted))),
                                if (on)
                                  const Icon(Icons.check_rounded,
                                    size: 16, color: Color(0xFF2563EB)),
                              ]),
                            ),
                          );
                        }),
                      ]),
                    );
                  }).toList(),
                ),
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
                        ? [const Color(0xFF2563EB).withValues(alpha: 0.5),
                           const Color(0xFF1D4ED8).withValues(alpha: 0.5)]
                        : [const Color(0xFF2563EB), const Color(0xFF1D4ED8)]),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: _saving ? [] : [BoxShadow(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                    blurRadius: 14, offset: const Offset(0, 5))]),
                child: Center(
                  child: _saving
                      ? const SizedBox(width: 22, height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white))
                      : Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.shield_rounded, color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                          Text('Save Permissions',
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

// ── Form field helpers ────────────────────────────────────────────────────────
class _FL extends StatelessWidget {
  final String text;
  const _FL(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
    style: GoogleFonts.plusJakartaSans(
      fontSize: 11.5, fontWeight: FontWeight.w800,
      color: AppColors.textMuted, letterSpacing: 0.3));
}

class _FF extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType? type;
  final TextCapitalization cap;

  const _FF(this.controller, this.hint, this.icon,
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
          contentPadding: const EdgeInsets.symmetric(
            vertical: 13, horizontal: 10)))),
    ]),
  );
}

class _DropField<T> extends StatelessWidget {
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  const _DropField({required this.value, required this.items, required this.onChanged});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: AppColors.bg, borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.border)),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<T>(
        value: value, isExpanded: true,
        style: GoogleFonts.inter(
          fontSize: 13, fontWeight: FontWeight.w600,
          color: AppColors.textPrimary),
        icon: const Icon(Icons.expand_more_rounded,
          size: 18, color: AppColors.textMuted),
        items: items, onChanged: onChanged)),
  );
}
