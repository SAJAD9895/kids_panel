import type { Activity } from "./data/catalog";

/** Where an activity opens in the child zone. */
export const hrefFor = (a: Activity) =>
  a.type === "video" ? `/kids/watch/${a.id}` : a.type === "song" || a.type === "audio_story" ? `/kids/listen/songs/${a.id}` : a.type === "story" ? `/kids/listen/stories/${a.id}` : `/kids/play/${a.id}`;
