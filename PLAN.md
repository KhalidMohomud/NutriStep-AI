# NutriStep AI — Spec & Implementation Plan

## Context

Mobile calorie/nutrition tracker built in Flutter, backed entirely by Supabase (Postgres,
Auth, Storage, Edge Functions). No custom backend (Go/Gin explicitly rejected). The
headline feature is an AI food scanner: photo → Gemini vision → nutrition estimate,
grounded against a nutrition database rather than trusting the model's numbers outright.
Secondary feature is step tracking (Health Connect / HealthKit). Three languages
(English default, Somali, Arabic) drive both UI copy and AI response language.
Monetization is a Free/Pro subscription gate on scan count + AI Coach access.

---

## 1. Spec Summary

### Product

Photo → nutrition. Flutter app, Supabase backend. A user signs up, scans meals by
camera, gets AI-estimated macros grounded against a nutrition database, corrects
portions when the AI is wrong, and tracks daily steps/activity alongside food.

### Users

Single role: the individual tracking their own nutrition and activity. No admin, no
teams, no sharing. Two tiers: Free and Pro, gated by subscription.

### In scope for v1

- Email/social sign-up via Supabase Auth
- AI Food Scanner: camera → Supabase Storage → Edge Function → Gemini vision → macros
- Nutrition-database grounding + user portion correction
- Step Tracking: Android via Health Connect, iOS via HealthKit
- Daily nutrition + activity dashboard
- Localization: English (default), Somali, Arabic — UI **and** AI response language
- Free tier: 2 scans/day. Pro tier: 8 scans/day + AI Nutrition Coach + no ads
- Subscription billing: Google Play Billing (Android), Apple In-App Purchase (iOS),
  entitlement state stored/verified in Supabase

### Explicitly OUT of v1

Custom backend server · barcode scanning · social features/sharing · web app ·
manual food-database search UI beyond correction · offline-first sync · exercise
logging beyond steps/calories-burned from HealthKit/Health Connect · multi-user
households · web dashboard.

### Core flow

```
Onboarding (goals, units, language) → Sign up (Supabase Auth)
   → Home (today's nutrition + steps)
   → Camera capture → upload → AI analyze (async) → result card
      → user confirms/corrects portion → saved to DB
   → AI Nutrition Coach (Pro) / Upgrade prompt (Free, after scan cap)
```

Aha moment: first scan resolving into a real, correctable macro breakdown in the
user's own language.

### Architecture

| Layer         | Choice                                                                          |
| ------------- | -------------------------------------------------------------------------------- |
| App           | Flutter (Dart), Riverpod or Bloc for state, `go_router` for navigation           |
| Backend       | Supabase: Postgres, Auth, Storage, Edge Functions (Deno/TypeScript)              |
| AI            | Gemini (vision) called from an Edge Function, never from the client directly     |
| Nutrition DB  | A reference nutrition dataset (e.g. USDA-derived or licensed) seeded in Postgres |
| Step data     | `health` (or `health_connect_plus` + native HealthKit bridge) Flutter plugin     |
| Localization  | `flutter_localizations` + `.arb` files (en, so, ar) incl. RTL for Arabic          |
| Billing       | `in_app_purchase` (Flutter) wrapping Play Billing + StoreKit; entitlement synced to Supabase via server-side receipt validation (Edge Function) |
| Push (later)  | Out of v1, but Supabase + FCM/APNs is the natural slot if added                  |

**Why Supabase-only:** Auth, Storage, RLS-secured Postgres, and Edge Functions cover
every backend need here with zero servers to run or scale. Edge Functions are the one
place the Gemini API key lives — the client never sees it.

### Data model (Postgres via Supabase)

`profiles` — one row per Supabase Auth user (`auth.users.id` FK)

```
id                uuid pk, references auth.users(id)
email             text
display_name      text
language          text            -- "en" | "so" | "ar"
unit_preference   text            -- metric | imperial
gender            text
date_of_birth     date
height_cm         numeric
weight_kg         numeric
goal              text            -- lose | maintain | gain
activity_level    text
daily_calories    integer         -- computed/target
protein_g / carbs_g / fat_g  integer
subscription_tier text            -- free | pro
subscription_expires_at  timestamptz
created_at / updated_at
```

`meals`

