import 'package:flutter/material.dart';

class Responsive {
  final double width;
  final double height;

  const Responsive._(this.width, this.height);

  factory Responsive.of(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Responsive._(size.width, size.height);
  }

  bool get isTablet => width >= 600;
  bool get isLargeTablet => width >= 900;
  bool get isPhone => width < 600;

  // POS grid columns
  int get posColumns {
    if (width >= 1100) return 5;
    if (width >= 900) return 4;
    if (width >= 600) return 3;
    return 2;
  }

  // Generic grid columns for cards
  int gridColumns(int phone, int tablet, [int? largeTablet]) {
    if (isLargeTablet) return largeTablet ?? tablet + 1;
    if (isTablet) return tablet;
    return phone;
  }

  // Horizontal padding
  double get hPad => isTablet ? 24.0 : 16.0;

  // Card aspect ratio for POS product cards
  double get posCardRatio => isTablet ? 0.82 : 0.73;

  // Font scale factor
  double get fontScale => isTablet ? 0.88 : 1.0;

  // Scaled font size
  double fs(double base) => base * fontScale;

  // Spacing
  double get cardSpacing => isTablet ? 10.0 : 8.0;
}
