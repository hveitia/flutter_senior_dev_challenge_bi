import 'package:feature_home/src/modules/promo_banner_module.dart';
import 'package:feature_home/src/modules/quick_actions_module.dart';
import 'package:module_kit/module_kit.dart';

/// The modules the home itself owns: they carry no data, only what the
/// configuration publishes for them.
abstract final class HomeModuleTypes {
  static const String quickActions = 'quickActions';
  static const String promoBanner = 'promoBanner';
}

/// Registers the modules owned by the home.
void registerHomeModules(HomeModuleRegistry registry) {
  registry
    ..register(
      HomeModuleTypes.quickActions,
      (context, module) => QuickActionsModule(module: module),
    )
    ..register(
      HomeModuleTypes.promoBanner,
      (context, module) => PromoBannerModule(module: module),
    );
}
