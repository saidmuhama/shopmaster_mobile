import 'package:flutter/material.dart';

class Responsive {
  final double width;
  final double height;

  const Responsive._(this.width, this.height);

  factory Responsive.of(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Responsive._(size.width, size.height);
  }

  // ── Breakpoints ─────────────────────────────────────────────────────────────
  bool get isPhone => width < 600;
  bool get isTablet => width >= 600;
  bool get isMidTablet => width >= 600 && width < 900;   // 600–899
  bool get isLargeTablet => width >= 900;

  // ── Content max-widths (centered containers) ─────────────────────────────
  double get maxContentWidth => isLargeTablet ? 1200.0 : (isMidTablet ? 800.0 : double.infinity);
  double get dialogMaxWidth => isLargeTablet ? 560.0 : (isMidTablet ? 480.0 : double.infinity);
  double get sheetMaxWidth => isLargeTablet ? 540.0 : (isMidTablet ? 460.0 : double.infinity);

  // Inline cart panel width for POS split-pane
  double get cartPanelWidth => isLargeTablet ? 340.0 : 300.0;

  // ── Grid helpers ─────────────────────────────────────────────────────────
  // POS product grid columns
  int get posColumns {
    if (width >= 1100) return 5;
    if (width >= 900) return 4;
    if (width >= 600) return 3;
    return 2;
  }

  // KPI / stat tile columns
  int get kpiCols {
    if (isLargeTablet) return 4;
    if (isMidTablet) return 2;
    return 2;
  }

  // Generic grid columns for cards
  int gridColumns(int phone, int tablet, [int? largeTablet]) {
    if (isLargeTablet) return largeTablet ?? tablet + 1;
    if (isTablet) return tablet;
    return phone;
  }

  // Form columns (1 on phone, 2 on tablet)
  int get formColumns => isTablet ? 2 : 1;

  // ── Spacing & sizing ─────────────────────────────────────────────────────
  double get hPad => isLargeTablet ? 32.0 : (isMidTablet ? 24.0 : 16.0);
  double get cardSpacing => isTablet ? 10.0 : 8.0;

  // Card aspect ratio for POS product cards
  double get posCardRatio => isTablet ? 0.82 : 0.73;

  // Font scale factor
  double get fontScale => isTablet ? 0.88 : 1.0;

  // Scaled font size
  double fs(double base) => base * fontScale;

  // ── Layout mode helpers ──────────────────────────────────────────────────
  // Should use side-by-side (split-pane) layout
  bool get useSplitPane => isTablet;

  // Should dialogs be centered and constrained
  bool get useConstrainedDialog => isTablet;
}
