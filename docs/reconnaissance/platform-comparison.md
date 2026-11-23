# Platform comparison

Legend: **[V Rn]** verified, **[A]** assumption, **[P]** proposal (our decision, to settle in the architecture step).

## 1. Where the original runs

| platform | supported | minimum | notes |
| --- | --- | --- | --- |
| iOS / iPadOS | ✓ | iOS 15.4+, 2GB RAM, 4.7"+ screen [V R19] (store page says 15.1+ [V R35]; the help center is stricter) | "Designed for iPad", tablet-first [V R35]. Sign in with Apple [V R21] |
| Android phones and tablets | ✓ | Android 12+, 4GB RAM, 5"+ (runs on 10/11 "less smoothly") [V R19] | 50M+ installs, "Teacher Approved" [V R34] |
| Amazon Fire tablets | ✓ | Fire OS 6+, 2GB, 7"+ [V R19] | Amazon IAP [V R24] |
| Huawei AppGallery | ✓ | — | distribution only [V R18] |
| Mac (Apple silicon) | ✓ via the iPad app | macOS 13+, M1+ [V R35] | not a native Mac app |
| **Web browser / computer** | **✗** | — | "no computer or web browser version" [V R18, R19] |
| Web: account services | ✓ | — | subscribe (S07), redeem (S08), password reset (S43), Stripe billing portal [V R1, R18, R25, R33] |
| Web: educator and printables | ✓ | — | S39–S41 [V R28, R40] |

**What this means for us:** for Android and iOS there's a reference to study. **For Web there isn't one.** A web kids' player, a web parent dashboard and web offline are all new design work, not cloning.

## 2. Our targets: Android, iOS, Web, compared by concern

| concern | Android | iOS / iPadOS | Web | evidence / notes |
| --- | --- | --- | --- | --- |
| Main device | tablet first, phone supported | iPad first, iPhone supported | Chromebooks, laptops, tablets in a browser | original tablet-first [A from store screenshots R34/R35]; web devices [P] |
| Orientation | **Kids Area landscape; Parents Area and Progress Report portrait; games choose per activity** (stacking is portrait) [SS-01, 12, 14, 16] | the same [A, only Android was captured] | any window shape; reflow the parent screens; letterbox games to their declared ratio [P] | U02 resolved |
| Input | touch | touch, Apple Pencil (tracing) [A] | **mouse, trackpad, keyboard** and touch | drag, trace and draw engines must accept pointer events [P] |
| Parent login | magic link, password; Google [P] | magic link, password, **Apple (required if any social login is offered)** | magic link, password, Google, Apple | Apple guideline 4.8 [A, general store rule] |
| Magic link opens | Android App Links | Universal Links | a normal URL | cross-device fallback code [P] |
| Purchases | Google Play Billing (required for digital subs bought in the app) | Apple IAP (required in the app) | Stripe (+ PayPal) | the original uses store IAP plus Stripe on the web [V R24, R25] |
| Entitlement sync | server-side receipt validation across all three [P] | ″ | ″ | "paid but can't access Plus" support article [V R41] shows this is a real failure point |
| Kids-category store rules | Google Play Families Policy [V R34] | App Store Kids category: parental gate before links and purchases, no third-party ads or analytics [A, general rule] | COPPA applies to the web too; no ad trackers [P] | original: no ads, kidSAFE COPPA+ [V R1] |
| Offline | download to app storage (large, reliable) | download to app storage | **service-worker cache + IndexedDB; quota limited, can be evicted** (Safari especially) | original offline is mobile only [V R27]; web offline is best-effort [P] |
| Video | native player, downloads | native player, downloads | HLS via a JS player; downloads only via the cache | [P] |
| Audio autoplay | allowed | allowed after interaction | **blocked until the first user gesture** | needs a "tap to start" [P] |
| Mic / camera (G32, G33, G37) | runtime permission after the gate | runtime permission after the gate | `getUserMedia` browser prompt; needs HTTPS; varies by browser | [V R20] for mobile |
| Screen-time enforcement | in-app timer | in-app timer | in-app timer; easy to get around (new tab, clearing storage) | server-side tally per child recommended [P] |
| Kid lock (video) | in-app lock [V R6]; OS screen pinning [A] | in-app lock; Guided Access [A] | fullscreen plus a click-lock overlay; can't stop the Esc key | [P] |
| Push notifications | FCM | APNs | Web Push (iOS Safari only for installed PWAs) | original has push [V R43] |
| Deep links | `activity?activity_id=`, `contentPage?feedSetId=` style [V R1, R37] | ″ | plain routes `/play/:activityId`, `/collections/:id` [P] | |
| Install size | app download (the iOS app is 253 MB [V R35]) + downloads | ″ | lazy-load per activity; first load must stay small | [P] |
| Accessibility | TalkBack, scalable text in parent areas | VoiceOver, Dynamic Type in parent areas | WCAG 2.2 AA for parent and teacher screens; keyboard nav | the original declares no accessibility features [V R35] |
| Languages | EN/ES/PT content; 17 UI languages | ″ | ″ plus `lang` and RTL if Arabic is added | [V R1, R35] |

## 3. Per-screen differences (in brief)

The full detail is in each screen's "Mobile vs web" line in `screen-inventory.md`.

| screens | mobile (original) | web (ours) [P] |
| --- | --- | --- |
| S01–S04 onboarding | store install, then the in-app flow, then IAP sheet | URL, no install, Stripe Checkout, Google sign-in |
| S05/S06 login | universal links open the app | link opens the browser; code fallback |
| S09 Home, S14 Theater, S17 Lessons | full-screen landscape tablet | responsive grid; hover; keyboard focus; fullscreen button |
| S13 game player | native engine | browser engine (Canvas/WebGL); pointer events; audio unlock |
| S28 gate | birth-year keypad | the same; optional parent PIN |
| S31–S37 Parents Area | in-app list screens | a full parent dashboard (sidebar), the best place for reports and billing |
| S36 downloads | reliable device storage | "available offline" with a storage meter and an eviction warning |
| S35 subscription | links out to the store for store subs | Stripe customer portal |

## 4. Implications for the architecture step (questions, not decisions)

1. **One codebase for three targets?** The game engines must run identically on Android, iOS and Web, which points to a web-tech game layer (Canvas/WebGL) or a cross-platform engine. To be decided in `/replica-architect`.
2. **Entitlements** must be unified on our server across Apple, Google and Stripe from day one.
3. **Content delivery:** per-activity bundles (art, audio, config) on a CDN, versioned, downloadable on mobile and cacheable on web.
4. **Offline progress queue** on all three, merged on the server (idempotent completion events).
5. **Child privacy:** COPPA/GDPR-K design on all three, and no third-party analytics SDKs in the kids' surfaces.
