import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Consola de experiencia",
  description: "Herramienta interna para configurar la experiencia de Banca Digital.",
  robots: { index: false, follow: false },
};

export default function RootLayout({ children }: LayoutProps<"/">) {
  return (
    <html lang="es">
      <body>{children}</body>
    </html>
  );
}
