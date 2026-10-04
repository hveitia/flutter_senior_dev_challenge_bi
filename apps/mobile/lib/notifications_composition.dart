import 'package:app_platform/app_platform.dart';
import 'package:banca_digital/notifications_wiring.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:feature_notifications/adapters.dart';
import 'package:feature_notifications/feature_notifications.dart';
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
  final messaging = FirebasePushMessaging(
    FirebaseMessaging.instance,
    preferences,
  );

  return NotificationsDependencies(
    repositoryFor: (uid) => DefaultNotificationsRepository(
      source: FirestoreInboxSource(firestore, uid: uid),
      policy: policy,
      telemetry: telemetry,
    ),
    registrations: DeviceRegistrations(
      messaging: messaging,
      devicesFor: (uid) => FirestoreDeviceStore(firestore, uid: uid),
      identity: SharedPreferencesDeviceIdentity(preferences),
      memory: SharedPreferencesRegistrationMemory(preferences),
      telemetry: telemetry,
    ),
    // Listening from here on: a notification tapped before anyone is signed
    // in, or while the session is locked, waits for the customer to be in.
    opened: OpenedNotifications(messaging)..start(),
    messaging: messaging,
    memory: SharedPreferencesPrimerMemory(preferences),
    settings: const ChannelSystemSettings(),
  );
}
