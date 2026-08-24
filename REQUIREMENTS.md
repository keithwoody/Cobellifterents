# Cobellifterents initial product notes

## Decisions already grilled and accepted

- Target: native iPhone-only SwiftUI first.
- Persistence: SwiftData local storage first.
- First working slice: StrongLifts-style A/B logging.
- First templates: standard StrongLifts 5x5 defaults.
  - A: Squat, Bench Press, Barbell Row.
  - B: Squat, Overhead Press, Deadlift.
- First implementation should build and run before deeper planning.

## First milestone scope

The first milestone is a local-only app that can:

1. Show the next A/B workout.
2. Start a workout from a seeded template.
3. Track sets, reps, weight, and completion.
4. Save completed workout history in SwiftData.
5. Compute next weights with StrongLifts-style progression:
   - success adds the exercise increment;
   - early failures repeat the weight;
   - repeated failures deload by 10%, rounded to normal 5 lb jumps.

## Import continuity policy

Decision: imports should do both provenance preservation and native conversion.

- Raw CSV rows are preserved as immutable provenance records using stable source IDs.
- Importable rows are converted into editable native workout sessions and set records.
- Imported native sessions carry source kind, source file, and source record ID for future dedupe/reconciliation.
- Rows that cannot safely become sessions, such as ATG rows with blank dates, are preserved as raw provenance only and reported as import issues.
- Raw personal exports and screenshots stay under `imports/` and are ignored by git.

Current CSV observations:

- StrongLifts file groups into dated A/B workout sessions and is suitable for native conversion.
- ATG file contains many blank-date rows; those require provenance-only handling until we know whether dates are recoverable from another export or app context.

## Current milestone focus

Focus StrongLifts workout tracking first. ATG import and ATG-specific workout features are deferred until the StrongLifts logging loop is usable day-to-day.

Implemented tracking/import baseline:

- In-app file picker/import UI inserts `ImportedRawRecord` and converted `WorkoutSession` objects into SwiftData.
- Import preview shows raw row count, converted session count, and issues before commit.
- StrongLifts CSV exports with BOM/CRLF line endings preview correctly.
- Imported StrongLifts history appears in Recent History and is marked as imported.

Next StrongLifts tracking requirements:

- Preserve the StrongLifts template exercise order on the active workout screen instead of sorting alphabetically.
- Make each work set directly editable for reps and working weight.
- Show workout progress while logging, such as completed sets over total sets.
- Keep screenshot-derived UX requirements local under `imports/screenshots/`; no screenshots are committed.

## Screenshot-derived StrongLifts requirements

Screenshots added locally under `imports/screenshots/` on 2026-08-24. They are ignored by git and treated as local reference material.

Observed StrongLifts UX surfaces:

- `IMG_8322.PNG` home dashboard:
  - Dark theme with bottom tabs: Home, Programs, History, Progress, Settings.
  - Shows upcoming workout cards with workout date, exercise names, set/rep/weight prescriptions.
  - Shows a start-workout card with estimated finish time and a prominent Start button.
- `IMG_8323.PNG` active workout:
  - Workout/Warmup segmented control.
  - Exercise rows show prescribed sets/reps/weight.
  - Each work set is a large tappable circle containing target reps.
  - Body weight is logged as part of the workout.
  - Persistent bottom actions: Note, rest timer, Edit.
- `IMG_8324.PNG` exercise weight/progression settings:
  - Exercise has sets x reps, exercise weight, increment, deload percent, and deload frequency.
  - Supports copying settings and resetting exercise progression.
- `IMG_8325.PNG` exercise form guidance:
  - Form tab includes a demo video/full-video action plus step-by-step instructions and notes.
- `IMG_8326.PNG` progress chart:
  - Exercise-level progress chart with timeframe picker.
- `IMG_8327.PNG` exercise history table:
  - Exercise-level history table with date, reps, lb, and e1RM.
- `IMG_8328.PNG` edit workout:
  - Workout can be edited: rename, edit exercise list/order, add exercise, set workout date, delete workout.
- `IMG_8329.PNG` programs list:
  - Multiple StrongLifts programs/templates with tags and info buttons.
  - Separate program/workout/weight/sets x reps configuration tabs.
- `IMG_8330.PNG` to `IMG_8332.PNG` template selection:
  - Quarantine program has Intro, Build, Advance templates.
  - Template cards show A/B exercise lists and set/rep prescriptions.
  - Flow supports replace exercises and then setting weights.
- `IMG_8333.PNG` history list:
  - List history shows each workout with date and per-exercise set outcomes/weights.
- `IMG_8334.PNG` history calendar:
  - Calendar view marks completed workout dates.
- `IMG_8335.PNG` workout notes history:
  - Notes tab lists dated freeform notes across workouts.
- `IMG_8336.PNG` progress dashboard:
  - Progress screen lists total/body weight/exercise entries with current values and trend mini-charts.
- `IMG_8337.PNG` settings:
  - Settings include timer, weight unit, auto-lock, Apple Health, Apple Watch, app icon, help/guide/support/rating.
- `IMG_8338.PNG` Apple Health:
  - Apple Health sync toggle covers workouts, body weight, and estimated calories.

Prioritized StrongLifts requirements for today/next:

1. Active workout logging must be fast: large tappable set-completion controls, visible reps/weight, workout progress, and workout order preserved.
2. Active workout logging should support body weight, notes, and rest timer as first-class bottom actions.
3. Recent History should show per-exercise set outcomes and weights, not just workout name/date.
4. Imported StrongLifts history should be browseable into session details so imported continuity is visible and auditable.
5. Exercise progression should be inspectable/editable per exercise: current weight, increment, deload percent/frequency.
6. Later: program/template management, progress charts, calendar history, notes history, Apple Health, Apple Watch.

Implemented in the current StrongLifts tracking checkpoint:

- Active workout preserves template exercise order.
- Work sets expose direct reps and weight editing.
- Active workout shows completed set count over total set count.

## Planned but not yet implemented

- Body weight field, workout notes, and rest timer on the active workout screen.
- Per-exercise set outcome/weight summaries in Recent History.
- Imported workout detail screen.
- Import and annotate any additional StrongLifts screenshots as UX requirements evolve.
- HealthKit read/write boundary for Apple Health sync.
- Settings for units, increments, warmups, timer behavior, rest periods, and deload policy.
- ATG mobility workout templates and session logging after StrongLifts tracking is usable.

## Next grilling questions

1. What exported data formats are available from StrongLifts and ATG?
2. Which HealthKit quantities must sync first: workouts, body mass, active energy, exercise minutes, heart rate, or strength samples?
3. What ATG mobility primitives matter most: timed holds, reps, side-specific work, regressions/progressions, pain score, range score, or notes?
4. Should imported history be immutable source-of-truth data, editable app-native sessions, or both?
