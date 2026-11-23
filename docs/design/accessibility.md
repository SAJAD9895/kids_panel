# Accessibility and child-friendly UX

Targets: **WCAG 2.2 AA** for the parent and admin web and the Parents Area; the same where it applies to the children's app, plus the child-specific rules below. Contrast is enforced in the tokens (60 pairs, 0 AA failures, `contrast.py`).

## 1. Children (ages 2–8)

| # | rule |
| --- | --- |
| C1 | **Pre-readers first**: every action has an icon and a spoken label; no screen needs reading. Text is a support for grown-ups and early readers [F-036] |
| C2 | **Targets**: primary ≥ 64 dp (`tap-kids`), secondary ≥ 56 dp, ≥ 12 dp apart (`tap-gap-kids`); hit areas may be larger than the art, never smaller |
| C3 | **Gestures**: tap and drag only. No long-press, double-tap, multi-finger or precise swipes required. Swipe is always also a button |
| C4 | **Feedback**: every tap gives sound + a 120 ms press animation within 100 ms; nothing happens silently |
| C5 | **No dead ends**: every screen has a visible way back or home |
| C6 | **No dark patterns**: no prices, ads, links out, streak-loss threats, countdown offers or "your friends are playing" in kids screens. Rewards are never taken away |
| C7 | **Locks are explained**, not hidden: locked cards stay readable and say "Ask a grown-up" (K30) |
| C8 | **Errors** are friendly, with no blame and no technical words (`states.md`) |
| C9 | **Consistent places**: the rail, Grown-ups button, close and replay buttons never move between screens |
| C10 | **Calm by default**: one moving thing at a time, celebrations ≤ 2.5 s and skippable, no flashing faster than 3 per second (WCAG 2.3.1) |
| C11 | **Left- and right-handed**: no critical control only in a bottom corner; game controls are mirrorable where the template allows |
| C12 | **Grown-up areas** are clearly different (white "grown-up zone" style, K03/K20) so children learn not to go there |

## 2. Vision

- Colour is never the only signal: locked = lock icon, correct = check + sound, subjects = icon + name, chart series = labels.
- Contrast: text 4.5:1, large text and UI parts 3:1 (tokens). Locked and disabled states change icon/border, not text opacity (`components.md` §0).
- **Text scaling**: Parents Area and web support 200 %; the Kids Area supports the OS text size up to 130 % (layouts fit fewer cards rather than clip) [P].
- Screen readers: VoiceOver, TalkBack (Flutter `Semantics`), and NVDA / VoiceOver on the web. Cards read as one item: "Shape homes, game, saved". Games expose at least the instruction, the replay button, pause and close; template-specific play may not be fully screen-reader accessible in v1, and the template states it in its metadata [A].
- Captions on all videos; transcripts for songs (lyrics) and stories (book text).

## 3. Hearing

- Every spoken instruction also has a visual cue (buddy gesture, highlighted target).
- Captions off by default, one switch in K20 to turn them on everywhere.

## 4. Motion and attention

- **Calm motion** switch (K20) and the OS "reduce motion" setting both: replace springs and parallax with fades, stop idle loops, show celebration end frames. `motion.*` tokens become 0.
- Background music can be switched off independently of voice.

## 5. Motor and input

- Full keyboard use on the web for all three apps (focus order follows the layout; visible focus ring `kids-focus` 3 px / `ui-focus` 2 px).
- Switch Access (Android) and Switch Control (iOS) can reach every non-game control.
- Drag in games has a tap-to-select, tap-to-place alternative (I12).
- No time limits on any form; the parental gate has no timer.

## 6. Checks (definition of done for every screen)

| check | tool | where |
| --- | --- | --- |
| token contrast | `contrast.py tokens/tokens.json` | CI, on every token change |
| automated a11y | axe-core (Playwright) on every parent and admin page | CI |
| Flutter semantics | `meetsGuideline(androidTapTargetGuideline, iOSTapTargetGuideline, textContrastGuideline, labeledTapTargetGuideline)` in widget tests | CI |
| keyboard-only walkthrough | manual, per flow | each release |
| screen reader walkthrough | VoiceOver (iPad), TalkBack (Android), NVDA (web) for F01, F04, F12 | each release |
| 200 % text, reduce motion, captions | manual | each release |
| child usability | 5 children per age band (2–3, 4–5, 6–8) on the vertical slice and before launch, with parental consent [P] | M2, M13 |
