import 'package:feature_accounts/src/domain/movement.dart';
import 'package:flutter/material.dart';

/// The icon that stands for a movement in a list.
///
/// Income always gets the same arrow, whatever its category: seeing at a
/// glance that money came in matters more than what it came in for.
IconData movementIcon(Movement movement) {
  if (movement.isIncome) return Icons.south_east;

  return switch (movement.category) {
    MovementCategory.salary => Icons.work_outline,
    MovementCategory.transfer => Icons.north_east,
    MovementCategory.groceries => Icons.storefront_outlined,
    MovementCategory.dining => Icons.restaurant_outlined,
    MovementCategory.transport => Icons.directions_bus_outlined,
    MovementCategory.services => Icons.receipt_long_outlined,
    MovementCategory.entertainment => Icons.movie_outlined,
    MovementCategory.health => Icons.local_hospital_outlined,
    MovementCategory.cash => Icons.local_atm_outlined,
    MovementCategory.other => Icons.payments_outlined,
  };
}
