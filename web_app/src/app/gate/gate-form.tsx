"use client";
import { useMemo, useState } from "react";
import { passGate } from "../zone-actions";

const WORDS = ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "eleven", "twelve"];

/** "Grown-ups only": a multiplication written in words, answered by typing digits. */
export function GateForm({ next }: { next: string }) {
  const [a, b] = useMemo(() => [3 + Math.floor(Math.random() * 7), 3 + Math.floor(Math.random() * 7)], []);
  const [value, setValue] = useState("");
  const [wrong, setWrong] = useState(false);
  return (
    <form className="flex flex-col gap-s4" onSubmit={async (e) => {
      e.preventDefault();
      if (Number(value) === a * b) await passGate(next);
      else { setWrong(true); setValue(""); }
    }}>
      <label htmlFor="gate-answer" className="text-ui-body">What is <strong>{WORDS[a]}</strong> times <strong>{WORDS[b]}</strong>? Type the number.</label>
      <input id="gate-answer" inputMode="numeric" autoComplete="off" value={value} onChange={(e) => setValue(e.target.value.replace(/\D/g, "").slice(0, 3))}
        aria-invalid={wrong} aria-describedby={wrong ? "gate-wrong" : undefined} className="min-h-tap-ui rounded-md border border-ui-border-input px-s4 text-ui-h2" />
      {wrong && <p id="gate-wrong" role="alert" className="text-ui-danger">Not quite. Try again.</p>}
      <button className="min-h-tap-ui rounded-md bg-ui-primary px-s5 text-ui-body-strong text-ui-on-primary">Continue</button>
    </form>
  );
}
