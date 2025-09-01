import 'package:flutter/cupertino.dart';
import '../../constants/constants.dart';

extension LayoutExt on BuildContext {
  Size get screenSize => MediaQuery.of(this).size;

  bool isDesktop() {
    return (screenSize.width >= kTabletWidth);
  }

  bool isTablet() {
    return (screenSize.width < kTabletWidth &&
        screenSize.width >= kMobileWidth);
  }

  bool isMobile() {
    return (screenSize.width < kMobileWidth);
  }

  T layout<T>(
    T base, {
    T? mobile,
    T? tablet,
    T? desktop,
  }) {
    if (screenSize.width < kMobileWidth) {
      return mobile ?? base;
    } else if (screenSize.width < kTabletWidth) {
      return tablet ?? base;
    } else {
      return desktop ?? base;
    }
  }
}
