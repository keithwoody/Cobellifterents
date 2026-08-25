import Foundation

/// Formats the identity shown for a workout without changing persisted session data.
enum WorkoutDisplayNaming {
    static let separator = " • "
    static let builtInStrongLiftsProgramName = "StrongLifts 5×5"

    static func combined(programName: String, workoutName: String) -> String {
        let program = programName.trimmingCharacters(in: .whitespacesAndNewlines)
        let workout = workoutName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !program.isEmpty else { return workout }
        guard !workout.isEmpty else { return program }
        if workout == program || workout.hasPrefix(program + separator) { return workout }
        return program + separator + workout
    }

    static func displayName(programName: String?, workoutName: String, templateID: TemplateID? = nil) -> String {
        if let programName, !programName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return combined(programName: programName, workoutName: workoutName)
        }
        if let templateID, isBareStrongLiftsWorkoutName(workoutName),
           templateID == .strongLiftsA || templateID == .strongLiftsB {
            return combined(programName: builtInStrongLiftsProgramName, workoutName: workoutName)
        }
        return workoutName
    }

    static func displayName(for session: WorkoutSession) -> String {
        displayName(programName: nil, workoutName: session.templateName, templateID: session.templateID)
    }

    private static func isBareStrongLiftsWorkoutName(_ name: String) -> Bool {
        ["Workout A", "Workout B"].contains(name.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
