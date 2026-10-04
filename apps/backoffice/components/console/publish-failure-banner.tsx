import type { PublishFailure } from "@/lib/console/editor-state";
import { AlertIcon, Button } from "../ui";

interface Notice {
  message: string;
  action: "retry" | "reload" | "sign-in" | null;
}

function noticeFor(failure: PublishFailure): Notice {
  switch (failure.kind) {
    case "unavailable":
      return {
        message: "No pudimos publicar los cambios. Tus ediciones siguen aquí.",
        action: "retry",
      };
    case "conflict":
      return {
        message:
          failure.storedVersion === null
            ? "La configuración publicada cambió mientras editabas. Recarga la consola para partir de la versión actual."
            : `Otra persona publicó la versión v${failure.storedVersion} mientras editabas. Recarga la consola para partir de esa versión.`,
        action: "reload",
      };
    case "unauthorized":
      return {
        message: "Tu sesión terminó. Inicia sesión de nuevo para publicar.",
        action: "sign-in",
      };
    case "faults-not-allowed":
      return {
        message: "Este entorno no permite publicar fallos simulados.",
        action: null,
      };
    case "too-large":
      return {
        message:
          "La configuración supera el tamaño máximo y no se publicó. Acorta los textos editados.",
        action: null,
      };
    case "invalid":
      return {
        message: "La configuración no cumple el contrato y no se publicó. Revisa los campos editados.",
        action: null,
      };
  }
}

/** Says why a publication failed and what can be done about it. */
export function PublishFailureBanner({
  failure,
  onRetry,
  onReload,
  onSignIn,
}: {
  failure: PublishFailure;
  onRetry: () => void;
  onReload: () => void;
  onSignIn: () => void;
}) {
  const notice = noticeFor(failure);
  const actions = {
    retry: { label: "Reintentar", run: onRetry },
    reload: { label: "Recargar", run: onReload },
    "sign-in": { label: "Iniciar sesión", run: onSignIn },
  };
  const action = notice.action ? actions[notice.action] : null;

  return (
    <div
      role="alert"
      className="flex items-center gap-3 rounded-admin border border-danger-500 bg-danger-tint px-4 py-3 text-danger-500"
    >
      <AlertIcon />
      <p className="flex-1 text-body">{notice.message}</p>
      {action ? (
        <Button variant="text" onClick={action.run} className="text-danger-500">
          {action.label}
        </Button>
      ) : null}
    </div>
  );
}
