# Cobellifterents Wayfinder Replacement Roadmap

> **For Hermes:** Use the feature-slice-orchestration workflow and isolated agent worktrees for execution. This document is exploration and planning only; no product code is implemented by this plan.

**Goal:** Capture enough evidence from ATG and StrongLifts before the September renewals to replace the essential workout/progression value in Cobellifterents, while shipping a realistic personal 30-day challenge on September 1 and designing—not prematurely implementing—safe social challenges.

**Architecture:** Keep Cobellifterents local-first with SwiftData and protocol/repository boundaries. The September 1 challenge is personal and offline-capable. Friend lists, invitations, shared challenge state, and remote notifications are a separate authenticated service boundary requiring explicit privacy, authorization, moderation, and conflict decisions.

**Tech Stack:** Native iPhone-only SwiftUI, SwiftData, XcodeGen/project.yml, existing local UserDefaults repositories, existing CSV import/provenance model, later Sign in with Apple/APNs/backend only after a reviewed social design.

---

## 1. Current Wayfinder state

**Date/evidence point:** 2026-08-29 (PDT). Deadlines supplied by the user are treated as September 2026:

- **2026-09-01:** begin a 30-day exercise challenge.
- **2026-09-04:** ATG subscription renews; capture/export and cancel or pause before this date.
- **2026-09-05:** StrongLifts subscription renews; capture/export and cancel or pause before this date.

**Repo:** `/Users/keithwoody/Development/Cobellifterents`, currently on `main` at `ae40fb1`, clean of tracked changes. No feature worktree was created because this is a planning-only exploration.

**Current implementation found:**

- Local SwiftData `WorkoutSession`/`WorkoutSetRecord` history with body weight, notes, source provenance, resistance units, durations, supersets, rounds, and program assignment fields (`Cobellifterents/Models.swift`).
- StrongLifts-style A/B defaults: A = Squat, Bench Press, Barbell Row; B = Squat, Overhead Press, Deadlift; 5x5 except Deadlift 1x5 (`Cobellifterents/Programs.swift`, `Models.swift`).
- Direct work-set editing, completion progress, body weight, notes, and a 90-second rest timer are already present in the active workout UI (`ContentView.swift`).
- Local progression settings support current weight, increment, deload percentage, failure frequency, target sets/reps, and persisted defaults (`ProgressionSettings.swift`, `Models.swift`).
- ATG and StrongLifts CSV preview/commit, immutable raw rows, dated-session conversion, blank-date provenance-only behavior, and stable source IDs exist (`CSVWorkoutImporter.swift`, `ImportModels.swift`, `ImportCommitter.swift`, `ImportView.swift`).
- Imported workout assignment UI exists individually and in bulk in the current source (`ImportView.swift`, `WorkoutProgramAssignment.swift`), and imported history detail/set summaries are present. GitHub issue #12 remains open only as a ticket-status/verification concern and must be independently verified against every acceptance criterion before being considered closed.
- A concrete iPhone 16 Pro iOS Simulator run passed all 100 existing tests. A generic simulator destination is invalid for XCTest, so future verification must name a concrete device.

**Open GitHub tickets that remain in scope:**

- **#5 — Import ATG workout history CSV** (`ready-for-agent`, milestone `ATG workout data import`). The implementation and tests cover nearly all listed behavior, including exercise order and evidence-based ambiguity handling; the issue body is stale. Remaining work is reconciling requirements/status and recording the concrete simulator/full-suite evidence, while preserving the explicit limitation that the export cannot reconstruct missing session boundaries.
- **#12 — Allow assigning Programs to imported workouts individually and in bulk** (`enhancement`, `ready-for-agent`). The main branch contains the requested UI/service behavior and assignment tests. Verify the flows manually, confirm persistence/reload and provenance preservation, then prepare a maintainer-reviewed ticket update or closure separately from new feature work.

