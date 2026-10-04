"use client";

import { useState, type FormEvent } from "react";
import { dateTimeLabel, destinationLabel } from "@/lib/config/labels";
import {
  BODY_MAX_LENGTH,
  TITLE_MAX_LENGTH,
  type PushField,
  type PushRecord,
  type PushStatus,
} from "@/lib/push/types";
import {
  AlertIcon,
  Button,
  Card,
  CheckIcon,
  Field,
  InfoIcon,
  Select,
  TextArea,
  TextInput,
} from "../ui";

const SEGMENT_AUDIENCE = "segment";
const CUSTOMER_AUDIENCE = "customer";

const FIELD_ERRORS: Record<PushField, string> = {
  title: `Escribe un título de hasta ${TITLE_MAX_LENGTH} caracteres.`,
  body: `Escribe un mensaje de hasta ${BODY_MAX_LENGTH} caracteres.`,
  audience: "Indica un correo válido del cliente.",
  destination: "Elige un destino de la lista.",
};

const STATUS: Record<PushStatus, { label: string; tone: string; icon: React.ReactNode }> = {
  sent: { label: "Enviado", tone: "text-success-500", icon: <CheckIcon /> },
  // A dry run the service accepted. It was not delivered and is not shown as sent.
  validated: { label: "Validado", tone: "text-info-500", icon: <InfoIcon /> },
  failed: { label: "Fallido", tone: "text-danger-500", icon: <AlertIcon /> },
};

type Submission =
  | { state: "idle" }
  | { state: "sending" }
  | { state: "invalid"; fields: PushField[] }
  | { state: "error"; message: string };

async function post(body: object): Promise<Response> {
  return fetch("/api/push", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(body),
  });
}

const UNAVAILABLE = "No pudimos enviar la notificación. Intenta de nuevo.";
const SESSION_ENDED = "Tu sesión terminó. Inicia sesión de nuevo.";

