import 'package:design_system/src/tokens/app_colors.dart';
import 'package:flutter/painting.dart';

/// Semantic tone of a status element. Each tone pairs a foreground that is
/// safe for text with the tint it is designed to sit on.
enum AppTone {
  success(AppColors.success500, AppColors.successTint),
  danger(AppColors.danger500, AppColors.dangerTint),
  warning(AppColors.warning500, AppColors.warningTint),
  info(AppColors.info500, AppColors.infoTint)
  ;

  const AppTone(this.foreground, this.tint);

  final Color foreground;
  final Color tint;
}
