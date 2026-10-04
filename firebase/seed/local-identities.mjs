// The people of a local stack. They exist only inside the Firebase
// emulators of whoever runs `tool/local-stack.sh seed`: nothing here is an
// account of the real project, and the Auth emulator accepts any password.

/** Signs in to the console at http://localhost:3210. */
export const LOCAL_ADMIN = Object.freeze({
  email: 'admin@banca-digital.test',
  password: 'Consola#Local1',
  displayName: 'Administración Local',
});

/** Signs in to the app. Gets two accounts, an investment and movements. */
export const LOCAL_CUSTOMER = Object.freeze({
  email: 'cliente@banca-digital.test',
  password: 'Cliente#Local1',
  fullName: 'Valentina Andrade',
  // Passes the check digit of an Ecuadorian national id; it is a test value.
  nationalId: '1710034065',
  phone: '0991234567',
  segment: 'family',
  interests: ['saving', 'travel'],
});

/**
 * The profile document of [customer], with the fields and only the fields
 * the security rules accept for `users/{uid}`.
 */
export function profileOf(customer, createdAt) {
  return {
    fullName: customer.fullName,
    nationalId: customer.nationalId,
    email: customer.email,
    phone: customer.phone,
    segment: customer.segment,
    interests: [...customer.interests],
    createdAt,
  };
}

/** Where the emulators listen, from the environment or their defaults. */
export function emulatorHosts(env) {
  return {
    auth: env.FIREBASE_AUTH_EMULATOR_HOST || '127.0.0.1:9099',
    firestore: env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8080',
  };
}

const LOCAL_HOSTS = new Set(['127.0.0.1', 'localhost', '[::1]']);

/**
 * Whether [hostAndPort] is this machine. The local seed writes with the
 * emulator's owner token and creates people with known passwords, so it
 * refuses to talk to anything else.
 */
export function isLocalHost(hostAndPort) {
  const host = hostAndPort.slice(0, hostAndPort.lastIndexOf(':'));
  return LOCAL_HOSTS.has(host);
}