export function PushCard({
  segmentId,
  segmentLabel,
  destinations,
  initialHistory,
  dryRun,
}: {
  segmentId: string;
  segmentLabel: string;
  destinations: string[];
  initialHistory: PushRecord[];
  dryRun: boolean;
}) {
  const [history, setHistory] = useState(initialHistory);
  const [submission, setSubmission] = useState<Submission>({ state: "idle" });
  const [audienceKind, setAudienceKind] = useState(SEGMENT_AUDIENCE);
  const [retrying, setRetrying] = useState<string | null>(null);

  const errorOf = (field: PushField) =>
    submission.state === "invalid" && submission.fields.includes(field)
      ? FIELD_ERRORS[field]
      : undefined;

  async function send(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const form = event.currentTarget;
    const data = new FormData(form);
    setSubmission({ state: "sending" });
    try {
      const response = await post({
        title: data.get("title"),
        body: data.get("body"),
        destination: data.get("destination"),
        audience:
          audienceKind === CUSTOMER_AUDIENCE
            ? { kind: CUSTOMER_AUDIENCE, email: data.get("email") }
            : { kind: SEGMENT_AUDIENCE, segmentId },
      });
      const payload = (await response.json()) as {
        record?: PushRecord;
        fields?: PushField[];
      };
      if (response.ok && payload.record) {
        setHistory((rows) => [payload.record!, ...rows]);
        setSubmission({ state: "idle" });
        form.reset();
      } else if (response.status === 400 && payload.fields) {
        setSubmission({ state: "invalid", fields: payload.fields });
      } else {
        setSubmission({
          state: "error",
          message: response.status === 401 ? SESSION_ENDED : UNAVAILABLE,
        });
      }
    } catch {
      setSubmission({ state: "error", message: UNAVAILABLE });
    }
  }

  async function retry(id: string) {
    setRetrying(id);
    try {
      const response = await post({ retryOf: id });
      const payload = (await response.json()) as { record?: PushRecord };
      if (response.ok && payload.record) {
        const updated = payload.record;
        setHistory((rows) => rows.map((row) => (row.id === id ? updated : row)));
      }
    } catch {
      // The row stays failed; the button is there to try again.
    } finally {
      setRetrying(null);
    }
  }

  return (
    <Card
      title="Enviar notificación"
      description={
        dryRun
          ? "Modo de prueba: el servicio valida cada envío, pero no lo entrega."
          : undefined
      }
    >
      <form onSubmit={send} className="grid gap-3" noValidate>
        <Field label="Título" htmlFor="push-title" error={errorOf("title")}>
          <TextInput
            id="push-title"
            name="title"
            maxLength={TITLE_MAX_LENGTH}
            placeholder="Una novedad para ti"
          />
        </Field>
        <Field label="Mensaje" htmlFor="push-body" error={errorOf("body")}>
          <TextArea
            id="push-body"
            name="body"
            rows={2}
            maxLength={BODY_MAX_LENGTH}
            placeholder="Escribe un mensaje claro y breve"
          />
        </Field>
        <div className="grid grid-cols-2 gap-3">
          <Field label="Audiencia" htmlFor="push-audience">
            <Select
              id="push-audience"
              value={audienceKind}
              onChange={(event) => setAudienceKind(event.target.value)}
            >
              <option value={SEGMENT_AUDIENCE}>Segmento: {segmentLabel}</option>
              <option value={CUSTOMER_AUDIENCE}>Un cliente</option>
            </Select>
          </Field>
          <Field
            label="Destino"
            htmlFor="push-destination"
            error={errorOf("destination")}
          >
            <Select id="push-destination" name="destination" defaultValue="inbox">
              {destinations.map((destination) => (
                <option key={destination} value={destination}>
                  {destinationLabel(destination)}
                </option>
              ))}
            </Select>
          </Field>
        </div>
        {audienceKind === CUSTOMER_AUDIENCE ? (
          <Field label="Correo del cliente" htmlFor="push-email" error={errorOf("audience")}>
            <TextInput id="push-email" name="email" type="email" autoComplete="off" />
          </Field>
        ) : null}
        {submission.state === "error" ? (
          <p role="alert" className="flex items-center gap-1 text-caption text-danger-500">
            <AlertIcon />
            {submission.message}
          </p>
        ) : null}
        <Button type="submit" disabled={submission.state === "sending"}>
          {submission.state === "sending" ? "Enviando…" : "Enviar"}
        </Button>
      </form>

      <table className="mt-6 w-full text-left text-caption">
        <caption className="sr-only">Historial de notificaciones</caption>
        <thead className="text-secondary">
          <tr className="border-b border-line">
            <th scope="col" className="py-2 font-semibold">Fecha y hora</th>
            <th scope="col" className="py-2 font-semibold">Título</th>
            <th scope="col" className="py-2 font-semibold">Audiencia</th>
            <th scope="col" className="py-2 font-semibold">Estado</th>
          </tr>
        </thead>
        <tbody>
          {history.length === 0 ? (
            <tr>
              <td colSpan={4} className="py-3 text-secondary">
                Aún no se ha enviado ninguna notificación.
              </td>
            </tr>
          ) : (
            history.map((row) => {
              const status = STATUS[row.status];
              return (
                <tr key={row.id} className="border-b border-line align-top">
                  <td className="py-2">{dateTimeLabel(row.createdAt)}</td>
                  <td className="py-2">{row.title}</td>
                  <td className="py-2">{row.audienceLabel}</td>
                  <td className="py-2">
                    <span className={`flex items-center gap-1 ${status.tone}`}>
                      {status.icon}
                      {status.label}
                    </span>
                    {row.status === "failed" ? (
                      <button
                        type="button"
                        onClick={() => retry(row.id)}
                        disabled={retrying === row.id}
                        className="mt-1 font-semibold text-brand-700 disabled:text-secondary"
                      >
                        {retrying === row.id ? "Reintentando…" : "Reintentar"}
                      </button>
                    ) : null}
                  </td>
                </tr>
              );
            })
          )}
        </tbody>
      </table>
    </Card>
  );
}
