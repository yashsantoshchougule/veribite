import 'package:flutter/material.dart';

/// Responsive layout utilities for phone, flagship, and tablet screen sizes
class ResponsiveLayout {
  static bool isSmallPhone(BuildContext context) =>
      MediaQuery.of(context).size.width < 380 || MediaQuery.of(context).size.height < 680;

  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= 600;

  static double horizontalPadding(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    if (w < 380) return 12.0;
    if (w >= 600) return 32.0;
    return 20.0;
  }

  static double graphicHeight(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    if (h < 600) return 150.0;
    if (h < 700) return 190.0;
    if (h < 900) return 240.0;
    if (h >= 1000) return 320.0;
    return 260.0;
  }

  /// Wraps content in a centered container with a maximum width on tablets
  static Widget constrainedContainer({required Widget child, double maxWidth = 580.0}) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
