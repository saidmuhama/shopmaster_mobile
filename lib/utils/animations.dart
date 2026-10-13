import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// ── Staggered list item ───────────────────────────────────────────────────────
// Supports two modes:
//  (a) self-managed: supply only [index], delays by index * baseDelay then plays
//  (b) parent-driven: supply [controller], derives interval from [index]
class StaggeredItem extends StatefulWidget {
  final Widget child;
  final int index;
  final Duration baseDelay;
  final AnimationController? controller;

  const StaggeredItem({
    super.key,
    required this.child,
    required this.index,
    this.baseDelay = const Duration(milliseconds: 60),
    this.controller,
  });

  @override
  State<StaggeredItem> createState() => _StaggeredItemState();
}

class _StaggeredItemState extends State<StaggeredItem>
    with SingleTickerProviderStateMixin {
  AnimationController? _owned;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  AnimationController get _ctrl => widget.controller ?? _owned!;

  @override
  void initState() {
    super.initState();

    if (widget.controller == null) {
      _owned = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    }

    final start = widget.controller != null
        ? (widget.index * 0.08).clamp(0.0, 0.8) : 0.0;
    final end = widget.controller != null
        ? (start + 0.35).clamp(0.0, 1.0) : 1.0;

    _fade = CurvedAnimation(
      parent: _ctrl,
      curve: Interval(start, end, curve: Curves.easeOut));
    _slide = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(CurvedAnimation(
          parent: _ctrl,
          curve: Interval(start, end, curve: Curves.easeOutCubic)));

    if (widget.controller == null) {
      Future.delayed(widget.baseDelay * widget.index, () {
        if (mounted) _owned!.forward();
      });
    }
  }

  @override
  void dispose() { _owned?.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _ctrl,
    builder: (_, child) => FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: child),
    ),
    child: widget.child,
  );
}

// ── Count-up number animation ─────────────────────────────────────────────────
class CountUpText extends StatefulWidget {
  final double target;   // alias: end
  final String prefix;
  final String suffix;
  final TextStyle? style;
  final Duration duration;
  final String Function(double)? formatter;

  const CountUpText({
    super.key,
    required this.target,
    this.prefix = '',
    this.suffix = '',
    this.style,
    this.duration = const Duration(milliseconds: 1200),
    this.formatter,
  });

  @override
  State<CountUpText> createState() => _CountUpTextState();
}

class _CountUpTextState extends State<CountUpText>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    _anim = Tween<double>(begin: 0, end: widget.target)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutExpo));
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(CountUpText old) {
    super.didUpdateWidget(old);
    if (old.target != widget.target) {
      // Re-animate from wherever we currently are to the new target
      final from = _anim.value;
      _ctrl.duration = widget.duration;
      _anim = Tween<double>(begin: from, end: widget.target)
          .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutExpo));
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _anim,
    builder: (_, __) {
      final val = widget.formatter != null
          ? widget.formatter!(_anim.value)
          : NumberFormat('#,##0').format(_anim.value.round());
      return Text('${widget.prefix}$val${widget.suffix}', style: widget.style);
    },
  );
}

// ── Pressable scale wrapper ───────────────────────────────────────────────────
class PressScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scale;

  const PressScale({
    super.key,
    required this.child,
    this.onTap,
    this.scale = 0.96,
  });

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 120));
    _scale = Tween<double>(begin: 1.0, end: widget.scale)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTapDown: (_) => _ctrl.forward(),
    onTapUp: (_) { _ctrl.reverse(); widget.onTap?.call(); },
    onTapCancel: () => _ctrl.reverse(),
    child: AnimatedBuilder(
      animation: _scale,
      builder: (_, child) => Transform.scale(scale: _scale.value, child: child),
      child: widget.child,
    ),
  );
}

// ── Page route with slide transition ─────────────────────────────────────────
Route<T> slideRoute<T>(Widget page) => PageRouteBuilder<T>(
  pageBuilder: (_, __, ___) => page,
  transitionDuration: const Duration(milliseconds: 350),
  reverseTransitionDuration: const Duration(milliseconds: 280),
  transitionsBuilder: (_, anim, sec, child) {
    final slide = Tween<Offset>(begin: const Offset(1.0, 0.0), end: Offset.zero)
        .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic));
    final fade = CurvedAnimation(parent: anim, curve: const Interval(0.0, 0.6));
    return FadeTransition(opacity: fade, child: SlideTransition(position: slide, child: child));
  },
);

// ── Floating pulsing orb ──────────────────────────────────────────────────────
class PulsingOrb extends StatefulWidget {
  final double size;
  final Color color;
  final Duration duration;
  const PulsingOrb({super.key, required this.size, required this.color,
    this.duration = const Duration(seconds: 4)});

  @override
  State<PulsingOrb> createState() => _PulsingOrbState();
}

class _PulsingOrbState extends State<PulsingOrb>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration)
      ..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.88, end: 1.12)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _scale,
    builder: (_, __) => Transform.scale(
      scale: _scale.value,
      child: Container(
        width: widget.size, height: widget.size,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      ),
    ),
  );
}
