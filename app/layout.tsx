import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Questbound Ascension",
  description: "A local-first productivity RPG for turning small actions into real momentum.",
  other: {
    "codex-preview": "development",
  },
  icons: {
    icon: "/favicon.svg",
    shortcut: "/favicon.svg",
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body className="antialiased">{children}</body>
    </html>
  );
}
