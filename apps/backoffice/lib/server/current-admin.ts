import "server-only";
import { cookies } from "next/headers";
import { adminAuth, serverSettings } from "./firebase";
import { adminFromCookie, SESSION_COOKIE, type Admin } from "./session";

/**
 * The administrator making the current request, or null. Every page, action
 * and route handler that reads or changes anything calls this itself; there
 * is no outer layer whose check the inner code relies on.
 */
export async function currentAdmin(): Promise<Admin | null> {
  const jar = await cookies();
  return adminFromCookie(
    adminAuth(),
    serverSettings(),
    jar.get(SESSION_COOKIE)?.value,
  );
}
