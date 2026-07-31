import 'package:flutter/widgets.dart';

/// Shared responsive rules for the public, private and administration areas.
class ResponsiveBreakpoints {
  static const double smallMobile = 360;
  static const double mobile = 480;
  static const double tablet = 768;
  static const double largeTablet = 820;
  static const double desktop = 1024;
  static const double wideDesktop = 1180;
}

class Responsive {
  const Responsive._();

  static ResponsiveData of(BuildContext context) {
    return ResponsiveData(MediaQuery.of(context).size.width);
  }

  static double horizontalPadding(double width) {
    if (width < ResponsiveBreakpoints.smallMobile) return 16;
    if (width < ResponsiveBreakpoints.mobile) return 20;
    if (width < ResponsiveBreakpoints.tablet) return 24;
    if (width < ResponsiveBreakpoints.desktop) return 32;
    return 40;
  }

  static double contentMaxWidth(double width) {
    if (width < ResponsiveBreakpoints.tablet) return double.infinity;
    if (width < ResponsiveBreakpoints.desktop) return 960;
    return 1120;
  }

  static int gridColumns(
    double width, {
    int small = 1,
    int medium = 2,
    int large = 3,
    int wide = 4,
  }) {
    if (width < ResponsiveBreakpoints.mobile) return small;
    if (width < ResponsiveBreakpoints.desktop) return medium;
    if (width < ResponsiveBreakpoints.wideDesktop) return large;
    return wide;
  }

  static double textScale(double width) {
    if (width < ResponsiveBreakpoints.smallMobile) return 0.9;
    if (width < ResponsiveBreakpoints.mobile) return 0.95;
    return 1;
  }
}

class ResponsiveData {
  final double width;

  const ResponsiveData(this.width);

  bool get isSmallMobile => width < ResponsiveBreakpoints.smallMobile;
  bool get isMobile => width < ResponsiveBreakpoints.tablet;
  bool get isTablet =>
      width >= ResponsiveBreakpoints.tablet &&
      width < ResponsiveBreakpoints.desktop;
  bool get isDesktop => width >= ResponsiveBreakpoints.desktop;
  bool get isWideDesktop => width >= ResponsiveBreakpoints.wideDesktop;

  double get horizontalPadding => Responsive.horizontalPadding(width);
  double get contentMaxWidth => Responsive.contentMaxWidth(width);
  double get textScale => Responsive.textScale(width);

  int gridColumns({
    int small = 1,
    int medium = 2,
    int large = 3,
    int wide = 4,
  }) {
    return Responsive.gridColumns(
      width,
      small: small,
      medium: medium,
      large: large,
      wide: wide,
    );
  }
}

extension ResponsiveBuildContext on BuildContext {
  ResponsiveData get responsive => Responsive.of(this);
}
