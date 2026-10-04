import 'dart:math';

import 'package:app_settings/app_settings.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:feature_notifications/src/data/ports.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Field names of a device document. The console's sender reads `token` and
/// writes `unregistered` on a device the messaging service no longer knows.
abstract final class DeviceFields {
  static const String token = 'token';
  static const String platform = 'platform';
  static const String updatedAt = 'updatedAt';
}

/// The customer's devices in Firestore: `users/{uid}/devices/{deviceId}`.
final class FirestoreDeviceStore implements DeviceStore {
  FirestoreDeviceStore(FirebaseFirestore firestore, {required String uid})
    : _devices = firestore.collection('users').doc(uid).collection('devices');

  final CollectionReference<Map<String, Object?>> _devices;

  @override
  Future<void> save({
    required String deviceId,
    required String token,
    required String platform,
  }) {
    // The whole document is replaced, so a flag the console left on the
    // previous address does not carry over to the new one.
    return _devices.doc(deviceId).set({
      DeviceFields.token: token,
      DeviceFields.platform: platform,
      DeviceFields.updatedAt: FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> remove(String deviceId) => _devices.doc(deviceId).delete();
}

/// An identifier made up once per installation and kept on the device. It
/// names the installation, not the customer, so it survives a sign-out.
final class SharedPreferencesDeviceIdentity implements DeviceIdentity {
  SharedPreferencesDeviceIdentity(this._preferences, {Random? random})
    : _random = random ?? Random.secure();

  static const String _key = 'notifications.device_id';
  static const int _length = 20;
  static const String _alphabet = '0123456789abcdefghijklmnopqrstuvwxyz';

  final SharedPreferences _preferences;
  final Random _random;

  @override
  Future<String> id() async {
    final existing = _preferences.getString(_key);
    if (existing != null && existing.isNotEmpty) return existing;

    final created = String.fromCharCodes([
      for (var index = 0; index < _length; index++)
        _alphabet.codeUnitAt(_random.nextInt(_alphabet.length)),
    ]);
    await _preferences.setString(_key, created);
    return created;
  }

  @override
  String get platform =>
      defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';
}

/// [PrimerMemory] on the device. It is about the device, not the customer:
/// whoever answered "Ahora no" on this phone is not asked again by the app.
final class SharedPreferencesPrimerMemory implements PrimerMemory {
  SharedPreferencesPrimerMemory(this._preferences);

  static const String _key = 'notifications.primer_answered';

  final SharedPreferences _preferences;

  @override
  bool get wasAnswered => _preferences.getBool(_key) ?? false;

  @override
  Future<void> rememberAnswered() => _preferences.setBool(_key, true);
}

/// Opens the notification settings of this app in the system.
final class AppSystemSettings implements SystemSettings {
  const AppSystemSettings();

  @override
  Future<void> openNotificationSettings() =>
      AppSettings.openAppSettings(type: AppSettingsType.notification);
}
