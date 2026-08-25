# Cobellifterents domain context

Cobellifterents is a native iPhone-only SwiftUI fitness app using SwiftData for local persistence and XcodeGen for project generation.

## Product focus

The app combines StrongLifts-style strength tracking and ATG mobility workout history. Current priority is reliable ATG workout data import so historical mobility work is available in the app before expanding the StrongLifts logging experience.

## Import model

Imports preserve immutable raw provenance and also create editable native records when the source data is safe to convert. Stable source IDs provide idempotent re-import. Rows with insufficient date or session-boundary information remain provenance-only; the app must not invent dates or workout boundaries.

## ATG program context

Historical ATG activity may belong to mobility programs such as Knee Ability Zero, Back Ability Zero, and Ankle Ability Zero. Program assignment must be evidence-based. If the export does not identify the program or cannot safely infer it, preserve the row and surface the ambiguity for review rather than silently assigning it. The current ATG export contains only `Strength Training` as `workout_type` and does not identify Knee, Back, or Ankle Ability Zero. The user believes the most recent historical program was probably Ankle Ability Zero, but this is not yet confirmed by export evidence and must not be applied automatically.

## Privacy

Raw personal CSV exports and screenshots under `imports/` are local reference data and must remain ignored and uncommitted.
