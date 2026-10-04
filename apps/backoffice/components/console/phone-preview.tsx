import type { ReactNode } from "react";
import { isVisible } from "@/lib/config/editing";
import type {
  JsonObject,
  ModuleConfig,
  ResilienceSettings,
  SegmentConfig,
} from "@/lib/config/types";
import { AlertIcon, ClockIcon } from "../ui";

/**
 * A sketch of the home the mobile app would compose from the draft: same
 * modules, same order, same visibility. It is drawn with sample figures and
 * is not the app itself; the rules it mirrors are named where they apply.
 */

/** The app announces a slow connection after this long without an answer. */
const SLOW_THRESHOLD_MS = 3000;
const TRANSFER_DESTINATION = "transfer";
const PARTNER_PREFIX = "partner:";

function Section({ title, children }: { title?: string; children: ReactNode }) {
  return (
    <div>
      {title ? <p className="mb-2 font-heading text-body">{title}</p> : null}
      {children}
    </div>
  );
}

const tile = "rounded-card border border-line bg-surface-0 p-3";

function listOf(value: unknown): JsonObject[] {
  return Array.isArray(value)
    ? value.filter(
        (item): item is JsonObject =>
          typeof item === "object" && item !== null && !Array.isArray(item),
      )
    : [];
}

function text(value: unknown): string {
  return typeof value === "string" ? value : "";
}

function ModulePreview({
  item,
  segment,
  resilience,
}: {
  item: ModuleConfig;
  segment: SegmentConfig;
  resilience: ResilienceSettings;
}) {
  const { transfers, partnerServices } = segment.features;
  // A feature that is off hides its entry points instead of disabling them.
  const reachable = (destination: string) =>
    (transfers || destination !== TRANSFER_DESTINATION) &&
    (partnerServices || !destination.startsWith(PARTNER_PREFIX));

  switch (item.type) {
    case "totalBalance":
      return (
        <Section>
          <p className="text-overline uppercase tracking-wide text-secondary">Saldo total</p>
          <p className="font-heading text-title">$4,820.35</p>
        </Section>
      );
    case "accountCarousel":
      return (
        <div className="flex gap-2 overflow-hidden">
          <div className={`${tile} min-w-[70%]`}>
            <p className="text-caption">Cuenta de ahorros ****4821</p>
            <p className="font-heading text-body">$3,570.35</p>
          </div>
          <div className={`${tile} min-w-[70%]`}>
            <p className="text-caption">Cuenta corriente ****1093</p>
            <p className="font-heading text-body">$1,250.00</p>
          </div>
        </div>
      );
    case "quickActions": {
      const actions = listOf(item.props?.actions).filter((action) =>
        reachable(text(action.destination)),
      );
      return (
        <ul className="flex justify-between gap-2">
          {actions.map((action) => (
            <li key={text(action.label)} className="text-center text-overline">
              <span className="mx-auto mb-1 block size-9 rounded-admin border border-line bg-surface-0" />
              {text(action.label)}
            </li>
          ))}
        </ul>
      );
    }
    case "promoBanner": {
      const action = item.props?.action;
      const label =
        typeof action === "object" && action !== null && !Array.isArray(action)
          ? action
          : {};
      if (!reachable(text(label.destination))) return null;
      return (
        <div className="rounded-card bg-brand-50 p-3">
          <p className="font-heading text-body">{text(item.props?.title)}</p>
          <p className="text-caption text-secondary">{text(item.props?.body)}</p>
          <p className="mt-2 text-caption font-semibold text-brand-700">
            {text(label.label)} →
          </p>
        </div>
      );
    }
    case "recentMovements":
      return (
        <Section title="Últimos movimientos">
          {resilience.movementsUnavailable ? (
            <div className={`${tile} text-center text-caption`}>
              <span className="mx-auto mb-1 block w-fit text-danger-500">
                <AlertIcon />
              </span>
              No pudimos cargar tus movimientos
              <p className="mt-1 font-semibold text-brand-700">Reintentar</p>
            </div>
          ) : (
            <ul className={`${tile} divide-y divide-line text-caption`}>
              <li className="flex justify-between py-1">
                <span>Supermercado</span>
                <span>− $64.80</span>
              </li>
              <li className="flex justify-between py-1">
                <span>Nómina de septiembre</span>
                <span className="text-success-500">+ $1,850.00</span>
              </li>
            </ul>
          )}
        </Section>
      );
    case "serviceRecommendations":
      if (!partnerServices) return null;
      return (
        <Section title="Para ti">
          <div className="grid grid-cols-2 gap-2 text-caption">
            <div className={tile}>
              <p className="font-semibold">Seguro de viaje</p>
              <p className="text-secondary">
                {resilience.partnerInsuranceUnavailable
                  ? "No disponible por ahora"
                  : "Viaja protegido"}
              </p>
            </div>
            <div className={tile}>
              <p className="font-semibold">Recargas</p>
              <p className="text-secondary">Siempre en contacto</p>
            </div>
          </div>
        </Section>
      );
    case "investmentSummary":
      return (
        <Section title="Inversiones">
          <div className={tile}>
            <p className="font-heading text-body">$24,600.00</p>
            <p className="text-caption text-secondary">Ver inversiones</p>
          </div>
        </Section>
      );
    default:
      // The app skips a module type it does not know; so does the preview.
      return null;
  }
}

export function PhonePreview({
  segment,
  resilience,
}: {
  segment: SegmentConfig;
  resilience: ResilienceSettings;
}) {
  const visible = segment.modules.filter(isVisible);
  return (
    <aside aria-label="Vista previa" className="text-center">
      <p className="mb-3 text-caption">Vista previa en tiempo real</p>
      <div className="mx-auto w-[326px] overflow-hidden rounded-[24px] border border-line bg-surface-1 text-left">
        <div className="border-b-2 border-brand-500 bg-surface-0 px-4 py-3">
          <p className="text-overline text-secondary">Banca Digital</p>
          <p className="text-body font-semibold">Hola, Valentina</p>
        </div>
        {resilience.latencyMs >= SLOW_THRESHOLD_MS ? (
          <p className="flex items-center gap-2 bg-warning-tint px-4 py-2 text-caption text-warning-500">
            <ClockIcon />
            Conexión lenta. Seguimos intentando
          </p>
        ) : null}
        <div className="flex min-h-[420px] flex-col gap-5 p-4" data-testid="preview-modules">
          {visible.length === 0 ? (
            <p className="text-caption text-secondary">
              Este segmento no muestra ningún módulo.
            </p>
          ) : (
            visible.map((item) => (
              <ModulePreview
                key={item.id}
                item={item}
                segment={segment}
                resilience={resilience}
              />
            ))
          )}
        </div>
      </div>
      <p className="mt-3 text-caption text-secondary">
        {segment.label} · datos de ejemplo
      </p>
    </aside>
  );
}
