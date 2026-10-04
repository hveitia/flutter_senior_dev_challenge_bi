import { dateTimeLabel } from "@/lib/config/labels";
import { Button } from "../ui";

export interface TopBarProps {
  /** Live version, or null when nothing has been published. */
  configVersion: number | null;
  isDemo: boolean;
  lastPublishedAt: string | null;
  changes: number;
  canPublish: boolean;
  publishing: boolean;
  adminEmail: string;
  onPublish: () => void;
  onDiscard: () => void;
  onSignOut: () => void;
}

function changesLabel(changes: number): string {
  if (changes === 0) return "Sin cambios pendientes";
  return changes === 1 ? "1 cambio sin publicar" : `${changes} cambios sin publicar`;
}

export function TopBar({
  configVersion,
  isDemo,
  lastPublishedAt,
  changes,
  canPublish,
  publishing,
  adminEmail,
  onPublish,
  onDiscard,
  onSignOut,
}: TopBarProps) {
  return (
    <header className="flex flex-wrap items-center gap-4 border-b border-line bg-surface-0 px-6 py-4">
      <h1 className="font-heading text-title">Consola de experiencia</h1>
      <span className="rounded-chip bg-surface-2 px-3 py-1 text-caption font-semibold">
        {isDemo ? "Demostración" : "Producción"}
      </span>
      <span className="text-body text-secondary">
        {configVersion === null
          ? "Configuración sin publicar"
          : `Configuración v${configVersion}`}
      </span>

      <div className="ml-auto flex items-center gap-4">
        <div className="text-right text-caption">
          <p aria-live="polite" className="flex items-center justify-end gap-1 font-semibold">
            {changes > 0 ? (
              <span aria-hidden className="size-2 rounded-chip bg-brand-500" />
            ) : null}
            {changesLabel(changes)}
          </p>
          {lastPublishedAt ? (
            <p className="text-secondary">
              Última publicación: {dateTimeLabel(lastPublishedAt)}
            </p>
          ) : null}
        </div>
        {changes > 0 ? (
          <Button variant="text" onClick={onDiscard} disabled={publishing}>
            Descartar
          </Button>
        ) : null}
        <Button onClick={onPublish} disabled={!canPublish}>
          {publishing ? "Publicando…" : "Publicar cambios"}
        </Button>
        <div className="border-l border-line pl-4 text-right text-caption">
          <p className="text-secondary">{adminEmail}</p>
          <button type="button" onClick={onSignOut} className="font-semibold text-brand-700">
            Cerrar sesión
          </button>
        </div>
      </div>
    </header>
  );
}
