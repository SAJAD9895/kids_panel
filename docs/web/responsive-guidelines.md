# Web platform: responsive guidelines

Phase 15, 2026-11-21. One codebase serves four kinds of screen. Layouts change with the space and the input device, rather than stretching a phone layout across a desktop.

## 1. Sizes and inputs

| class | width (CSS px) | tested as | input |
| --- | --- | --- | --- |
| phone | < 640 | Pixel 7 (412 × 915) | touch |
| tablet | 640–1023 | 820 × 1180 portrait | touch |
| laptop | 1024–1279 | 1280 × 800 | mouse, keyboard |
| desktop | ≥ 1280 | 1440 × 900 | mouse, keyboard |

The breakpoints are Tailwind's defaults (`sm` 640, `md` 768, `lg` 1024, `xl` 1280). Every size comes from the design tokens (`docs/design/tokens/tokens.json` → `src/app/theme.css`), and a unit test fails on any hex colour, px value or arbitrary value in a component.

## 2. The child zone

| element | phone | tablet | laptop and desktop |
| --- | --- | --- | --- |
| sections (Home, Learn, Games, Watch, Listen, Me) | a bar along the bottom, icon and label, ≥ 56 px tall | the same bar | a **rail on the left** (`kids-rail-w` 112 px), ≥ 84 px targets |
| header | buddy, name, stars, a parent icon | the same, with "Grown-ups" written | the same |
| shelves (rows of cards) | scroll sideways, snapping to cards | scroll sideways | **wrap into a grid** (`auto-fill` of `kids-card-w`) from `xl` |
| course map | one column | one column, lessons alternating left and right | the same, within `ui-content-max` |
| answer tiles | 2 columns | 2–3 columns | 3–4 columns, capped at `ui-form-w` so tiles don't become giant |
| story reader | the picture above the words | the same | **the picture beside the words** |
| players | full width | full width | within `ui-content-max` (1200 px), centred |

**Touch and type.**
- **Touch targets:** at least `tap-kids` (64 px) for primary actions, and at least `tap-kids-secondary` (56 px) for secondary ones (the app's rule).
- **Type:** the kids' scale (`kids-display` 48 px, down to `kids-caption` 15 px). Stories use the reading font at `kids-reading-lg`.
- **Dragging:** draggable pieces have `touch-action: none`, so a drag doesn't scroll the page. The trace board does the same. Elsewhere the page scrolls normally.

## 3. The grown-up area

| element | phone | tablet | laptop and desktop |
| --- | --- | --- | --- |
| navigation | a Menu button opens the list | the same | a **sidebar** (`ui-sidebar-w` 256 px) with "Back to playing" |
| overview | child cards in one column | one column | **two columns** from `xl` |
| report | key numbers 2 per row, then charts in one column; tables scroll inside their card | numbers 3 per row | numbers 6 per row; charts **two per row** from `xl` |
| forms | one column, `ui-form-w` max | the same | two cards side by side |

Targets are at least `tap-ui` (44 px). The grown-up type scale is `ui-*` (Inter).

## 4. Accessibility and motion

- **Keyboard:**
  - every control is a real link or button;
  - the focus ring is 2 px in grown-up pages and **4 px in the child zone**, both using the focus token;
  - games have tap-to-pick alternatives to dragging;
  - stories turn with ← →;
  - the parent area can be used by keyboard alone (tested: sign in → child → gate → report).
- **Labels:**
  - every input has a label;
  - cards say what they are and whether they're locked or done ("Count the boats, Game, done");
  - pieces and cards say what they show ("Card 3: Moon", "Card 4, face down");
  - lessons say their state ("Lesson 2: Next steps, locked");
  - progress bars are `role="progressbar"` with values;
  - charts have a summary and a table.
- **Live regions:** feedback, page numbers, the memory pair count and hints are announced.
- **Reduced motion:** with `prefers-reduced-motion`, every animation and transition is cut to about 1 ms (`globals.css`). The celebrations still appear, without movement.
- **Sound:**
  - speech uses the browser's voices and can be switched off in the player;
  - nothing plays without a tap;
  - videos have captions on by default.

## 5. Images and loading

- **Images:**
  - thumbnails are the pre-sized WebP files (256 and 512) from the public bucket;
  - they use `loading="lazy"` and `decoding="async"`, and fall back to the title's letter if missing;
  - game pictures, buddies, icons and characters are inline SVG (no requests).
- **Media:**
  - video uses `preload="metadata"` and a poster, and audio uses `preload="metadata"`;
  - story narration loads only when "Read to me" is pressed (`preload="none"`);
  - media URLs are short-lived and fetched only after `play/launch` allows it.
- **Rendering:** pages render on the server (no loading spinners for the first view). Client JavaScript is limited to the players, forms and navigation. Fonts are the app's own open fonts, served from `/fonts` with `font-display: swap`.

## 6. How it's checked

`test/e2e/responsive.spec.ts` runs on all four projects. On each it:
- checks for no sideways scrolling;
- checks for the rail on laptop and desktop and the bottom bar on tablet and phone;
- saves screenshots to `docs/web/screens/W01`–`W12-<screen>-<device>.png` (48 images).

The game journeys also run on the phone project with **touch taps**.
