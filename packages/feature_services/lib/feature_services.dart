/// The services of Banca Digital: the catalog of what the bank and its
/// partners offer, the Servicios section and the container a partner's mini
/// app runs in.
///
/// Nothing exported here depends on the web view or any other plugin. The
/// adapters that do live in `package:feature_services/adapters.dart` and
/// are meant for the composition root only.
library;

export 'src/data/stepwise_mini_app_data.dart';
export 'src/domain/partner_origin.dart' show PartnerOrigin;
export 'src/domain/service_catalog.dart';
export 'src/ports.dart';
export 'src/presentation/home/service_recommendations_module.dart'
    show ServicesModuleTypes, registerServicesHomeModules;
export 'src/presentation/services_routes.dart';
export 'src/services_dependencies.dart';
export 'src/services_telemetry.dart';
