import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import '../theme/app_theme.dart';
import '../utils/animations.dart';
import '../utils/responsive.dart';

// ── Tablet-aware bottom sheet wrapper ────────────────────────────────────────
// Centers and constrains sheets to sheetMaxWidth on tablets.
class AppSheet extends StatelessWidget {
  final Widget child;
  final double? maxWidth;

  const AppSheet({super.key, required this.child, this.maxWidth});

  @override
  Widget build(BuildContext context) {
    final resp = Responsive.of(context);
    final mw = maxWidth ?? resp.sheetMaxWidth;
    if (!resp.isTablet || mw == double.infinity) return child;
    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: mw),
        child: child,
      ),
    );
  }
}

// ── Tablet-aware dialog wrapper ───────────────────────────────────────────────
// Use in showDialog builder to center and constrain dialog content on tablets.
class AppDialogSheet extends StatelessWidget {
  final Widget child;

  const AppDialogSheet({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final resp = Responsive.of(context);
    if (!resp.isTablet) return child;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: resp.dialogMaxWidth),
        child: child,
      ),
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────
class SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  const SectionHeader({super.key, required this.title, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    final resp = Responsive.of(context);
    final hPad = resp.hPad;
    return Padding(
      padding: EdgeInsets.fromLTRB(hPad, resp.isTablet ? 28 : 24, hPad, 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
            style: AppTextStyles.headingMedium.copyWith(
              fontSize: resp.isLargeTablet ? 20 : (resp.isMidTablet ? 18 : 16))),
          if (action != null)
            GestureDetector(
              onTap: onAction,
              child: Text(action!,
                style: GoogleFonts.inter(
                  fontSize: resp.isTablet ? 14 : 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryLight)),
            ),
        ],
      ),
    );
  }
}

// ── Animated stat card ────────────────────────────────────────────────────────
class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color bgColor;
  final String? trend;
  final bool trendUp;
  final VoidCallback? onTap;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.bgColor,
    this.trend,
    this.trendUp = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final resp = Responsive.of(context);
    final pad = resp.isTablet ? 22.0 : 18.0;
    final iconSz = resp.isTablet ? 50.0 : 42.0;
    final iconRadius = resp.isTablet ? 15.0 : 13.0;
    final valFontSz = resp.isLargeTablet ? 24.0 : (resp.isMidTablet ? 22.0 : 19.0);
    final lblFontSz = resp.isTablet ? 13.0 : 12.0;
    final borderColor = resp.isTablet
        ? const Color(0xFFCBD5E1)   // stronger, visible on white for tablet
        : AppColors.border;

    return PressScale(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(pad),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(resp.isTablet ? 22 : 20),
          border: Border.all(color: borderColor, width: resp.isTablet ? 1.5 : 1.0),
          boxShadow: resp.isTablet ? [
            BoxShadow(color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 16, offset: const Offset(0, 4)),
            BoxShadow(color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4, offset: const Offset(0, 1)),
          ] : AppShadows.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: iconSz, height: iconSz,
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(iconRadius)),
                  child: Icon(icon, color: color,
                    size: resp.isTablet ? 24 : 20),
                ),
                if (trend != null)
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: resp.isTablet ? 9 : 7,
                      vertical: resp.isTablet ? 4 : 3),
                    decoration: BoxDecoration(
                      color: trendUp ? AppColors.successBg : AppColors.dangerBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(
                        trendUp ? Icons.trending_up_rounded
                            : Icons.trending_down_rounded,
                        size: resp.isTablet ? 13 : 11,
                        color: trendUp ? AppColors.success : AppColors.danger),
                      const SizedBox(width: 3),
                      Text(trend!,
                        style: GoogleFonts.inter(
                          fontSize: resp.isTablet ? 11 : 10,
                          fontWeight: FontWeight.w800,
                          color: trendUp ? AppColors.successDark : AppColors.danger)),
                    ]),
                  ),
              ],
            ),
            SizedBox(height: resp.isTablet ? 16 : 14),
            Text(value,
              style: GoogleFonts.plusJakartaSans(
                fontSize: valFontSz, fontWeight: FontWeight.w900,
                color: AppColors.textPrimary, letterSpacing: -0.5, height: 1.1)),
            const SizedBox(height: 4),
            Text(label,
              style: GoogleFonts.inter(
                fontSize: lblFontSz, fontWeight: FontWeight.w600,
                color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }
}

// ── Dark hero stat card ───────────────────────────────────────────────────────
class HeroStatCard extends StatelessWidget {
  final String label;
  final Widget valueWidget;
  final IconData icon;
  final List<Color> gradient;
  final VoidCallback? onTap;

  const HeroStatCard({
    super.key,
    required this.label,
    required this.valueWidget,
    required this.icon,
    required this.gradient,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final resp = Responsive.of(context);
    return PressScale(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(resp.isTablet ? 24 : 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: gradient.first.withValues(alpha: resp.isTablet ? 0.35 : 0.3),
              blurRadius: resp.isTablet ? 24 : 16,
              offset: Offset(0, resp.isTablet ? 8 : 6)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: resp.isTablet ? 48 : 40,
                  height: resp.isTablet ? 48 : 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, color: Colors.white, size: resp.isTablet ? 24 : 20),
                ),
                Icon(Icons.arrow_forward_ios_rounded,
                  color: Colors.white.withValues(alpha: 0.4), size: 14),
              ],
            ),
            SizedBox(height: resp.isTablet ? 20 : 16),
            DefaultTextStyle(
              style: GoogleFonts.plusJakartaSans(
                fontSize: resp.isTablet ? 26 : 22, fontWeight: FontWeight.w900,
                color: Colors.white, letterSpacing: -0.8),
              child: valueWidget,
            ),
            const SizedBox(height: 4),
            Text(label,
              style: GoogleFonts.inter(
                fontSize: resp.isTablet ? 13 : 12, fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.65))),
          ],
        ),
      ),
    );
  }
}

