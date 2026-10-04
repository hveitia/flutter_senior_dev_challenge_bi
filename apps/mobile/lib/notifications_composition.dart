import 'package:app_platform/app_platform.dart';
import 'package:banca_digital/notifications_wiring.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:feature_notifications/adapters.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The notifications feature on Firebase Messaging, Firestore and the
/// device's own storage.
NotificationsDependencies composeNotifications({
  required SharedPreferences preferences,
  required ResiliencePolicy policy,
  required Telemetry telemetry,
}) {
  final firestore = FirebaseFirestore.instance;

  return NotificationsDependencies(
    repositoryFor: (uid) => DefaultNotificationsRepository(
      source: FirestoreInboxSource(firestore, uid: uid),
      policy: policy,
      telemetry: telemetry,
    ),
    devicesFor: (uid) => FirestoreDeviceStore(firestore, uid: uid),
    identity: SharedPreferencesDeviceIdentity(preferences),
    registrationMemory: SharedPreferencesRegistrationMemory(preferences),
    messaging: FirebasePushMessaging(FirebaseMessaging.instance, preferences),
    memory: SharedPreferencesPrimerMemory(preferences),
    settings: const ChannelSystemSettings(),
  );
}
