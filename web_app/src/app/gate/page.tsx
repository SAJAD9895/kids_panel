import Link from "next/link";
import { requireFamily } from "@/lib/session";
import { GateForm } from "./gate-form";

export default async function Gate({ searchParams }: { searchParams: Promise<{ next?: string }> }) {
  await requireFamily("/gate");
  const { next = "/parents" } = await searchParams;
  return (
    <main className="flex min-h-screen items-center justify-center bg-ui-surface px-s5">
      <div className="w-full max-w-ui-form-w rounded-lg bg-ui-bg p-s7 shadow-card">
        <h1 className="text-ui-h1">Grown-ups only</h1>
        <p className="mt-s2 text-ui-text-muted">A quick question to check a grown-up is here.</p>
        <div className="mt-s6"><GateForm next={next.startsWith("/parents") ? next : "/parents"} /></div>
        <Link href="/kids" className="mt-s5 inline-block text-ui-primary underline">Back to playing</Link>
      </div>
    </main>
  );
}
