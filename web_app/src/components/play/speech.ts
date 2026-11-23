"use client";
// Speaking prompts and options with the browser's own voice (the app uses on-device TTS too).
// Silent when the browser has no speech or the child switched sound off.
let muted = false;
export const setMuted = (m: boolean) => { muted = m; if (m) window.speechSynthesis?.cancel(); };
export function speak(text: string) {
  if (muted || !text || typeof window === "undefined" || !("speechSynthesis" in window)) return;
  window.speechSynthesis.cancel();
  const u = new SpeechSynthesisUtterance(text);
  u.rate = 0.9;
  u.lang = "en";
  window.speechSynthesis.speak(u);
}
