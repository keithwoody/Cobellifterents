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

## Planned but not yet implemented

- In-app file picker/import UI that inserts `ImportedRawRecord` and converted `WorkoutSession` objects into SwiftData.
- Import preview screen showing raw row count, converted session count, and issues before commit.
- Import and annotate screenshots from StrongLifts and ATG apps to extract UX requirements.
- ATG mobility workout templates and session logging.
- HealthKit read/write boundary for Apple Health sync.
- Settings for units, increments, warmups, timer behavior, rest periods, and deload policy.

## Next grilling questions

1. What exported data formats are available from StrongLifts and ATG?
2. Which HealthKit quantities must sync first: workouts, body mass, active energy, exercise minutes, heart rate, or strength samples?
3. What ATG mobility primitives matter most: timed holds, reps, side-specific work, regressions/progressions, pain score, range score, or notes?
4. Should imported history be immutable source-of-truth data, editable app-native sessions, or both?