```
id             uuid pk
user_id        uuid fk -> profiles.id
image_url      text not null       -- Supabase Storage path
status         text not null       -- analyzing | completed | failed
name           text
portion_grams  numeric             -- AI estimate, user-correctable
calories       integer
protein_g / carbs_g / fat_g  integer
ai_confidence  text                -- optional: low/med/high, drives correction prompt
source         text                -- "ai" | "ai+db" | "user_corrected"
logged_at      timestamptz not null
created_at / updated_at

index (user_id, logged_at desc)
```

`nutrition_reference` — seeded lookup table (food name/category → per-100g macros),
used by the Edge Function to ground/adjust Gemini's raw output.

`activity_logs` — daily rollups pulled from Health Connect/HealthKit

```
id          uuid pk
user_id     uuid fk -> profiles.id
date        date not null
steps       integer
distance_m  numeric
calories_burned  integer
synced_at   timestamptz
unique (user_id, date)
```

`scan_usage` — per-day scan counter for the Free/Pro cap

```
user_id     uuid fk -> profiles.id
date        date
scan_count  integer
unique (user_id, date)
```

**RLS is mandatory on every table**: users can only read/write their own rows.
Edge Functions use the Supabase service role to write AI results after auth-checking
the caller's JWT.

### Edge Functions

| Function            | Trigger                    | Purpose                                                                 |
| -------------------- | --------------------------- | ------------------------------------------------------------------------ |
| `analyze-meal`       | Called by app after upload  | Fetch image from Storage → Gemini vision → parse → cross-check against `nutrition_reference` → write `meals` row → return result |
| `check-scan-quota`   | Called before capture       | Read `scan_usage` + `subscription_tier`, reject if Free user over 2/day  |
| `ai-nutrition-coach` | Called from Coach screen (Pro only) | Gemini text call in the user's `language`, grounded on the user's recent `meals`/`profiles` data |
| `verify-purchase`    | Called after Play/StoreKit purchase | Validate receipt server-side, update `profiles.subscription_tier` |
| `sync-activity`      | Called on app open/background sync | Upsert `activity_logs` from client-collected Health Connect/HealthKit data |

### Race condition, handled

Purchase verification and app-side "restore purchases" can both fire around the same
time. `verify-purchase` must be **idempotent on the platform transaction ID** — upsert,
not insert — so re-delivery of the same receipt doesn't double-write.

### Localization detail

- UI strings: `.arb` files per locale, English source of truth, Somali/Arabic as
  translated bundles. Arabic requires RTL layout support (`Directionality`, mirrored
  icons) — flag this early, not as a v1-end polish item.
