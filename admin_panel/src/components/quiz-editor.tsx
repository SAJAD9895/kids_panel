"use client";
// Quiz questions (questions + answers rows): the app turns them into engine items.
import { useState } from "react";
import type { Question, QuestionInput } from "@/lib/data/games";
import { checkQuestion } from "@/lib/data/games";

const input = "w-full rounded-md border border-ui-border-input bg-ui-bg px-s3 min-h-tap-ui text-ui-body";
const btn = "min-h-tap-ui rounded-md border border-ui-border-input bg-ui-bg px-s4 text-ui-body hover:bg-ui-surface";
const TYPES = [
  { value: "single_choice", label: "One right answer" }, { value: "multi_choice", label: "Several right answers" },
  { value: "true_false", label: "True or false" }, { value: "listen_choose", label: "Listen and choose (read aloud)" },
] as const;

export function QuizEditor({ questions, save, canWrite }: {
  questions: Question[]; save: (q: QuestionInput, id?: string) => Promise<{ error?: string }>; canWrite: boolean;
}) {
  const [editing, setEditing] = useState<Question | "new" | null>(null);
  return (
    <div className="flex flex-col gap-s4">
      {questions.length === 0 && <p className="text-ui-body text-ui-text-muted">No questions yet.</p>}
      <ol className="flex flex-col gap-s3">
        {questions.map((q, i) => (
          <li key={q.id} className="rounded-md bg-ui-surface p-s4">
            <div className="flex flex-wrap items-start justify-between gap-s3">
              <div className="min-w-0">
                <p className="text-ui-body-strong break-words">{i + 1}. {q.prompt}</p>
                <ul className="mt-s2 flex flex-wrap gap-s2">{q.answers.map((a) => (
                  <li key={a.id} className={`rounded-pill px-s3 py-s1 text-ui-small ${a.correct ? "bg-ui-success-soft text-ui-success" : "bg-ui-bg"}`}>{a.correct ? "✓ " : ""}{a.text}</li>
                ))}</ul>
              </div>
              {canWrite && <button type="button" className={btn} onClick={() => setEditing(q)}>Edit</button>}
            </div>
          </li>
        ))}
      </ol>
      {canWrite && !editing && <div><button type="button" className={btn} onClick={() => setEditing("new")}>Add a question</button></div>}
      {editing && <QuestionForm key={editing === "new" ? "new" : editing.id} q={editing === "new" ? undefined : editing} onCancel={() => setEditing(null)}
        onSave={async (v) => { const r = await save(v, editing === "new" ? undefined : editing.id); if (!r.error) setEditing(null); return r; }} />}
    </div>
  );
}

function QuestionForm({ q, onSave, onCancel }: { q?: Question; onSave: (v: QuestionInput) => Promise<{ error?: string }>; onCancel: () => void }) {
  const [answers, setAnswers] = useState(q?.answers.map((a) => ({ text: a.text, correct: a.correct })) ?? [{ text: "", correct: true }, { text: "", correct: false }]);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  async function submit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const fd = new FormData(e.currentTarget);
    const v: QuestionInput = {
      prompt: String(fd.get("prompt") ?? ""), type: String(fd.get("type")) as QuestionInput["type"], difficulty: Number(fd.get("difficulty")) || 1,
      imageAssetId: null, audioAssetId: null, answers,
    };
    const p = checkQuestion(v);
    if (p.length) return setError(p.join(". ") + ".");
    setBusy(true);
    const r = await onSave(v);
    setBusy(false);
    setError(r.error ?? null);
  }
  return (
    <form onSubmit={submit} className="flex flex-col gap-s4 rounded-md border border-ui-primary p-s5" aria-label="Question">
      <label className="flex flex-col gap-s1"><span className="text-ui-body-strong">Question *</span><input name="prompt" defaultValue={q?.prompt} maxLength={200} className={input} /></label>
      <div className="grid gap-s3 md:grid-cols-2">
        <label className="flex flex-col gap-s1"><span className="text-ui-body-strong">Kind</span>
          <select name="type" defaultValue={q?.type ?? "single_choice"} className={input}>{TYPES.map((t) => <option key={t.value} value={t.value}>{t.label}</option>)}</select></label>
        <label className="flex flex-col gap-s1"><span className="text-ui-body-strong">Difficulty (1–5)</span><input name="difficulty" type="number" min={1} max={5} defaultValue={q?.difficulty ?? 1} className={input} /></label>
      </div>
      <fieldset className="flex flex-col gap-s3"><legend className="text-ui-body-strong">Answers (tick the right one)</legend>
        {answers.map((a, i) => (
          <div key={i} className="flex items-center gap-s3">
            <input type="checkbox" aria-label={`Answer ${i + 1} is correct`} checked={a.correct} className="size-icon-md accent-ui-primary"
              onChange={(e) => setAnswers((x) => x.map((y, j) => (j === i ? { ...y, correct: e.target.checked } : y)))} />
            <input aria-label={`Answer ${i + 1}`} value={a.text} maxLength={120} className={input}
              onChange={(e) => setAnswers((x) => x.map((y, j) => (j === i ? { ...y, text: e.target.value } : y)))} />
            <button type="button" className={btn} aria-label={`Remove answer ${i + 1}`} onClick={() => setAnswers((x) => x.filter((_, j) => j !== i))}>✕</button>
          </div>
        ))}
        {answers.length < 6 && <div><button type="button" className={btn} onClick={() => setAnswers((x) => [...x, { text: "", correct: false }])}>Add an answer</button></div>}
      </fieldset>
      {error && <p role="alert" className="text-ui-small text-ui-danger">{error}</p>}
      <div className="flex gap-s3">
        <button disabled={busy} className="min-h-tap-ui rounded-md bg-ui-primary px-s5 text-ui-on-primary">{busy ? "Saving…" : "Save question"}</button>
        <button type="button" className={btn} onClick={onCancel}>Cancel</button>
      </div>
    </form>
  );
}
