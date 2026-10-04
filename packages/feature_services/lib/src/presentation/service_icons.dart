import 'package:feature_services/src/domain/service_catalog.dart';
import 'package:flutter/material.dart';

/// How each pictogram of the catalog is drawn.
IconData iconFor(ServiceSymbol symbol) => switch (symbol) {
  ServiceSymbol.transfer => Icons.swap_horiz,
  ServiceSymbol.insurance => Icons.shield_outlined,
  ServiceSymbol.recharge => Icons.smartphone_outlined,
};
