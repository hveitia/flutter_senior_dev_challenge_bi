import 'package:app_platform/src/config/config_repository.dart';
import 'package:flutter/services.dart';

const String _assetKey =
    'packages/app_platform/assets/default-home-config.json';

/// Loads the configuration shipped inside the app, used on a first launch
/// with no network and nothing cached yet.
BundledConfigLoader bundledConfigLoader(AssetBundle bundle) {
  return () => bundle.loadString(_assetKey);
}
