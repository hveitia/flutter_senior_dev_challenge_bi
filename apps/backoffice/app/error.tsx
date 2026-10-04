"use client";

import { Button } from "@/components/ui";

/** Shown when the console cannot read what is published. */
export default function ConsoleError({ reset }: { reset: () => void }) {
  return (
    <main className="mx-auto grid min-h-screen max-w-sm content-center gap-4 p-6 text-center">
      <h1 className="font-heading text-title">No pudimos cargar la consola</h1>
      <p className="text-body text-secondary">
        La configuración publicada no se modificó. Intenta de nuevo en un momento.
      </p>
      <Button onClick={reset}>Reintentar</Button>
    </main>
  );
}
