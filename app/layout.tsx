import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "EdgeLab — Futures Market Apprenticeship",
  description: "A local-first, education-only deliberate-practice system for market context, playbook recognition, evidence, and honest review.",
  other: { "codex-preview": "development" },
  icons: { icon: "/favicon.svg", shortcut: "/favicon.svg" },
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return <html lang="en"><body>{children}</body></html>;
}
