// The learning engine's item kinds (docs/games/content-requirements.md, the Flutter engine's
// contract), with the form fields the builder shows. The schema check (validate.ts) is the
// engine's own JSON Schema, so anything saved here is something the app can play.
export type FieldType = "text" | "int" | "choices" | "answers" | "letters" | "picture" | "enum" | "bool" | "pairs" | "bins" | "json";
export type Field = { name: string; label: string; type: FieldType; required?: boolean; help?: string; options?: string[]; min?: number; max?: number };
export type Kind = { kind: string; label: string; family: string; summary: string; fields: Field[] };

const prompt: Field = { name: "prompt", label: "Question (one short line)", type: "text", help: "Read aloud to the child" };
const hint: Field = { name: "hint", label: "Hint", type: "text", help: "Shown after a wrong try" };
const choices = (pictures = false): Field[] => [
  { name: "options", label: pictures ? "Options (one per line: label | picture)" : "Options (one per line)", type: "choices", required: true, help: "2–8 options" },
  { name: "correct", label: "Correct option(s)", type: "answers", required: true, help: "Type the right option exactly; several on separate lines" },
];

export const KINDS: Kind[] = [
  { kind: "multiple_choice", label: "Multiple choice", family: "Quizzes and choices", summary: "Tap the right answer", fields: [prompt, ...choices(), hint] },
  { kind: "image_choice", label: "Picture choice", family: "Quizzes and choices", summary: "Tap the right picture", fields: [prompt, ...choices(true), hint] },
  { kind: "audio_choice", label: "Listen and choose", family: "Quizzes and choices", summary: "Hear a question, tap the answer", fields: [{ ...prompt, required: true, help: "Heard, never shown" }, ...choices(), hint] },
  { kind: "fill_blank", label: "Fill the gap", family: "Words", summary: "Pick the missing word", fields: [{ name: "sentence", label: "Sentence with ___", type: "text", required: true }, ...choices(), hint] },
  { kind: "word_build", label: "Word building", family: "Words", summary: "Put letters in order", fields: [{ name: "word", label: "Word (1–8 letters)", type: "text", required: true }, { name: "extra", label: "Decoy letters", type: "letters" }, { name: "picture", label: "Picture (the hint)", type: "picture" }, hint] },
  { kind: "letter_recognition", label: "Alphabet: find the letter", family: "Alphabet", summary: "Find a letter by name, sound or case", fields: [{ name: "target", label: "Letter", type: "text", required: true }, { name: "mode", label: "Ask by", type: "enum", options: ["name", "sound", "case"] }, { name: "distractors", label: "Other letters", type: "letters" }, hint] },
  { kind: "trace", label: "Alphabet: trace", family: "Alphabet", summary: "Trace a letter or number", fields: [{ name: "glyph", label: "Letter or number", type: "text", required: true, help: "a–h, o, l, x, 0–9 and most capitals" }] },
  { kind: "number_recognition", label: "Numbers: count or find", family: "Numbers", summary: "Count things, or find a number", fields: [{ name: "count", label: "How many to count (1–10)", type: "int", min: 1, max: 10 }, { name: "picture", label: "Picture to count", type: "picture" }, { name: "target", label: "…or the number to find (0–20)", type: "int", min: 0, max: 20 }, hint] },
  { kind: "arithmetic", label: "Numbers: add or take away", family: "Numbers", summary: "Small sums", fields: [{ name: "a", label: "First number", type: "int", required: true, min: 0, max: 10 }, { name: "op", label: "Sign", type: "enum", options: ["+", "-"] }, { name: "b", label: "Second number", type: "int", required: true, min: 0, max: 10 }, { name: "picture", label: "Picture to count with", type: "picture" }, hint] },
  { kind: "match_pairs", label: "Picture matching", family: "Matching and memory", summary: "Join each pair", fields: [prompt, { name: "pairs", label: "Pairs (one per line: left = right)", type: "pairs", required: true }] },
  { kind: "memory", label: "Memory", family: "Matching and memory", summary: "Turn cards to find pairs", fields: [{ name: "cards", label: "Card faces (one per line: label | picture)", type: "choices", required: true, help: "2–8; each appears twice" }, { name: "timer", label: "Show a timer", type: "bool" }] },
  { kind: "sort", label: "Sorting", family: "Sorting and drag-and-drop", summary: "Put things in the right group", fields: [prompt, { name: "bins", label: "Groups (one per line)", type: "choices", required: true }, { name: "items", label: "Things (one per line: label | picture = group)", type: "bins", required: true }] },
  { kind: "drag_to_target", label: "Drag and drop", family: "Sorting and drag-and-drop", summary: "Drag each piece onto its place", fields: [prompt, { name: "tokens", label: "Pieces (one per line)", type: "choices", required: true }, { name: "targets", label: "Places (one per line)", type: "choices", required: true }, { name: "solution", label: "Answers (one per line: piece = place)", type: "pairs", required: true }] },
  { kind: "puzzle", label: "Puzzle (swap)", family: "Puzzles", summary: "Swap tiles to finish the picture", fields: [{ name: "picture", label: "Picture", type: "picture", required: true }, { name: "grid", label: "Grid size (2–4)", type: "int", min: 2, max: 4 }] },
  { kind: "jigsaw", label: "Jigsaw", family: "Puzzles", summary: "Drag pieces onto the board", fields: [{ name: "picture", label: "Picture", type: "picture", required: true }, { name: "grid", label: "Grid size (2–4)", type: "int", min: 2, max: 4 }] },
  { kind: "shape_complete", label: "Finish the shape", family: "Puzzles", summary: "Find the missing part", fields: [{ name: "shape", label: "Shape", type: "enum", required: true, options: ["circle", "square", "triangle", "star", "heart"] }, { name: "missing", label: "Missing side", type: "enum", options: ["left", "right", "top", "bottom"] }] },
];
export const kindOf = (k: string) => KINDS.find((x) => x.kind === k);

/** The brief's game types → the engine kinds that make them. */
export const GAME_TYPES: { label: string; kinds: string[] }[] = [
  { label: "Multiple-choice games", kinds: ["multiple_choice", "image_choice", "audio_choice"] },
  { label: "Image matching", kinds: ["match_pairs", "image_choice"] },
  { label: "Memory", kinds: ["memory"] },
  { label: "Word building", kinds: ["word_build", "fill_blank"] },
  { label: "Number games", kinds: ["number_recognition", "arithmetic"] },
  { label: "Alphabet games", kinds: ["letter_recognition", "trace"] },
  { label: "Sorting", kinds: ["sort"] },
  { label: "Puzzles", kinds: ["puzzle", "jigsaw", "shape_complete"] },
  { label: "Quizzes", kinds: ["multiple_choice", "audio_choice"] },
  { label: "Drag and drop", kinds: ["drag_to_target", "sort"] },
];

export const PICTURE_HELP =
  "Built-in pictures: shape:circle, icon:apple, char:pip, glyph:A, count:3:star, or asset:<media id> for an uploaded image.";
