import { redirect } from "next/navigation";
import { Suspense } from "react";
import { Console } from "@/components/console/console";
import { countCustomers } from "@/lib/server/audiences";
import { loadConsoleState } from "@/lib/server/config-store";
import { currentAdmin } from "@/lib/server/current-admin";
import { adminDb, serverSettings } from "@/lib/server/firebase";
import { latestPushes } from "@/lib/server/push-store";
import { publishConfigAction } from "./actions";

const PUSH_HISTORY_ROWS = 10;

/**
 * Shown only if the console has to wait for the address it reads its section
 * from. It names no section, so it cannot show the wrong one for an instant.
 */
function ConsoleFallback() {
  return (
    <div className="min-h-screen" aria-busy="true">
      <header className="border-b border-line bg-surface-0 px-6 py-4">
        <h1 className="font-heading text-title">Consola de experiencia</h1>
      </header>
      <p className="p-6 text-body text-secondary">Cargando la consola…</p>
    </div>
  );
}

export default async function ConsolePage() {
  const admin = await currentAdmin();
  if (!admin) redirect("/login");

  const db = adminDb();
  const settings = serverSettings();
  const [loaded, pushHistory] = await Promise.all([
    loadConsoleState(db),
    latestPushes(db, PUSH_HISTORY_ROWS),
  ]);
  const customers = await countCustomers(db, Object.keys(loaded.config.segments));

  return (
    // The console reads its section from the address; the boundary keeps
    // that read from ever deciding how the rest of the page is rendered.
    <Suspense fallback={<ConsoleFallback />}>
      <Console
        loaded={loaded}
        customers={customers}
        pushHistory={pushHistory}
        isDemo={settings.isDemo}
        pushDryRun={settings.pushDryRun}
        adminEmail={admin.email}
        publish={publishConfigAction}
      />
    </Suspense>
  );
}