**Known remaining baseline work from `CONTEXT.md` / `REQUIREMENTS.md`:** progress charts, calendar history, notes history, form guidance/video, richer program/template selection, HealthKit/Apple Watch boundaries, and ATG mobility templates/session logging. The body-weight/notes/rest-timer and imported-history-detail requirements appear implemented despite stale wording in `REQUIREMENTS.md`; reconcile that documentation before scheduling duplicate work. Do not let social work silently displace the import and logging baseline.

---

## 2. Wayfinder phase A — Capture before cancellation (human-led, urgent)

Agents cannot reliably inspect the user's authenticated subscription apps or private account data from this repo. No proprietary in-app capture was performed in this exploration. Before cancelling/pausing, the user should capture local evidence and keep private exports/screenshots under ignored `imports/`.

### ATG capture checklist (complete before 2026-09-04)

1. Export/download the complete workout history and preserve the original file unchanged; record export date, account/program name, timezone, and file format.
2. Screenshot or screen-record the program chooser and the currently active program, including exact program name, schedule/frequency, workout days, and any assessment/onboarding result.
3. Capture every workout template screen: exercise order, sets, reps, time/distance, sides, rounds, supersets, rest, equipment, and coaching cues.
4. Capture regression/progression controls for each exercise: assistance, range/height/angle, load, rep/time targets, pain-free rules, and how the app decides the next level.
5. Capture logging behavior: partial completion, skipped exercise, pain/pain-free note, freeform notes, timers, video/form submission, coach feedback, and resume/interruption behavior.
6. Capture progress/history screens, charts, PR/standard/assessment views, calendar/streaks, and any export/share options.
7. Record what survives cancellation: downloaded videos/articles, cached programs, history read access, and whether export remains available.

Public ATG evidence currently supports these planning requirements, not a full private app specification: app-based programs, progress tracking, exercise library, form-video coaching, 24/7 coach messaging, coach feedback, strength/mobility tracking, and programs such as Knee Ability Zero, Back Ability Zero, Longevity Zero, ATG Basics, Male Standards, and Female Standards. Official public descriptions show zero-equipment variants, 1–2 rounds of 11 exercises for Back Ability Zero, supersets, bodyweight-to-loaded progressions, and a pain-free/regression-first philosophy. They also describe progression axes including side-to-side balance, short/long range, light/heavy loading, duration, tempo, assistance, elevation, load position, and measurable standards. Cobellifterents should therefore eventually model exercises as a progression/regression graph with per-side logging, supersets, equipment/assistance/elevation/load metadata, duration, pain-free/form status, and original instructional content. The user's private program and exact app behavior must be captured rather than inferred from marketing pages; the public sources do not verify a member-to-member social feed, challenge system, leaderboard, or public friend graph.

### StrongLifts capture checklist (complete before 2026-09-05)

1. Export all history and preserve the original CSV/database export unchanged; record units, timezone, current program/template, schedule, and subscription tier.
2. Capture program/template catalog and the active program, including A/B/C workout definitions, exercise order, assistance work, alternate exercises, and custom exercises.
3. Capture every per-exercise progression setting: current weight, increment, increment frequency, failure threshold, deload percentage/frequency, reset behavior, and break/resume behavior.
4. Capture warmup and plate calculator output for representative lifts, rest timer rules, workout timer, notifications/live activity, Apple Watch behavior if used, and Apple Health data types/permissions.
5. Capture logging gestures and outcomes: complete set, partial reps, changed weight, skipped set/exercise, notes, body weight, edit workout, and unfinished-workout recovery.
6. Capture history, exercise history, e1RM/volume/reps charts, consistency calendar, PR markers, and any data export/import/share path.
7. Record what remains accessible after cancellation and save subscription cancellation/pause confirmation separately from workout data.

The local screencaps already satisfy much of checklist items 2, 4, 5, and 6 for the observed Quarantine flow. Remaining live-app capture should focus on subscription entitlement/cancellation, export semantics, the user's active configuration, exact progression/deload behavior, warmup/plate calculations, and any screens not represented in `IMG_8322.PNG`–`IMG_8338.PNG`.

