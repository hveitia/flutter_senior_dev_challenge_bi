import type { FeatureName } from "./types";

/**
 * Names shown to the editor. The configuration carries identifiers; a name
 * missing here falls back to the identifier, so a module or destination added
 * to the contract still shows up before this file learns about it.
 */

const MODULE_LABELS: Record<string, string> = {
  totalBalance: "Saldo total",
  accountCarousel: "Cuentas",
  quickActions: "Acciones rápidas",
  promoBanner: "Banner promocional",
  recentMovements: "Últimos movimientos",
  serviceRecommendations: "Para ti",
  investmentSummary: "Inversiones",
};

const DESTINATION_LABELS: Record<string, string> = {
  transfer: "Transferencias",
  accounts: "Cuentas",
  services: "Servicios",
  inbox: "Notificaciones",
  profile: "Perfil",
  "partner:travelInsurance": "Seguro de viaje",
  "partner:recharge": "Recargas",
};

export const FEATURE_LABELS: Record<FeatureName, string> = {
  transfers: "Transferencias",
  partnerServices: "Servicios de aliados",
};

export function moduleLabel(type: string): string {
  return MODULE_LABELS[type] ?? type;
}

export function destinationLabel(destination: string): string {
  return DESTINATION_LABELS[destination] ?? destination;
}

const DATE_TIME = new Intl.DateTimeFormat("es-EC", {
  day: "numeric",
  month: "short",
  hour: "2-digit",
  minute: "2-digit",
  hour12: false,
  // Fixed so the server and the browser render the same text.
  timeZone: "America/Guayaquil",
});

/** A moment as the console shows it, in Ecuador time: `3 oct, 09:12`. */
export function dateTimeLabel(iso: string): string {
  return DATE_TIME.format(new Date(iso));
}
