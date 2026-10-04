import { getApps, initializeApp } from "firebase/app";
import {
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
  const app = getApps()[0] ?? initializeApp(firebaseConfig);
  const auth = getAuth(app);
  await setPersistence(auth, inMemoryPersistence);
  const credential = await signInWithEmailAndPassword(auth, email, password);
  const idToken = await credential.user.getIdToken();
  await signOut(auth);
  return idToken;
}