Public official StrongLifts evidence verifies: 5x5 A/B with Squat + Bench/Overhead Press + Row/Deadlift, three workouts per week with rest days and alternating A/B, 5x5 straight sets and Deadlift 1x5, automatic increment on full success, repeat on failure, configurable increments/frequency, automatic configurable deload, form-aware completion, warmup and plate calculators, one-tap set logging, rest timers, exercise replacement/custom exercises, exercise videos/instructions, progress charts for weight/e1RM/volume/reps, consistency history, Apple Watch/Health sync, and broader intermediate/Madcow/templates. StrongLifts' Apple Health integration is advertised to write workouts, duration, estimated calories, body weight, and Apple Watch heart rate. Exact subscription-gated behavior and exact deload algorithm still require the user's capture. Comparable fitness apps publicly demonstrate private groups, invite codes, weekly/custom challenges, streaks, accountability, and leaderboards, but these are not verified StrongLifts features. Avoid absolute-weight rankings; attendance or completion is a fairer initial challenge metric.

### Existing StrongLifts screencap evidence (already captured locally)

The ignored local reference set at `imports/stronglifts/screenshots/IMG_8322.PNG` through `IMG_8338.PNG` materially refines the roadmap. These are observed UX requirements, not assumptions about every subscription tier:

- **Home dashboard:** upcoming workout cards show workout letter, date, exercise names, set×rep prescription, weight, and an estimated finish time; a prominent Start action and five-tab navigation are visible (Home, Programs, History, Progress, Settings).
- **Active workout:** Workout/Warmup segmented navigation; exercise rows with large per-set rep circles; set completion is the primary interaction; body weight is part of the session; persistent Note, elapsed/rest timer, and Edit actions are present. The observed Quarantine workout uses dumbbells, bodyweight, and 5×12/3×12 prescriptions, so the engine must not assume barbell-only or 5×5-only workouts.
- **Exercise detail:** Weights, Form, Progress, and History tabs; weight can be displayed per arm; settings show sets×reps, exercise weight, increment, progression frequency, deload percentage, failures-before-deload, Copy Settings, and Reset Exercise. Form includes a demonstration video, full-video action, numbered instructions, and editable notes. Progress includes a timeframe selector and a weight chart. History includes a filter and rows for date, reps, lb, and e1RM.
- **Workout editing:** rename the workout, edit exercise list/order, add exercises, set workout date, and delete the workout. This establishes that prescriptions, session dates, and history are separately editable concerns.
- **Programs/templates:** Programs have an active selection, tags such as Beginner/Intermediate/Strength & Size/Maintenance, info affordances, and separate Program/Workouts/Weights/Sets×Reps configuration areas. The Quarantine program visibly offers Intro, Build, and Advance templates, with A/B exercise lists, selection, Replace Exercises, and Next: Set Weights flow.
- **History/progress:** History has List, Calendar, and Notes views. List rows show per-exercise outcomes such as `12/12/12/12/11`, weight, workout letter, and date. Calendar marks workout dates. Notes preserve dated freeform training observations. Progress has Total, Body Weight, and exercise entries with current values and trend mini-charts.
- **Settings/integrations:** Profile/email, Subscription, Timer, Weight Unit, Auto-Lock Display, Apple Health, Apple Watch, App Icon, Help Center, guide, support, and rating are visible. Apple Health is described as syncing workouts, body weight, and estimated calories; the local screenshot shows the sync toggle enabled and Apple Watch off.

This evidence moves the minimum StrongLifts parity target from “classic A/B 5×5 logger” to “fast, configurable program/template logger with per-arm/bodyweight/time prescriptions, workout editing, exercise education, four exercise-detail tabs, calendar/notes/history, and explicit integration settings.” It does not prove the exact paid entitlement boundary or the full catalog beyond the captured screens.

### Subscription safety gate

