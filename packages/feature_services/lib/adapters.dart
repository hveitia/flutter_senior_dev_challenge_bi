/// The implementations of the services ports on the device plugins: the web
/// view that shows a partner's page, what it leaves on the device and the
/// system browser.
///
/// For the composition root only. Nothing else in the workspace may import
/// it.
library;

export 'src/adapters/url_launcher_external_links.dart';
export 'src/adapters/web_view_mini_app_data.dart';
export 'src/adapters/web_view_mini_app_surface.dart';
