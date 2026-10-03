import 'package:flutter/painting.dart';

/// Elevation. Only floating elements (sheets, snackbars) cast a shadow.
abstract final class AppShadows {
  static const List<BoxShadow> floating = [
    BoxShadow(
      color: Color.fromRGBO(54, 55, 58, 0.10),
      offset: Offset(0, 8),
      blurRadius: 24,
    ),
  ];
}