The user—not an agent—must cancel or pause through the platform/account that owns each subscription and verify the effective date and confirmation. Do not delete the apps or private exports until exports, screenshots, and cancellation status are verified. Cancellation is not performed by this plan.

---

## 3. Wayfinder phase B — September 1 personal challenge (realistic MVP)

### Scope for the first 30 days

Build one clearly labeled **personal** challenge from September 1 through September 30, stored locally in SwiftData and derived from existing completed workout sessions where possible.

Required behavior:

- Create a challenge with name, start/end dates, device-calendar timezone semantics, and a selectable completion rule.
- Recommended first rule: one qualifying completed workout/session per calendar day, with an explicit option to count only app-recorded completed sessions versus self-attested completion.
- Show daily completion, streak, completed/remaining days, missed days, pause/cancel state, and safe reset confirmation.
- Support interrupted logging and duplicate-session prevention without changing imported provenance.
- Offer local export/import of challenge state for backup and deterministic testing.
- Use local notifications only if the user opts in; provide quiet-hours and disable controls.
- Mark any manual progress summary as self-reported and non-authoritative.

Explicit non-goals for September 1: accounts, friend discovery, shared challenge membership, server sync, invite redemption, public profiles, direct messaging, remote push, leaderboards, anti-cheat claims, and remote attendance verification. A fake friend screen may be a local prototype only and must be conspicuously labeled as a prototype.

Likely future files (after discovery and approval): a new challenge domain/repository/model, SwiftData schema migration, challenge views, local-notification coordinator, export/import support, and focused tests. Exact filenames should be confirmed by the SwiftData/frontend agent in a worktree rather than guessed in advance.

### Acceptance gate

Before calling the September 1 slice usable: create a challenge, complete a qualifying workout, verify day/streak rendering, test a missed day and device-day boundary, interrupt/resume a workout, relaunch and reload, export/import, deny notification permission, and run the full Xcode test suite plus an installed simulator smoke test. Human review must confirm the copy does not imply multiplayer behavior.

---

## 4. Wayfinder phase C — Social challenge design, then controlled build

### Product decisions required before backend work

- Challenge authority: self-attested, derived from local workout logs, or a trusted external source. Recommend self-attested/app-derived with no medical, attendance, or anti-cheating claim.
- Friend model: recommend mutual opt-in friend requests or opaque invite codes; avoid address-book upload initially.
- Visibility: private by default; explicit invite-only/friend-only visibility; do not expose exact workout details without opt-in.
- Membership lifecycle: invite, accept, decline, leave, remove, block, mute, report, expire, and delete-account behavior.
- Conflict authority: offline completion event model versus last-write-wins; define idempotency and duplicate handling first.
- Retention/export/deletion semantics across devices, caches, backups, analytics, and moderation records.
- Whether social notifications are needed at all; local reminders remain the default.

### Agent sequence and worktree discipline

1. **Researcher/product agent:** turn the captured ATG/StrongLifts evidence into a capability matrix, preserving citations and marking unknown/private behavior. No code.
2. **Tester/verifier agent:** finish verification for open #5 and #12, add only the tests/docs needed to prove their acceptance criteria, and report actual `xcodebuild` output. Use `agent/tester/...` in `~/Development/agent-worktrees/Cobellifterents--tester`.
3. **Backend/domain agent:** design the local challenge model and repository protocol behind a feature branch/worktree; one conceptual commit at a time.
4. **Frontend agent:** implement the personal challenge UI only after the domain contract is reviewed; use `agent/frontend/...` and a separate worktree.
5. **Tester/release agent:** run full tests, migration/reload tests, accessibility checks, and exact simulator smoke test; do not equate compilation with acceptance.
6. **Product/security architect:** prototype friend/challenge screens with deterministic fake users only, then threat-model identity, object authorization, enumeration, invite abuse, stalking, block/report, notification disclosure, and account deletion.
7. **Backend + identity agents:** only after approval, build a non-production Sign in with Apple service with immutable internal IDs, server-side object authorization, rate limits, expiring opaque invites, deletion/export, audit controls, and observability.
8. **Controlled-alpha tester/operations agent:** validate with consenting users, add APNs only after opt-in/quiet-hours/redaction behavior, and establish report handling, kill switch, incident owner, and rollback.

