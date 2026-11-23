import type { Metadata, Viewport } from "next";
import { configProblems } from "@/lib/env";
import "./globals.css";

export const metadata: Metadata = {
  title: { default: "Kids Learning", template: "%s · Kids Learning" },
  description: "Games, stories, songs and lessons for children aged 2 to 8, with a dashboard for grown-ups.",
};
export const viewport: Viewport = { width: "device-width", initialScale: 1 };

export default function RootLayout({ children }: { children: React.ReactNode }) {
  const problems = configProblems();
  return (
    <html lang="en">
      <body>
        {problems.length ? (
          <main className="mx-auto max-w-ui-form-w p-s7">
            <h1 className="text-ui-h1">Configuration needed</h1>
            <ul className="mt-s4 list-disc pl-s6">{problems.map((p) => <li key={p}>{p}</li>)}</ul>
          </main>
        ) : children}
      </body>
    </html>
  );
}
