"use client";

import { useRouter } from "next/navigation";
import { useState, type FormEvent } from "react";
import { signInForIdToken } from "@/lib/client/sign-in";
import { AlertIcon, Button, Field, TextInput } from "./ui";

// One message for every refusal: a wrong password, an unknown address and an
// address that is not an administrator are indistinguishable from outside.
const REFUSED =
  "No pudimos validar tu acceso. Revisa tus datos o pide que te agreguen como administrador.";

async function openSession(email: string, password: string): Promise<boolean> {
  try {
    const idToken = await signInForIdToken(email, password);
    const response = await fetch("/api/session", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ idToken }),
    });
    return response.ok;
  } catch {
    return false;
  }
}

export function LoginForm() {
  const router = useRouter();
  const [submitting, setSubmitting] = useState(false);
  const [refused, setRefused] = useState(false);

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const data = new FormData(event.currentTarget);
    setSubmitting(true);
    setRefused(false);
    const opened = await openSession(
      String(data.get("email") ?? "").trim(),
      String(data.get("password") ?? ""),
    );
    if (opened) {
      // Refreshed so the console is rendered on the server with the new cookie.
      router.replace("/");
      router.refresh();
      return;
    }
    setRefused(true);
    setSubmitting(false);
  }

  return (
    <form onSubmit={submit} className="grid gap-4">
      <Field label="Correo electrónico" htmlFor="email">
        <TextInput id="email" name="email" type="email" autoComplete="username" required />
      </Field>
      <Field label="Contraseña" htmlFor="password">
        <TextInput
          id="password"
          name="password"
          type="password"
          autoComplete="current-password"
          required
        />
      </Field>
      {refused ? (
        <p role="alert" className="flex items-start gap-2 text-caption text-danger-500">
          <AlertIcon />
          {REFUSED}
        </p>
      ) : null}
      <Button type="submit" disabled={submitting}>
        {submitting ? "Ingresando…" : "Ingresar"}
      </Button>
    </form>
  );
}
