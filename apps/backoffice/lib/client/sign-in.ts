import { getApps, initializeApp } from "firebase/app";
import {
  connectAuthEmulator,
  getAuth,
  inMemoryPersistence,
  setPersistence,
  signInWithEmailAndPassword,
  signOut,
} from "firebase/auth";

// Public identifiers of the Firebase web app; they are not credentials.
const firebaseConfig = {
  apiKey: process.env.NEXT_PUBLIC_FIREBASE_API_KEY,
  authDomain: process.env.NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN,
  projectId: process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID,
  appId: process.env.NEXT_PUBLIC_FIREBASE_APP_ID,
};

const authEmulatorUrl = process.env.NEXT_PUBLIC_FIREBASE_AUTH_EMULATOR_URL;

/**
 * Signs in with the identity provider and returns the short-lived token the
 * server exchanges for its session cookie. The browser keeps nothing: the
 * provider's own session is held in memory and closed straight away, so the
 * cookie is the only session there is.
 */
export async function signInForIdToken(
  email: string,
  password: string,
): Promise<string> {
  const existing = getApps()[0];
  const app = existing ?? initializeApp(firebaseConfig);
  const auth = getAuth(app);
  // A local stack signs in against the Auth emulator. The address is only
  // set when the console is started for one (docs/operacion/backoffice.md).
  if (!existing && authEmulatorUrl) {
    connectAuthEmulator(auth, authEmulatorUrl, { disableWarnings: true });
  }
  await setPersistence(auth, inMemoryPersistence);
  const credential = await signInWithEmailAndPassword(auth, email, password);
  const idToken = await credential.user.getIdToken();
  await signOut(auth);
  return idToken;
}
