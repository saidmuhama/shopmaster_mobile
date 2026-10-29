import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/pin_service.dart';
import '../theme/app_theme.dart';

/// Shows a compact PIN confirmation bottom sheet before a sensitive action.
/// Returns `true` when the PIN was verified (or no PIN is set up).
/// Returns `false` when the user cancels or exhausts their attempts.
Future<bool> showPinConfirm(
  BuildContext context, {
  required String title,
  String subtitle = 'Enter your PIN to confirm',
  Color accentColor = AppColors.primary,
  IconData icon = Icons.lock_rounded,
}) async {
  final hasPIN = await PinService.hasPin();
  if (!hasPIN) return true; // no PIN configured — skip gate

  if (!context.mounted) return false;
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _PinConfirmSheet(
      title: title,
      subtitle: subtitle,
      accentColor: accentColor,
      icon: icon,
    ),
  );
  return result ?? false;
}

// ── Sheet widget ──────────────────────────────────────────────────────────────
class _PinConfirmSheet extends StatefulWidget {
  final String title, subtitle;
  final Color accentColor;
  final IconData icon;
  const _PinConfirmSheet({
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.icon,
  });

  @override
  State<_PinConfirmSheet> createState() => _PinConfirmSheetState();
}

class _PinConfirmSheetState extends State<_PinConfirmSheet>
    with SingleTickerProviderStateMixin {
  String _pin = '';
  String? _error;
  bool _verifying = false;
  int _attempts = 0;

  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _shakeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -12.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -12.0, end: 12.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 12.0, end: -8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    super.dispose();
  }

  void _onDigit(String d) {
    if (_pin.length >= 4 || _verifying) return;
    HapticFeedback.selectionClick();
    setState(() { _pin += d; _error = null; });
    if (_pin.length == 4) _verify();
  }

  void _onDelete() {
    if (_pin.isEmpty || _verifying) return;
    HapticFeedback.selectionClick();
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _error = null;
    });
  }

  Future<void> _verify() async {
    setState(() => _verifying = true);
    await Future.delayed(const Duration(milliseconds: 130));
    final ok = await PinService.verifyPin(_pin);
    if (!mounted) return;
    if (ok) {
      HapticFeedback.mediumImpact();
      Navigator.of(context).pop(true);
    } else {
      HapticFeedback.heavyImpact();
      _attempts++;
      if (_attempts >= 5) {
        Navigator.of(context).pop(false);
        return;
      }
      setState(() {
        _pin = '';
        _verifying = false;
        final left = 5 - _attempts;
        _error = 'Incorrect PIN. $left attempt${left == 1 ? '' : 's'} left.';
      });
      _shakeCtrl.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(24, 20, 24, 28 + bottomInset),
      decoration: const BoxDecoration(
        color: Color(0xFF0B1F15),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: Color(0xFF1A3D28), width: 1),
          left: BorderSide(color: Color(0xFF1A3D28), width: 1),
          right: BorderSide(color: Color(0xFF1A3D28), width: 1),
        ),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Drag handle
        Container(
          width: 40, height: 4,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(height: 20),

        // Action icon
        Container(
          width: 54, height: 54,
          decoration: BoxDecoration(
            color: widget.accentColor.withValues(alpha: 0.12),
            shape: BoxShape.circle,
            border: Border.all(
              color: widget.accentColor.withValues(alpha: 0.25), width: 1.5)),
          child: Icon(widget.icon, color: widget.accentColor, size: 26),
        ),
        const SizedBox(height: 12),

        Text(widget.title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18, fontWeight: FontWeight.w800,
            color: Colors.white, letterSpacing: -0.3)),
        const SizedBox(height: 4),
        Text(widget.subtitle,
          style: GoogleFonts.inter(
            fontSize: 12, fontWeight: FontWeight.w500,
            color: Colors.white.withValues(alpha: 0.42)),
          textAlign: TextAlign.center),
        const SizedBox(height: 22),

        // Dots + error, with shake
        AnimatedBuilder(
          animation: _shakeCtrl,
          builder: (_, child) => Transform.translate(
            offset: Offset(_shakeAnim.value, 0), child: child),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _SheetDots(count: _pin.length, color: widget.accentColor),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              child: _error != null
                ? Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(_error!,
                      style: GoogleFonts.inter(
                        fontSize: 12, fontWeight: FontWeight.w600,
                        color: AppColors.danger)))
                : const SizedBox.shrink()),
          ])),
        const SizedBox(height: 18),

        // Numpad
        _SheetNumPad(
          onDigit: _onDigit,
          onDelete: _onDelete,
          enabled: !_verifying,
        ),
        const SizedBox(height: 10),

        // Cancel
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text('Cancel',
            style: GoogleFonts.inter(
              fontSize: 13, fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.3))),
        ),
      ]),
    );
  }
}

// ── Dot indicators ────────────────────────────────────────────────────────────
class _SheetDots extends StatelessWidget {
  final int count;
  final Color color;
  const _SheetDots({required this.count, required this.color});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: List.generate(4, (i) {
      final filled = i < count;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          width: filled ? 18 : 16,
          height: filled ? 18 : 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled ? color : Colors.transparent,
            border: Border.all(
              color: filled ? color : Colors.white.withValues(alpha: 0.25),
              width: 2),
            boxShadow: filled
              ? [BoxShadow(
                  color: color.withValues(alpha: 0.5),
                  blurRadius: 10, spreadRadius: 0)]
              : const [],
          )));
    }),
  );
}

// ── Numpad ────────────────────────────────────────────────────────────────────
class _SheetNumPad extends StatelessWidget {
  final ValueChanged<String> onDigit;
  final VoidCallback onDelete;
  final bool enabled;
  const _SheetNumPad({
    required this.onDigit, required this.onDelete, this.enabled = true});

  @override
  Widget build(BuildContext context) {
    const rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['',  '0', '⌫'],
    ];
    return Column(
      children: rows.map((row) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: row.map((k) {
            if (k.isEmpty) return const SizedBox(width: 64, height: 64);
            return _SheetKey(
              label: k,
              isDelete: k == '⌫',
              enabled: enabled,
              onTap: () => k == '⌫' ? onDelete() : onDigit(k),
            );
          }).toList()),
      )).toList(),
    );
  }
}

class _SheetKey extends StatefulWidget {
  final String label;
  final bool isDelete, enabled;
  final VoidCallback onTap;
  const _SheetKey({
    required this.label, required this.onTap,
    this.isDelete = false, this.enabled = true});

  @override
  State<_SheetKey> createState() => _SheetKeyState();
}

class _SheetKeyState extends State<_SheetKey>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 100));
    _scale = Tween<double>(begin: 1.0, end: 0.88)
      .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTapDown: widget.enabled ? (_) => _ctrl.forward() : null,
    onTapUp: widget.enabled ? (_) { _ctrl.reverse(); widget.onTap(); } : null,
    onTapCancel: () => _ctrl.reverse(),
    child: AnimatedBuilder(
      animation: _scale,
      builder: (_, child) => Transform.scale(scale: _scale.value, child: child),
      child: Container(
        width: 64, height: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.isDelete
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.white.withValues(alpha: 0.09),
          border: Border.all(
            color: Colors.white.withValues(
              alpha: widget.isDelete ? 0.06 : 0.12),
            width: 1)),
        child: Center(
          child: widget.isDelete
            ? Icon(Icons.backspace_outlined,
                color: Colors.white.withValues(alpha: 0.55), size: 20)
            : Text(widget.label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 24, fontWeight: FontWeight.w600,
                  color: Colors.white))))));
}