// ── Shimmer skeleton ──────────────────────────────────────────────────────────
class ShimmerBox extends StatelessWidget {
  final double width;
  final double height;
  final double radius;
  const ShimmerBox({super.key, required this.width, required this.height, this.radius = 8});

  @override
  Widget build(BuildContext context) => Shimmer.fromColors(
    baseColor: const Color(0xFFE8EDF2),
    highlightColor: const Color(0xFFF8FAFC),
    child: Container(
      width: width, height: height,
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(radius)),
    ),
  );
}

class ShimmerStatCard extends StatelessWidget {
  const ShimmerStatCard({super.key});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        ShimmerBox(width: 34, height: 34, radius: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ShimmerBox(width: 80, height: 15, radius: 5),
          const SizedBox(height: 5),
          ShimmerBox(width: 60, height: 10, radius: 4),
        ]),
      ],
    ),
  );
}

// ── Empty state ───────────────────────────────────────────────────────────────
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const EmptyState({super.key, required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            color: AppColors.bg,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 36, color: AppColors.textMuted),
        ),
        const SizedBox(height: 20),
        Text(title, style: AppTextStyles.headingSmall, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(subtitle,
          style: AppTextStyles.bodyMedium, textAlign: TextAlign.center),
      ]),
    ),
  );
}

// ── Error state ───────────────────────────────────────────────────────────────
class ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const ErrorState({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 64, height: 64,
          decoration: const BoxDecoration(
            color: AppColors.dangerBg, shape: BoxShape.circle),
          child: const Icon(Icons.cloud_off_rounded,
            size: 28, color: AppColors.danger),
        ),
        const SizedBox(height: 16),
        Text('Could not load data',
          style: AppTextStyles.headingSmall, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(message,
          style: AppTextStyles.bodyMedium.copyWith(fontSize: 12),
          textAlign: TextAlign.center, maxLines: 3, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 20),
        PressScale(
          onTap: onRetry,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(14),
              boxShadow: AppShadows.primary,
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.refresh_rounded, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Text('Try Again',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
            ]),
          ),
        ),
      ]),
    ),
  );
}

// ── Status badge ──────────────────────────────────────────────────────────────
class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final Color bgColor;
  const StatusBadge({super.key, required this.label, required this.color, required this.bgColor});

  factory StatusBadge.fromStatus(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return StatusBadge(label: 'Paid', color: AppColors.successDark, bgColor: AppColors.successBg);
      case 'partial':
        return StatusBadge(label: 'Partial', color: AppColors.warning, bgColor: AppColors.warningBg);
      case 'credit':
        return StatusBadge(label: 'Credit', color: AppColors.info, bgColor: AppColors.infoBg);
      case 'pending':
        return StatusBadge(label: 'Pending', color: AppColors.warning, bgColor: AppColors.warningBg);
      case 'refunded':
        return const StatusBadge(label: 'Refunded', color: Color(0xFF7C3AED), bgColor: Color(0xFFEDE9FE));
      default:
        return StatusBadge(label: status, color: AppColors.textMuted, bgColor: AppColors.bg);
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: bgColor, borderRadius: BorderRadius.circular(20)),
    child: Text(label,
      style: GoogleFonts.inter(
        fontSize: 10, fontWeight: FontWeight.w800, color: color)),
  );
}

// ── Premium app bar ───────────────────────────────────────────────────────────
class PremiumAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final List<Widget>? actions;

  const PremiumAppBar({
    super.key, required this.title, this.subtitle, this.actions});

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) => AppBar(
    backgroundColor: AppColors.primary,
    elevation: 0,
    titleSpacing: 20,
    title: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: GoogleFonts.plusJakartaSans(
          fontSize: 18, fontWeight: FontWeight.w900,
          color: Colors.white, letterSpacing: -0.4)),
        if (subtitle != null)
          Text(subtitle!, style: GoogleFonts.inter(
            fontSize: 11, fontWeight: FontWeight.w500,
            color: Colors.white.withValues(alpha: 0.5))),
      ],
    ),
    actions: actions != null
        ? [...actions!, const SizedBox(width: 8)]
        : const [SizedBox(width: 8)],
  );
}

// ── Pill filter row ───────────────────────────────────────────────────────────
class FilterPills extends StatelessWidget {
  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelect;

  const FilterPills({
    super.key, required this.options, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
    child: Row(
      children: options.map((opt) {
        final active = opt == selected;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            child: GestureDetector(
              onTap: () => onSelect(opt),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: active ? AppColors.primary : AppColors.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: active ? AppColors.primary : AppColors.border),
                  boxShadow: active ? AppShadows.primary : null,
                ),
                child: Text(opt,
                  style: GoogleFonts.inter(
                    fontSize: 12, fontWeight: FontWeight.w700,
                    color: active ? Colors.white : AppColors.textSecondary)),
              ),
            ),
          ),
        );
      }).toList(),
    ),
  );
}
