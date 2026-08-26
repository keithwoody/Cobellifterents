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
        let assignedProgramName = session.programAssignmentID != nil
            ? programName(for: session)
            : session.importProgramAssignment?.displayName
        return displayName(
            programName: assignedProgramName,
            workoutName: session.templateName,
            templateID: session.templateID
        )
    }

    /// Returns the program associated with a persisted workout, including explicit
    /// fallbacks for older sessions that predate program assignment metadata.
    static func programName(for session: WorkoutSession) -> String {
        if let rawAssignment = session.programAssignmentRawValue,
           let assignment = ImportProgramAssignment(rawValue: rawAssignment),
           assignment != .unassignedAmbiguous {
            return assignment.displayName
        }

        // Manual assignment stores the selected Program name alongside its stable
        // ID. It is intentionally not an ImportProgramAssignment raw value, and
        // must win over the imported template/source name on every display path.
        if session.programAssignmentID != nil,
           let explicitName = session.programAssignmentRawValue?.trimmingCharacters(in: .whitespacesAndNewlines),
           !explicitName.isEmpty {
            return explicitName
        }

        if let templateID = session.templateID,
           templateID == .strongLiftsA || templateID == .strongLiftsB,
           isBareStrongLiftsWorkoutName(session.templateName) {
            return builtInStrongLiftsProgramName
        }

        // Custom workouts persist their program in the display name so that the
        // existing navigation and persistence contract remains unchanged.
        let separator = Self.separator
        if let separatorRange = session.templateName.range(of: separator) {
            let prefix = String(session.templateName[..<separatorRange.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !prefix.isEmpty { return prefix }
        }

        return "Unassigned (program unclear)"
    }

    private static func isBareStrongLiftsWorkoutName(_ name: String) -> Bool {
        ["Workout A", "Workout B"].contains(name.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
