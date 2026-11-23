import type { Metadata } from "next";
import { configProblems } from "@/lib/env";
import "./globals.css";

export const metadata: Metadata = { title: "Admin · Kids Learning Platform", robots: { index: false, follow: false } };

export default function RootLayout({ children }: { children: React.ReactNode }) {
  const problems = configProblems();
  return (
    <html lang="en">
      <body className="min-h-screen bg-ui-bg text-ui-text antialiased">
        {problems.length ? (
          <main className="mx-auto max-w-ui-form-w p-s8">
            <h1 className="text-ui-h1">This admin build can&apos;t start</h1>
            <ul className="mt-s5 list-disc pl-s7 text-ui-body">{problems.map((p) => <li key={p}>{p}</li>)}</ul>
          </main>
        ) : children}
      </body>
    </html>
  );
}
