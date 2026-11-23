"use client";
/* eslint-disable @next/next/no-img-element -- pre-sized webp thumbnails from the public bucket */
import { useState } from "react";

/** A card picture that falls back to the title's first letter when there's no file (yet). */
export function Thumb({ src, letter, ink }: { src: string | null; letter: string; ink: string }) {
  const [broken, setBroken] = useState(false);
  if (!src || broken) return <span className={`flex size-full items-center justify-center font-display text-kids-title ${ink}`} aria-hidden>{letter}</span>;
  return <img src={src} alt="" loading="lazy" decoding="async" onError={() => setBroken(true)} className="size-full object-cover" />;
}
