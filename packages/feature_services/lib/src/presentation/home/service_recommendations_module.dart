import 'package:design_system/design_system.dart';
import 'package:feature_services/src/domain/service_catalog.dart';
import 'package:feature_services/src/presentation/service_icons.dart';
import 'package:feature_services/src/presentation/services_strings.dart';
import 'package:flutter/material.dart';
import 'package:module_kit/module_kit.dart';

/// The home modules the services domain owns, by the type the published
/// configuration names them with.
abstract final class ServicesModuleTypes {
  static const String serviceRecommendations = 'serviceRecommendations';
}

/// Registers the modules of the services domain. They draw only what
/// [catalog] knows.
void registerServicesHomeModules(
  HomeModuleRegistry registry, {
  ServiceCatalog catalog = ServiceCatalog.standard,
}) {
  registry.register(
    ServicesModuleTypes.serviceRecommendations,
    (context, module) =>
        ServiceRecommendationsModule(module: module, catalog: catalog),
  );
}

/// Home module "Para ti": the partner services published for the
/// customer's segment.
///
/// What is published is a list of names. A name this version does not know,
/// or a service that cannot be opened right now, is left out, and when none
/// is left the module takes no space at all.
class ServiceRecommendationsModule extends StatelessWidget {
  const ServiceRecommendationsModule({
    required this.module,
    required this.catalog,
    super.key,
  });

  /// Where the published list of names is.
  static const String servicesProp = 'services';

  /// More recommendations than this stop being recommendations. The rest of
  /// a longer list is ignored.
  static const int maxRecommendations = 4;

  final HomeModuleContext module;
  final ServiceCatalog catalog;

  /// The services to draw: published, known to this version and open,
  /// without repeats, in the published order.
  List<ServiceEntry> get _recommended {
    final published = switch (module.props[servicesProp]) {
      final List<Object?> names => names.whereType<String>(),
      _ => const <String>[],
    };

    final recommended = <ServiceEntry>[];
    for (final key in published.toSet()) {
      final entry = catalog.partner(key);
      if (entry == null) continue;
      if (module.destinations.resolve(entry.destination) == null) continue;
      recommended.add(entry);
      if (recommended.length == maxRecommendations) break;
    }
    return recommended;
  }

  @override
  Widget build(BuildContext context) {
    final recommended = _recommended;
    if (recommended.isEmpty) return HomeModuleBinding.hidden(module: module);

    return HomeModuleBinding(
      module: module,
      status: HomeModuleStatus.ready,
      child: ModuleContainer(
        title: ServicesStrings.recommendationsTitle,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (index, entry) in recommended.indexed) ...[
              if (index > 0) const SizedBox(height: AppSpacing.x3),
              LinkCard(
                icon: iconFor(entry.symbol),
                title: entry.title,
                description: entry.description,
                badge: ServicesStrings.partnerBadge,
                // Asked again on the tap: what is published may have
                // changed since the card was drawn.
                onTap: () => module.destinations
                    .resolve(entry.destination)
                    ?.call(context),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
