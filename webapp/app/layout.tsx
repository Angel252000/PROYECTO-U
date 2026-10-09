import "./globals.css";
import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Plataforma SINAES",
  description: "Autoevaluación y acreditación · Modelo de Grado 2025",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="es">
      <body>{children}</body>
    </html>
  );
}
