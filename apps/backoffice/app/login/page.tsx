import { redirect } from "next/navigation";
import { LoginForm } from "@/components/login-form";
import { currentAdmin } from "@/lib/server/current-admin";

export default async function LoginPage() {
  if (await currentAdmin()) redirect("/");

  return (
    <main className="mx-auto grid min-h-screen max-w-sm content-center gap-6 p-6">
      <div>
        <p className="text-caption text-secondary">Banca Digital</p>
        <h1 className="font-heading text-title">Consola de experiencia</h1>
        <p className="mt-2 text-body text-secondary">
          Acceso para administradores autorizados.
        </p>
      </div>
      <LoginForm />
    </main>
  );
}
