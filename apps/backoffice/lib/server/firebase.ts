import "server-only";
import {
  applicationDefault,
  cert,
  getApps,
  initializeApp,
  type App,
} from "firebase-admin/app";
import { getAuth, type Auth } from "firebase-admin/auth";
import { getFirestore, type Firestore } from "firebase-admin/firestore";
import { getMessaging, type Messaging } from "firebase-admin/messaging";
import { offlineMessaging } from "./offline-messaging";
import { readServerSettings, type ServerSettings } from "./settings";

let settings: ServerSettings | undefined;

/** Settings read once; a wrong environment fails the first request loudly. */
export function serverSettings(): ServerSettings {
  settings ??= readServerSettings(process.env);
  return settings;
}

function adminApp(): App {
  const existing = getApps()[0];
  if (existing) return existing;
  const { projectId, serviceAccount, usesEmulators } = serverSettings();
  // The emulators of a local stack ask for no credentials, and whoever runs
  // one may have none for the project.
  if (usesEmulators) return initializeApp({ projectId });
  return initializeApp({
    // A deployment passes a service account through the environment; a
    // developer machine uses its own default credentials, so no key file is
    // ever needed in the repository.
    credential: serviceAccount ? cert(serviceAccount) : applicationDefault(),
    projectId,
  });
}

export function adminAuth(): Auth {
  return getAuth(adminApp());
}

export function adminDb(): Firestore {
  return getFirestore(adminApp());
}

export function adminMessaging(): Messaging {
  // The messaging service has no emulator: a local stack validates on the
  // spot and sends nothing. Only the two calls the console makes exist.
  if (serverSettings().usesEmulators) return offlineMessaging() as Messaging;
  return getMessaging(adminApp());
}
