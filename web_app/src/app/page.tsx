import Link from "next/link";
import { redirect } from "next/navigation";
import { currentUser } from "@/lib/session";

/** Signed-in families go straight to "Who's playing?"; everyone else sees a short welcome. */
export default async function Home() {
  const { user } = await currentUser();
  if (user) redirect("/who");
  return (
    <main className="kids flex min-h-screen flex-col items-center justify-center gap-s7 px-s5 py-s9 text-center">
      <h1 className="max-w-ui-form-w font-display text-kids-display">Play, learn and grow</h1>
      <p className="max-w-ui-form-w text-kids-body text-kids-ink-muted">Games, songs, stories and little lessons for children aged 2 to 8, made with care. Grown-ups get a calm dashboard to see what their children are learning.</p>
      <div className="flex flex-wrap justify-center gap-s4">
        <Link href="/sign-up" className="inline-flex min-h-tap-kids items-center rounded-xl bg-kids-play-fill px-s7 font-display text-kids-label shadow-kid-raised">Get started</Link>
        <Link href="/sign-in" className="inline-flex min-h-tap-kids items-center rounded-xl bg-kids-surface px-s7 font-display text-kids-label shadow-kid-raised">I have an account</Link>
      </div>
    </main>
  );
}
