# ATG Capability Matrix

> Derived from the local ATG export and screen recording. This document is a research artifact, not a reproduction of ATG proprietary content. Original files remain under the ignored `imports/` directory and were not modified.

**Evidence files**

- CSV: `imports/atg/ATG Workout History.csv`
- Recording: `imports/atg/screenshots/ScreenRecording_08-29-2026 10-01-47_1.MP4`
- CSV facts below use exact line ranges from the 3,727-line file.
- Recording observations use approximate timestamps because the 119.05-second recording was sampled at approximately 10-second intervals.

## Matrix

| Capability area | Evidence status | Observed/verified behavior | Cobellifterents implication | Evidence |
|---|---|---|---|---|
| Program browsing | Observed | Training browse shows categories such as `Zero Equipment` and `Extras`, a search control, program cards, and a `Rest` card. | Add program category/filter/search concepts; do not assume every program is a workout template. | Recording ~01:30–01:40 |
| Program families | Observed | Visible names include Back Ability Zero, Back Ability Basics, Back Ability Pro, Knee Ability Zero, and Ankle Ability Zero. | Model related program stages/families separately from individual workouts. | Recording ~00:30–01:00, ~01:40 |
| Program progression ladder | Observed/inferred | Program pages show `PROGRAM PROGRESSIONS` and adjacent stage tabs; Back Ability Zero, Basics, and Pro appear related. | Represent program-stage relationships, but do not invent transition eligibility or automated rules. | Recording ~00:30, ~00:50 |
| Active program tracking | Observed | A confirmation dialog says beginning a new program stops tracking the previous program while preserving everything saved. | Support one active tracked program with historical records retained; define switching semantics explicitly. | Recording ~01:00 |
| Weekly progression | Observed/inferred | Workout view shows a `WEEKS` row, completed checkmark circles, a current Week 11 circle, edit affordance, and `WEEK 11`. | Add week-level progress state and editable week navigation; exact completion semantics remain unknown. | Recording ~00:00–00:20 |
| Weekly scheduling | Observed | Monday and Wednesday sections are visible; later content includes a Thursday section. | Schedule needs weekday sections and possibly multiple sessions per week. | Recording ~00:00–00:20, ~01:50 |
| Supersets | Observed | Brackets connect exercises; description states bracketed exercises form a superset and users perform one set of each exercise in the bracket. | Existing `supersetGroupID` is useful; add explicit ordering and round semantics. | Recording ~00:40–01:10 |
| Repetition prescriptions | Observed | Examples include 20, 25, 10–12, 15–20, and “up to” targets. | Prescriptions need flexible max/target semantics, not only fixed integer reps. | Recording ~00:40–01:50; CSV lines 2–3727 |
| Timed prescriptions | Observed | Examples include 5-minute backward walking, 1-minute back extension, 30-second stretches, 20-second L-sit, and 30/60/300/600-second export values. | Model duration as a first-class prescription and result, distinct from reps. | Recording ~00:00–01:50; CSV lines 137–159, 183–250 |
| Per-side work | Observed | Multiple prescriptions explicitly say per side, including split squat stretch, pigeon, Patrick Step, ATG Split Squat, Elephant Walk, and mobility work. | Add laterality/side to the native model; do not infer side from duplicate rows alone. | Recording ~00:00–01:50; CSV row patterns |
| Equipment variants | Observed | Prescriptions reference sled/resisted treadmill, slantboard, dumbbells, MonkeyFoot/low-cable, and bodyweight-style variants. | Exercise variants should carry equipment requirements and substitutions. | Recording ~00:40; CSV lines 2–3727 notes |
| Exercise logging | Observed | Piriformis Push-up detail exposes Add a note, date/Today, Pounds, Reps, and a completion/check control. Older logged entries show time-relative history. | Build per-exercise entries with date, reps/load/duration, note, and completion state. | Recording ~01:20 |
| Exercise history | Observed/inferred | Detail screen shows current and older entries with pounds, reps, notes, and completion. | Preserve a history timeline per exercise and variant. | Recording ~01:20 |
| Instructional media | Observed | Exercise detail shows video thumbnail/play control, Coach Chat, and Send in Form. | Keep media metadata and coaching/form-review actions separate from workout records. | Recording ~01:20 |
| Coach communication | Observed | Chat appears in bottom navigation; exercise detail exposes Coach Chat and Send in Form. | A future coaching integration is distinct from friend/social challenges; requires account, upload, privacy, and moderation decisions. | Recording ~01:20–01:40 |
| Editorial content | Observed | Program pages include descriptions and Read full article links. | Support original articles/guidance links; do not copy ATG content without rights review. | Recording ~00:30–00:50 |
| Progress tracking | Observed | Program pages show Track Progress; weekly completion circles are visible. | Track active program/week completion separately from individual exercise logs. | Recording ~00:30–01:00 |
| Progress charts | Not observed | No chart axes or trend dashboard were visible in the sampled recording. | Do not assume ATG chart metrics; capture more evidence if required. | Unknown; recording sample |
| Search/filter | Observed | Category selector and search button are visible. | Add search/filter requirements to program and exercise library planning. | Recording ~01:30–01:40 |
| Rest state | Observed | A Rest card appears in the training browse surface. | Represent scheduled rest/recovery entries explicitly, not only absent workouts. | Recording ~01:30–01:40 |
| Account/profile | Surface observed only | Profile is visible in bottom navigation, but no profile or login flow is shown. | Account requirements remain unknown. | Recording ~01:30–01:40 |
| Subscription/commerce | Surface observed only | Shop is visible, but no billing, paywall, renewal, cancellation, or plan entitlement screen is shown. | Do not infer post-cancellation access or entitlement behavior. | Recording ~01:30–01:40 |
| Social/community | Not observed | No friend feed, member-to-member messaging, challenge, leaderboard, or community screen was captured. | Do not treat coach Chat as a social graph. Social design remains a separate Cobellifterents phase. | Recording ~01:20–01:40 |
| Export structure | Verified | CSV header contains workout_type, exercise, date, repetitions, resistance, resistance_unit, duration_seconds, duration_ms, and note. | Preserve raw fields and add versioned mapping; do not discard unsupported values. | CSV line 1 |
| Workout type | Verified | All 3,726 data rows use `Strength Training`. | Export does not identify ATG program or workout session. | CSV lines 2–3727 |
| Dates | Verified limitation | 598 rows are undated; 3,128 rows have dates spanning 190 calendar dates from 2024-01-11 through 2026-05-09. | Dated rows may be grouped by exact date/type only; undated rows remain provenance-only. | CSV lines 2–599, 600–614, 3716–3727 |
| Session boundaries | Verified limitation | No session ID, timestamp, workout title, program, set number, or side field exists. | Never infer one workout per date, set numbers, sides, or programs from duplicate rows. | CSV header and all rows |
| Repetition data | Verified | 61 rows have blank repetitions; nonblank values include 1, 3, 5, 6, 7, 10–33 with gaps. | Support blank/unknown reps and avoid treating every row as one completed set. | CSV lines 2–3727 |
| Resistance data | Verified | 730 rows have blank resistance; 2,416 explicitly contain 0; remaining nonblank values range from 3 to 45 lb, including fractional values. | Preserve blank versus zero; support fractional loads and unit metadata. | CSV lines 2–3727 |
| Duration data | Verified | 348 rows have blank duration; 2,419 explicitly contain 0; nonzero values are 20, 30, 45, 60, 300, or 600 seconds. Milliseconds match seconds × 1,000. | Preserve blank versus zero and normalize seconds as canonical duration. | CSV lines 2–3727; representative lines 137–159, 183–250 |
| Notes | Verified | 1,096 rows contain notes with 543 distinct note strings. Notes include equipment substitutions, form/pain/fatigue observations, rest intervals, and progression decisions. | Notes are a major source of user-authored progression/context data and need searchable preservation. | CSV lines 2–3727; representative noted block around lines 3458–3473 |
| Exercise naming | Verified limitation | CSV names differ from visible labels: Patrick Step Up/Down, Standing/Pancake Pulse, Wall Pullover/Pullover, and Full Range ATG Row variants. | Keep immutable source labels and use explicit, reviewable aliases rather than silent merges. | CSV lines 2–3727; recording ~00:40–01:50 |