- AI response language: the user's `profiles.language` is passed into every Gemini
  prompt (both `analyze-meal`'s food-name output and `ai-nutrition-coach`), so Gemini
  is explicitly instructed to answer in that language rather than inferring it.

---

## 2. Assumptions

| # | Assumption |
| --- | --- |
| A1 | **Gemini model**: `gemini-2.5-flash` (or current fast vision-capable tier) for `analyze-meal` — cost-sensitive, called on every scan. Escalate to a stronger model only for `ai-nutrition-coach` if flash-tier reasoning disappoints. |
| A2 | Nutrition grounding means: Gemini identifies food + estimates portion; the Edge Function then looks up the closest `nutrition_reference` match by food name/category and reconciles Gemini's raw macro guess against the reference per-100g values rather than trusting either source blindly. |
| A3 | Health Connect / HealthKit integration is **read-only** in v1 (pull steps/distance/calories), no writing workouts back. |
| A4 | Subscription state (`profiles.subscription_tier`) is the single source of truth the app reads; Play/StoreKit are only consulted at purchase/restore time, then reconciled via `verify-purchase`. |
| A5 | Free tier's daily cap resets at local midnight in the user's device timezone, checked by `check-scan-quota`. |
| A6 | RTL support for Arabic is built into the design system from day one (not retrofitted). |
| A7 | Gemini API key lives only in Edge Function secrets — never shipped in the Flutter binary. |

---

## 3. Open Risks

| # | Risk | Mitigation |
| --- | --- | --- |
| R1 | **AI portion/calorie estimates are frequently wrong** — the #1 complaint in this category of app. | Manual portion correction is in v1 by design (point 3 of the brief). Nutrition-DB grounding reduces variance but won't eliminate it — don't over-promise accuracy. |
| R2 | **Health Connect (Android) and HealthKit (iOS) have divergent permission models and data shapes.** | Build one internal `ActivityRepository` interface with two platform implementations; test on both a real Android device with Health Connect installed and a physical iOS device (simulator HealthKit data is unreliable). |
| R3 | **Receipt validation for Play Billing / StoreKit is easy to get wrong** (sandbox vs. production, renewal vs. one-time). | Server-side verification only, in `verify-purchase`; never trust a client-reported "I bought Pro" flag. |
| R4 | **Gemini cost scales directly with scan volume**; Free tier is a real cost center at 2 scans/day/user. | Cap enforced server-side (`check-scan-quota`) before the Gemini call is ever made, not just in the UI. |
| R5 | **Arabic RTL bugs are easy to miss** if development happens LTR-first. | Test the full flow in Arabic/RTL at the end of each phase, not only at the end of the project. |
| R6 | **Nutrition reference dataset licensing/coverage** — a thin or unlicensed dataset undermines the "grounded, not just AI-guessed" pitch. | Decide the dataset source (USDA FoodData Central is public-domain and a reasonable v1 default) before building the grounding logic. |
| R7 | **Supabase Edge Function cold starts** may make the first scan of a session feel slow. | Acceptable for v1; note it rather than engineering around it. |

---

## 4. Implementation Plan

### Phase 1 — Foundation
1. Flutter project scaffolded (done — `nutristep_ai`), configure `flutter_localizations`
   for en/so/ar with RTL support verified on a placeholder screen.
2. Supabase project: Auth providers, Storage bucket for meal photos, initial schema
   (`profiles`, `meals`, `activity_logs`, `scan_usage`, `nutrition_reference`) with RLS
   policies from the start.
3. Seed `nutrition_reference` from a chosen dataset (see R6).
4. Wire Supabase Auth (email + at least one social provider) end-to-end in the app.

### Phase 2 — AI Food Scanner core loop
5. Camera capture screen (`camera` or `image_picker` plugin) + permission handling.
6. Upload to Supabase Storage.
7. `analyze-meal` Edge Function: Gemini vision call → structured parse → grounding
   against `nutrition_reference` → write `meals` row.
8. `check-scan-quota` gate wired in before capture is allowed.
9. Result screen with portion correction UI, writes back to `meals` as `user_corrected`.

### Phase 3 — Dashboard + localization
10. Home dashboard: daily calories/macros vs. targets, recent meals list.
11. Full `.arb` translation pass for en/so/ar; verify AI responses honor
    `profiles.language` for both scanner output and Coach.
12. Settings screen: language switch, units, profile edit.

### Phase 4 — Step tracking
13. `ActivityRepository` abstraction; Health Connect implementation (Android).
14. HealthKit implementation (iOS).
15. `sync-activity` Edge Function + daily rollup display alongside nutrition.

### Phase 5 — Monetization
16. Google Play Billing + Apple IAP product setup (Free/Pro).
17. `verify-purchase` Edge Function, idempotent on transaction ID.
18. Paywall UI at the scan cap and on the AI Coach entry point.
19. `ai-nutrition-coach` Edge Function, Pro-gated, localized.

### Phase 6 — Polish
20. Error/empty/loading state sweep across all screens.
21. Ads integration for Free tier (if in scope) — gate correctly on `subscription_tier`.
22. Analytics/crash reporting (e.g. Sentry or Supabase logs review).
23. App Store / Play Store listing prep.

---

## 5. Verification

**Definition of done — manual happy path, on real devices (Android + iOS):**

1. Fresh install → onboarding in each of the 3 languages → sign up
2. Scan a real meal → result appears with plausible macros → correct the portion →
   totals update
3. Hit the Free-tier 2-scan/day cap → upgrade prompt appears, no 3rd scan processed
4. Purchase Pro (sandbox) → cap lifts to 8/day, AI Coach unlocks, ads disappear
5. Ask the AI Coach a question in Somali and in Arabic → response comes back in that
   language, RTL renders correctly for Arabic
6. Steps recorded on-device appear in the dashboard on both Android (Health Connect)
   and iOS (HealthKit)
7. Force-quit and relaunch → session persists, today's data intact
8. Airplane mode mid-scan → recoverable error, no orphaned `analyzing` row

**Checks worth writing** (small, no framework): the nutrition-grounding reconciliation
logic and the scan-quota reset-at-midnight calculation — both are pure functions where
a bug is silent and only surfaces as wrong numbers or a wrongly-blocked scan.

---

## Notes

- This plan assumes the dataset/licensing decision (R6) and the exact Gemini model
  (A1) get confirmed before Phase 2 grounding logic is built.
- Package/plugin versions (health, in_app_purchase, camera, etc.) should be pinned and
  checked against current pub.dev docs at scaffold time, not from memory.
