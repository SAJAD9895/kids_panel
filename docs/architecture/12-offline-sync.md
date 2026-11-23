# 12. Offline synchronization architecture

**Goal:** a child can play downloaded content with no connection, every star and step they earn is kept, and nothing is counted twice when the device reconnects. The original supports offline play on mobile only [V R27]; we do the same on mobile and best-effort on web.

## 12.1 What works offline

| capability | offline on mobile | offline on web |
| --- | --- | --- |
| play downloaded games, stories, audio | ✓ | best-effort (packs in Cache Storage) |
| watch downloaded videos | ✓ (MP4 rendition) | ✗ in v1 |
| earn stars, complete lesson steps (optimistic, confirmed on sync) | ✓ | ✓ while the tab's storage survives |
| see the sticker album, place stickers | ✓ | ✓ |
| open gifts | ✗ (needs the server's star count) → "your gift is waiting" | ✗ |
| favorites add / remove | ✓ (queued) | ✓ (queued) |
| Parents Area reports, purchases, account changes | ✗ | ✗ |
| download new content | ✗ | ✗ |

## 12.2 Local storage on the device

| store | technology | contents |
| --- | --- | --- |
| local database | **Drift (SQLite)**; on web, Drift with sqlite3 WASM in OPFS / IndexedDB [P] | catalogue cache, child state snapshot, **outbox**, download index, sync cursors |
| files | app support directory (mobile); Cache Storage via the service worker (web) | packs (unzipped, per content version), MP4 videos, thumbnails |
| secrets | Keychain / Keystore (mobile) | session tokens, **entitlement token**, parent PIN hash |

### Local tables (Drift) [P]

| table | purpose |
| --- | --- |
| `catalog_items` | activities, collections and courses for the child's age band + locale (from `catalog/sync`) |
| `child_state` | stars today, gifts available, enrollments, completed steps, favorites, reward counts (from `learning/state`) |
| `outbox` | pending operations: `{opId, type, childId, payload, createdAt, attempts, lastError}` |
| `downloads` | `{activityId, contentVersion, path, bytes, sha256, status, lastUsedAt}` |
| `sync_meta` | catalogue cursor, last sync time, **server clock offset** |

## 12.3 Sync protocol

```mermaid
sequenceDiagram
  participant G as GameHost
  participant O as Outbox (Drift)
  participant S as Sync engine
  participant API as play/sync
  participant DB as Postgres engine
  G->>O: session + result + responses (session.id = UUIDv7 made on device)
  G->>G: optimistic star / unlock in the UI
  Note over S: triggers: app foreground, connectivity regained, every 2 min while online, end of activity
  S->>O: take ≤ 100 oldest items
  S->>API: POST /play/sync {deviceId, clockOffsetMs, items}
  API->>DB: apply_session per item (09-…)
  DB-->>API: accepted | duplicate | rejected
  API-->>S: per-item status + state deltas
  S->>O: delete accepted + duplicate; keep rejected with reason
  S->>S: replace optimistic state with server state
```

**Push (device → server)**

| outbox op | endpoint | conflict rule |
| --- | --- | --- |
| `session` (+ result + responses) | `POST /play/sync` | append-only, no conflicts; idempotent by session id |
| `favorite.add` / `favorite.remove` | `PUT/DELETE /library/favorites/:id` | last write wins by the client timestamp; removal leaves a tombstone so an older add can't resurrect it |
| `scene.save` | `PUT /rewards/scenes/:id` | whole-scene replace with a version number; on `409` the server copy wins and the device's version is kept as "unsaved" for one undo [P] |
| `heartbeat` | `POST /play/heartbeat` | additive seconds; offline seconds are sent on reconnect and capped per day |

- Items are sent in creation order per child. A **rejected** item (e.g. a child deleted meanwhile) stays with its reason; after 3 attempts it moves to a dead-letter list that is reported to Sentry (no personal data) and dropped.
- **Batching:** ≤ 100 items per call; repeat until the outbox is empty.
- **Ids:** UUIDv7 (time-ordered) for sessions, generated on the device. They are the idempotency keys.

**Pull (server → device)**

| data | endpoint | how |
| --- | --- | --- |
| catalogue | `GET /catalog/sync?since=cursor` | changed items + tombstones for retired items; full refresh if the cursor is older than 30 days |
| child state | `GET /learning/state` | full snapshot (small), after each push and on app start |
| entitlement | `GET /billing/entitlement-token` | on start and every 12 h online |
| account bootstrap | `GET /account/me` | on start |

## 12.4 Time and the household day

Device clocks can be wrong or changed. The app records times from its own clock **and** the offset it measured at the last successful sync (server time minus device time, from the `Date` header of `/account/me`). The server corrects by that offset, clamps, and computes the household day from the account's timezone (`09-…` §9.2). Changing the device clock can't mint stars.

## 12.5 Offline entitlement

- The server signs an **entitlement token** (JWT, Ed25519; key in Edge Function secrets; public key compiled into the app) [P]:
  `{sub: accountId, plus_until, iat, exp = min(plus_until, now + 7 days)}`.
- Offline, the app opens Plus content only while the token is valid. After it expires, downloaded Plus content shows a lock until the device is back online. That matches the original's "downloads locked after lapse" assumption [A U07].
- Sessions played offline carry the token's `iat`. The engine honours access that was valid at `started_at` (`09-…` rule 3).

## 12.6 Downloads

| step | detail |
| --- | --- |
| choose | single card, a whole row [V SS-01 row download icon], or favorites |
| manifest | `POST /library/downloads/manifest` → files, sizes, sha256, signed URLs (15 min) |
| download | `background_downloader` [P]: background on iOS/Android, resumable, Wi-Fi-only setting (default on) |
| verify | sha256 per file; a mismatch deletes the file and retries once |
| install | unzip to `{appSupport}/content/{activityId}/{contentVersion}/`; atomic rename when complete |
| record | `POST /library/downloads/report` → `content_downloads` (so S36 can list "downloaded on this device" and support can see it) |
| update | when `catalog/sync` shows a new `contentVersion`, the old copy keeps working until the new one is downloaded (on Wi-Fi) |
| evict | user-removable in S36; automatic LRU eviction when free space is low; Plus lapse past the token's expiry locks but keeps files for 30 days [P] |
| quota | storage meter in S36; default limit 2 GB, adjustable [P] |

**Web:** a service worker caches the app shell and packs in Cache Storage and requests `navigator.storage.persist()`. The UI warns that the browser may clear it (Safari especially). No video downloads on web in v1.

## 12.7 Failure handling

| situation | behaviour |
| --- | --- |
| sync fails (network) | exponential backoff (5 s → 5 min), retried on connectivity change |
| `401` (session expired) | refresh the token; if refresh fails, keep the outbox and ask a parent to sign in. **The outbox is never deleted on sign-out without a warning** [P] |
| `426` app too old | the outbox is kept; the app asks for an update; the new version syncs it |
| a child was deleted on another device | the server rejects that child's items; they are dropped after the parent confirms |
| storage full | stop downloads; offer to remove the oldest downloads |
| corrupted local DB | rebuild from the server (child state and catalogue are re-derivable); the outbox is backed up to a JSON file before any migration [P] |

## 12.8 Testing

- Unit tests of the sync engine against a fake server (accept, duplicate, reject, 401, 426, timeout).
- An integration test on devices: airplane mode → play 3 activities, complete a lesson step → reconnect → exactly 3 sessions on the server, 1 star per distinct activity, the step unlocked, no duplicates after a forced second sync.
- A clock test: set the device clock 2 days ahead, play offline, sync → stars are counted on the correct household day.