## Normalized capability requirements

### High-confidence requirements for the ATG replacement slice

1. A program contains stages, weeks, weekday sections, exercises, prescriptions, and optional rest entries.
2. A workout can contain bracketed supersets with a defined exercise order.
3. An exercise prescription can be reps, duration, distance/time, “up to” reps, or a mixed/optional target.
4. A log entry supports date, completion state, reps, duration, load, unit, side, note, and source provenance.
5. A program can be selected for active progress tracking without deleting prior program history.
6. Exercises need original source labels, stable internal identity, and manually reviewed aliases.
7. Mobility work requires per-side support and must distinguish blank, zero, and nonzero values.
8. User notes must remain first-class data because they document substitutions, symptoms, fatigue, form, rest, and progression decisions.

### Requirements still requiring live-app evidence

- Exact program-stage transition rules and eligibility.
- Whether a program can be rescheduled or combined with another active program.
- Exact set/round completion behavior and partial-completion semantics.
- Exact automated progression/regression recommendations.
- Chart metrics and standard/assessment calculations.
- Export coverage for videos, coach messages, attachments, and program metadata.
- Subscription entitlement and what remains available after cancellation.
- Account deletion, privacy settings, notifications, HealthKit/Apple Watch, and connected devices.

## Source citations

- `imports/atg/ATG Workout History.csv`, lines 1–3727: complete header and dataset.
- `imports/atg/ATG Workout History.csv`, lines 2–599: undated leading records.
- `imports/atg/ATG Workout History.csv`, lines 600–614: first dated block.
- `imports/atg/ATG Workout History.csv`, lines 3716–3727: final dated block.
- `imports/atg/ATG Workout History.csv`, lines 137–159: 600-second backward walking records.
- `imports/atg/ATG Workout History.csv`, lines 183–250: timed stretch records.
- `imports/atg/ATG Workout History.csv`, approximately lines 3458–3473: notes, zero resistance, repeated exercises, and durations.
- `imports/atg/screenshots/ScreenRecording_08-29-2026 10-01-47_1.MP4`, approximately 00:00–01:50: all visual observations in this matrix.
