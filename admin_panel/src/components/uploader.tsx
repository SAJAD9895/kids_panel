"use client";
// Upload: the file goes straight from the browser to admin-staging/<your id>/… (allowed by the
// Storage policy for content editors with MFA), then the admin Edge Function checks it and
// moves it into the library. Large videos never pass through the Next.js server.
import { useState } from "react";
import { supabaseBrowser } from "@/lib/supabase/browser";
import { checkUpload } from "@/lib/data/media";

type Finalize = (v: { stagingPath: string; locale?: string; width?: number; height?: number; durationMs?: number }) => Promise<{ error?: string; asset?: { id: string; path: string } }>;

async function measure(file: File): Promise<{ width?: number; height?: number; durationMs?: number }> {
  const url = URL.createObjectURL(file);
  try {
    if (file.type.startsWith("image/")) {
      const img = new Image();
      await new Promise((ok, no) => { img.onload = ok; img.onerror = no; img.src = url; });
      return { width: img.naturalWidth, height: img.naturalHeight };
    }
    if (file.type.startsWith("audio/") || file.type.startsWith("video/")) {
      const el = document.createElement(file.type.startsWith("audio/") ? "audio" : "video");
      await new Promise((ok, no) => { el.onloadedmetadata = ok; el.onerror = no; el.src = url; });
      const out: { width?: number; height?: number; durationMs?: number } = { durationMs: Math.round(el.duration * 1000) };
      if (el instanceof HTMLVideoElement && el.videoWidth) Object.assign(out, { width: el.videoWidth, height: el.videoHeight });
      return out;
    }
  } catch {
    /* the server still checks the file; sizes are optional */
  } finally {
    URL.revokeObjectURL(url);
  }
  return {};
}

export function Uploader({ userId, maxMb, allowed, finalize }: { userId: string; maxMb: number; allowed: string[]; finalize: Finalize }) {
  const [state, setState] = useState<{ tone: "ok" | "err" | "busy"; text: string } | null>(null);
  async function onSubmit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const form = e.currentTarget;
    const fd = new FormData(form);
    const file = fd.get("file");
    if (!(file instanceof File) || !file.name) return setState({ tone: "err", text: "Choose a file." });
    const problem = checkUpload(file, maxMb, allowed);
    if (problem) return setState({ tone: "err", text: problem });
    setState({ tone: "busy", text: "Uploading…" });
    const path = `${userId}/${crypto.randomUUID()}-${file.name.replace(/\s+/g, "-")}`;
    const { error } = await supabaseBrowser().storage.from("admin-staging").upload(path, file, { contentType: file.type, upsert: false });
    if (error) return setState({ tone: "err", text: `Upload failed: ${error.message}` });
    setState({ tone: "busy", text: "Checking the file…" });
    const locale = String(fd.get("locale") ?? "").trim() || undefined;
    const r = await finalize({ stagingPath: path, locale, ...(await measure(file)) });
    if (r.error) return setState({ tone: "err", text: r.error });
    form.reset();
    setState({ tone: "ok", text: `Added ${r.asset?.path}` });
  }
  return (
    <form onSubmit={onSubmit} className="flex flex-wrap items-end gap-s4" aria-label="Upload a file">
      <label className="flex flex-col gap-s2"><span className="text-ui-body-strong">File</span>
        <input type="file" name="file" accept={allowed.join(",")} className="text-ui-body" /></label>
      <label className="flex flex-col gap-s2"><span className="text-ui-body-strong">Language (captions, narration)</span>
        <input name="locale" placeholder="en" className="rounded-md border border-ui-border-input px-s3 min-h-tap-ui" /></label>
      <button disabled={state?.tone === "busy"} className="min-h-tap-ui rounded-md bg-ui-primary px-s5 text-ui-body-strong text-ui-on-primary disabled:opacity-50">Upload</button>
      {state && <p role={state.tone === "err" ? "alert" : "status"} className={`w-full text-ui-body ${state.tone === "err" ? "text-ui-danger" : state.tone === "ok" ? "text-ui-success" : "text-ui-text-muted"}`}>{state.text}</p>}
      <p className="w-full text-ui-small text-ui-text-muted">Up to {maxMb} MB. Pictures (WebP, PNG, JPEG) are public; videos, audio, captions and packs are only served through short-lived links. The real file type is checked on the server.</p>
    </form>
  );
}