Every implementation agent must use an individual worktree, avoid `main`, commit one conceptual change at a time, report absolute worktree, branch, commit SHA, changed files, and real test/build output. Do not push or open a PR unless explicitly requested.

### Phasing

- **Aug 29–31:** human capture + product rules + challenge spike + open-ticket verification. No social backend.
- **Sep 1:** personal local challenge pilot, with known limitations visible.
- **Sep 2–7:** stabilization, migration/reload/accessibility testing, import regression testing, and renewal-period evidence review.
- **Week 2:** local-only friend/challenge UX prototype with fixtures and reviewed privacy/threat model.
- **Week 3:** authenticated backend proof of concept and feature-flagged remote adapter in a non-production environment.
- **Week 4:** small consenting social alpha only after block/remove/report, deletion, authorization, rate limits, and operational controls work end to end.
- **Month 2:** offline synchronization/conflict resolution, friend-only challenge views, privacy/App Store disclosure review.
- **Month 3+:** optional teams, reactions, comparisons, or leaderboards only if the product value justifies added exposure and moderation burden; never assume these are required for replacing either subscription.

---

## 5. Verification and decision log requirements

After meaningful work, update `.hermes/session.md`; update `.hermes/feature-file-map.md` as new feature files are discovered; record durable architecture/privacy decisions in `.hermes/decisions.md`. These files do not currently exist in the checked-out repo, so create them only during an execution/decision phase, not as part of this planning-only artifact unless the user requests broader documentation changes.

The next decision gate is human evidence capture, not implementation: confirm the exports/screenshots are available, confirm whether the first challenge should count only completed Cobellifterents sessions or allow self-attestation, and confirm whether ATG/StrongLifts cancellation/pause has been completed and verified.

## Sources

- StrongLifts official app/features: https://stronglifts.com/app/
- StrongLifts official 5x5 workout structure: https://stronglifts.com/stronglifts-5x5/workout-program/
- StrongLifts official progression guide: https://stronglifts.com/stronglifts-5x5/progress/
- StrongLifts official failure guidance: https://stronglifts.com/stronglifts-5x5/failure/
- StrongLifts Apple Health support: https://support.stronglifts.com/article/32-apple-health
- ATG official program/pricing/feature overview: https://www.atgonlinecoaching.com/
- ATG official principles: https://www.atgonlinecoaching.com/articles/the-10-atg-principles
- ATG official slant-squat progression: https://www.atgonlinecoaching.com/articles/article-slant-squat-breakdown
- ATG official home/school progression examples: https://www.atgonlinecoaching.com/articles/article-my-top-8-exercises-for-school-or-home
- ATG official mobility checklist: https://www.atgonlinecoaching.com/articles/article-childlike-mobility-routine-checklist
- ATG official beginner lifting program: https://www.atgonlinecoaching.com/articles/article-the-beginners-atg-lifting-program
- ATG official twice-weekly full-body structure: https://www.atgonlinecoaching.com/articles/article-full-body-atg-twice-per-week
- ATG official iOS listing: https://apps.apple.com/us/app/atg-online-coaching/id1609643131
- Comparable challenge patterns: https://apps.apple.com/us/app/friendsfitnesschallenge/id6759629305
- Comparable challenge patterns: https://apps.apple.com/us/app/steps-fitness-challenge/id6760107862
- Comparable health-with-friends pattern: https://apps.apple.com/us/app/proof-health-with-friends/id1622639620
- Apple HealthKit authorization: https://developer.apple.com/documentation/healthkit/authorizing-access-to-health-data
- Sign in with Apple private relay: https://developer.apple.com/documentation/signinwithapple/communicating-using-the-private-email-relay-service
