import type { PromoFields, PromoPatch } from "@/lib/config/editing";
import { destinationLabel, FEATURE_LABELS } from "@/lib/config/labels";
import type {
  FeatureFlags,
  FeatureName,
  ResilienceSettings,
} from "@/lib/config/types";
import { Card, Field, Select, TextInput, Toggle } from "../ui";

const MS_PER_SECOND = 1000;
/** Usual upper end of the slider. The contract allows more; the demo does not need it. */
const MAX_LATENCY_SECONDS = 8;

export function PromoCard({
  promo,
  destinations,
  onChange,
}: {
  /** Null when the selected segment has no banner module. */
  promo: PromoFields | null;
  destinations: string[];
  onChange: (patch: PromoPatch) => void;
}) {
  if (!promo) {
    return (
      <Card title="Banner promocional">
        <p className="text-body text-secondary">
          Este segmento no tiene un banner en su inicio.
        </p>
      </Card>
    );
  }
  return (
    <Card title="Banner promocional">
      <div className="grid grid-cols-2 gap-3">
        <Field label="Título" htmlFor="promo-title">
          <TextInput
            id="promo-title"
            value={promo.title}
            onChange={(event) => onChange({ title: event.target.value })}
          />
        </Field>
        <Field label="Texto" htmlFor="promo-body">
          <TextInput
            id="promo-body"
            value={promo.body}
            onChange={(event) => onChange({ body: event.target.value })}
          />
        </Field>
        <Field label="Acción" htmlFor="promo-action">
          <TextInput
            id="promo-action"
            value={promo.actionLabel}
            onChange={(event) => onChange({ actionLabel: event.target.value })}
          />
        </Field>
        <Field label="Destino" htmlFor="promo-destination">
          {/* Only what the contract's allow-list offers can be chosen. */}
          <Select
            id="promo-destination"
            value={promo.destination}
            onChange={(event) => onChange({ destination: event.target.value })}
          >
            {destinations.map((destination) => (
              <option key={destination} value={destination}>
                {destinationLabel(destination)}
              </option>
            ))}
          </Select>
        </Field>
      </div>
    </Card>
  );
}

function SettingRow({
  label,
  checked,
  onChange,
}: {
  label: string;
  checked: boolean;
  onChange: (checked: boolean) => void;
}) {
  return (
    <li className="flex items-center justify-between py-3">
      <span className="text-body">{label}</span>
      <Toggle label={label} checked={checked} onChange={onChange} />
    </li>
  );
}

export function FeaturesCard({
  features,
  onChange,
}: {
  features: FeatureFlags;
  onChange: (feature: FeatureName, enabled: boolean) => void;
}) {
  const names = Object.keys(FEATURE_LABELS) as FeatureName[];
  return (
    <Card title="Funcionalidades">
      <ul>
        {names.map((feature) => (
          <SettingRow
            key={feature}
            label={FEATURE_LABELS[feature]}
            checked={features[feature]}
            onChange={(enabled) => onChange(feature, enabled)}
          />
        ))}
      </ul>
    </Card>
  );
}

export function ResilienceCard({
  resilience,
  onChange,
}: {
  resilience: ResilienceSettings;
  onChange: (patch: Partial<ResilienceSettings>) => void;
}) {
  const seconds = resilience.latencyMs / MS_PER_SECOND;
  // A latency published above the usual range stretches the slider instead of
  // being drawn at its end: the control never shows less than what is live.
  const sliderMax = Math.max(MAX_LATENCY_SECONDS, Math.ceil(seconds));
  return (
    <Card
      title="Laboratorio de resiliencia"
      description="Disponible solo en entornos de demostración"
    >
      <label htmlFor="latency" className="block text-body font-semibold">
        Latencia simulada: {seconds} s
      </label>
      <input
        id="latency"
        type="range"
        min={0}
        max={sliderMax}
        step={1}
        value={seconds}
        onChange={(event) =>
          onChange({ latencyMs: Number(event.target.value) * MS_PER_SECOND })
        }
        className="mt-3 w-full accent-ink-900"
      />
      <ul className="mt-2">
        <SettingRow
          label="Servicio de movimientos no disponible"
          checked={resilience.movementsUnavailable}
          onChange={(movementsUnavailable) => onChange({ movementsUnavailable })}
        />
        <SettingRow
          label="Aliado Seguros no disponible"
          checked={resilience.partnerInsuranceUnavailable}
          onChange={(partnerInsuranceUnavailable) =>
            onChange({ partnerInsuranceUnavailable })
          }
        />
      </ul>
    </Card>
  );
}
