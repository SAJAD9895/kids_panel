# Stories module

Phase 11, 2026-11-21. Screens K14 (Listen library, the stories part) and K32 (book reader). Screenshot: `screens/M06-story-reader-narration.png`.

## Brief → status

| brief | status | notes |
| --- | --- | --- |
| story library | done | Listen: Stories row, Bedtime stories row, category rows, featured, search |
| story categories | done | Bedtime, Garden, Space, Calm and kind |
| illustrated reader | done | `/kids/listen/stories/:id`, full screen: the page picture (left, or above on portrait phones) and its words |
| audio narration | done, **device voice** | sentence by sentence with the sentence highlighted; the device's text-to-speech (iOS / Android voices, the Web Speech API in browsers). Recorded narration per page (`activity_media` role `page_audio`) is supported and plays instead when present, but none has been recorded, so that path is tested with fake files only |
| play and pause narration | done | "Read" / "Pause"; pausing stops at once; Read continues from the sentence it stopped on |
| page-by-page navigation | done | arrows, swipe left / right; "Read to me" turns the pages by itself after each page is read; tap a sentence to hear just that sentence |
| reading progress | done | "Page 3 of 6" with a bar; the last page shows "The end!" with Read again / More stories |
| continue reading | done | leaving saves the page (device + server); the story opens there ("Carrying on from page 3 · Start at the beginning"); "Keep reading and listening" row on Listen |

## Details

- **Sentences.** `splitSentences` keeps quotes with their sentence: `"Goodnight, little cloud!" she sang.` is one. Ellipses end a sentence.
- **Slow voice.** A switch reads at 75 % speed (recorded narration plays at 85 %).
- **Finishing.** Reaching the last page completes the session, which earns the daily star and completes the lesson step if opened from an island. Leaving earlier records the page.
- **Interruptions.** The app going to the background stops the narration and the reading clock; nothing restarts on its own when it comes back.
- **Parents' controls apply.** The Listen switch, categories and the daily limit cover stories; Plus stories need Plus.
- **Text.** Page words live in `activity_media.text` (localized), so a translation is another language key, not new artwork.

## Not done

- **Recorded narration** and word-level highlighting. Sentence level only, because device voices don't report word timings consistently.
- **Audiobooks** without pictures. These need recorded audio; see `music-module.md`.
- **Two-page spreads** on tablets (K32 spec): one page at a time everywhere.
