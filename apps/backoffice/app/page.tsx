import { redirect } from "next/navigation";
import { Console } from "@/components/console/console";
import { countCustomers } from "@/lib/server/audiences";
import { loadConsoleState } from "@/lib/server/config-store";
import { currentAdmin } from "@/lib/server/current-admin";
import { adminDb, serverSettings } from "@/lib/server/firebase";
import { latestPushes } from "@/lib/server/push-store";
import { publishConfigAction } from "./actions";

const PUSH_HISTORY_ROWS = 10;

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
    <Console
      loaded={loaded}
      customers={customers}
      pushHistory={pushHistory}
      isDemo={settings.isDemo}
      pushDryRun={settings.pushDryRun}
      adminEmail={admin.email}
      publish={publishConfigAction}
    />
  );
}
