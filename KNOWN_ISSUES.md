# FlightPath — Known Issues & Tech Debt

Last updated: 2026-04-10

A living list of known limitations, parked decisions, and watch items discovered during audit. Each entry has **Impact** (what it means today) and **Fix when** (the trigger that should unblock work).

---

## Security

### 1. App Check is in monitoring mode
- **Where:** `functions/index.js` — callable functions declared with `enforceAppCheck: false`.
- **Impact:** Clients without a valid App Check token can still hit `getAiChat` / `getAiDebrief`. Per-user auth + rate limiting still apply, but abuse surface is wider than it should be.
- **Fix when:** Before public launch / App Store submission. Flip to `enforceAppCheck: true` once the Firebase console shows clean monitoring metrics for production builds.

### 2. Secrets-in-binary risk for third-party SDK keys
- **Where:** `lib/shared/services/subscription_service.dart` (RevenueCat SDK keys).
- **Status:** FIXED 2026-04-10 — keys now read from `--dart-define` at compile time. See CLAUDE.md "Build flags". Clarification 2026-04-10 (evening): the original hardcoded constants in `lib/core/constants/app_constants.dart` (`revenueCatApiKeyIos` / `revenueCatApiKeyAndroid`) had been left behind as dead code by the original migration and were only deleted today. Migration is now genuinely complete — no RevenueCat SDK keys remain anywhere in the repo.
- **Fix when:** Done. Watch item only — any new third-party SDK must follow the same pattern.

---

## Testing

### 3. Zero real test coverage
- **Where:** `test/widget_test.dart` is a one-line `expect(true, isTrue)` placeholder.
- **Impact:** No regression safety net. Any Apple review rejection that requires a quick fix is high-risk — we cannot prove we didn't break auth, paywall gating, or the Ask AI flow.
- **Fix when:** Before first TestFlight beta with external users. Minimum viable set: auth smoke, paywall gate on a free exercise, `getAiChat` call mocked at the `cloud_functions` boundary.

---

## Tech debt

### 4. Cloud Functions rate limiter is in-memory
- **Where:** `functions/index.js` — `_rateLimitStore = new Map()` per-instance.
- **Impact:** Limit is 10/min per user *per function instance*. Under horizontal scaling, a determined user hitting multiple warm instances can exceed the intended cap. Acceptable at current scale (single paying user target), will degrade as traffic grows.
- **Fix when:** When DAU > ~500 or when billing/abuse signals appear in Cloud Functions logs. Migrate to Firestore counter doc or Redis (Upstash) — Firestore is the cheaper path given the existing stack.

### 5. Deprecated `FirebaseAppCheck.activate` usage
- **Where:** `lib/main.dart` — `// ignore: deprecated_member_use` on the activate call.
- **Impact:** Works today, will break on a future `firebase_app_check` major bump. Pinned to `^0.4.1+5`.
- **Fix when:** Next Firebase SDK upgrade pass, or when the deprecation becomes a hard removal.

### 6. README is default Flutter boilerplate
- **Where:** `README.md`.
- **Impact:** Embarrassing if the repo is ever shared / open-sourced / shown to a collaborator. No build instructions, no `--dart-define` docs (see CLAUDE.md for the authoritative list for now).
- **Fix when:** Before sharing the repo with anyone outside Ed — collaborator, contractor, investor, beta tester with source access.

### 7. Web build intentionally unsupported
- **Where:** `lib/firebase_options.dart` throws `UnsupportedError` for web.
- **Impact:** `flutter run -d chrome` will crash at Firebase init. Not a bug — web is out of scope for v1 (mobile-first £24.99 lifetime).
- **Fix when:** If/when a web companion is prioritised. Regenerate `firebase_options.dart` with `flutterfire configure` including web, then re-audit App Check (web uses reCAPTCHA, different provider).

---

## Watch items

### 8. Claude model pinned for unit economics
- **Where:** `functions/index.js` — `claude-haiku-4-5-20251001` hardcoded in both `getAiChat` and `getAiDebrief`.
- **Impact:** Cost model for £24.99 lifetime assumes Haiku-class pricing. Any upgrade to Sonnet/Opus changes per-user gross margin materially.
- **Fix when:** Only revisit with a fresh unit-economics spreadsheet. If upgrading, consider tier-gating (e.g. Sonnet only for paid users who exceed N messages/day).

### 9. No `@anthropic-ai/sdk` dependency — raw REST calls
- **Where:** `functions/index.js` — previously called `https://api.anthropic.com/v1/messages` directly via a hand-rolled `https.request` helper with manual `anthropic-version: 2023-06-01` header.
- **Status:** FIXED 2026-04-10 — migrated both `getAiChat` and `getAiDebrief` to `@anthropic-ai/sdk` ^0.87.0. Client is instantiated lazily inside each handler so Firebase secret access still works. Error mapping (401/403/429/network) preserved via typed SDK errors. Response-text extraction now tolerates multiple content blocks and ignores non-text blocks.
- **Fix when:** Done. Watch item only — revisit if we want streaming Ask AI or prompt caching for the syllabus system prompt, both of which the SDK now makes trivial.

### 10. Region hardcoded to `europe-west2`
- **Where:** `functions/index.js` — all callables and the RevenueCat webhook.
- **Impact:** Latency penalty for non-EU users (US, AU). Fine for the UK-first launch; bad for FAA / global expansion.
- **Fix when:** US / FAA expansion is scheduled. Consider multi-region deploy or moving AI calls to `us-central1` once the US cohort exists — but watch GDPR implications for EU user data.

### 11. `youtube_player_flutter` for exercise videos
- **Where:** `pubspec.yaml` — `youtube_player_flutter: ^9.1.1`.
- **Impact:** YouTube Terms of Service restrict monetising embedded content in some contexts. FlightPath is a paid app (£24.99) that shows YouTube-hosted training videos; this is a grey area depending on whether videos are Ed's own uploads, licensed, or third-party.
- **Fix when:** Before App Store submission. Confirm every embedded video is either (a) uploaded by Ed to a FlightPath YouTube channel, or (b) explicitly cleared by the rights holder. Document the decision. Long-term, consider self-hosting via Firebase Storage or Mux.

---

## Not-an-issue (just remembering the decision)
- Stripe is NOT in the app binary. App uses RevenueCat + native IAP only. Stripe is for the marketing site waitlist checkout.
- No TODO/FIXME/HACK comments exist in `lib/` — this is intentional cleanliness, not oversight.
