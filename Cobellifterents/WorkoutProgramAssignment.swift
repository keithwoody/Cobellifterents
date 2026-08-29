import Foundation
import SwiftData

/// Errors raised when changing the Program attached to an imported workout.
enum WorkoutProgramAssignmentError: Equatable, Error {
    case workoutNotImported
    case programNotFound
    case unsupportedProgramKind
}

/// The mutation boundary used by both individual and bulk UI actions.
/// Program assignment is stored by stable Program UUID; source and set fields are never touched.
enum WorkoutProgramAssignment {
    @discardableResult
    static func assign(_ session: WorkoutSession, to program: Program, in context: ModelContext) throws -> Bool {
        guard session.isImported else { throw WorkoutProgramAssignmentError.workoutNotImported }
        guard program.isValid else { throw WorkoutProgramAssignmentError.unsupportedProgramKind }
        let changed = session.programAssignmentID != program.id
        session.programAssignmentID = program.id
        session.programAssignmentRawValue = program.name
        session.programAssignmentEvidence = "manual"
        if changed { try context.save() }
        return changed
    }

    @discardableResult
    static func clear(_ session: WorkoutSession, in context: ModelContext) throws -> Bool {
        guard session.isImported else { throw WorkoutProgramAssignmentError.workoutNotImported }
        let changed = session.programAssignmentID != nil || session.programAssignmentRawValue != nil
        session.programAssignmentID = nil
        session.programAssignmentRawValue = nil
        session.programAssignmentEvidence = nil
        if changed { try context.save() }
        return changed
    }

    /// Assigns every imported session in one save, returning the number actually changed.
    /// Callers should confirm the displayed count before invoking this for a large selection.
    @discardableResult
    static func assign(_ sessions: [WorkoutSession], to program: Program, in context: ModelContext) throws -> Int {
        guard program.isValid else { throw WorkoutProgramAssignmentError.unsupportedProgramKind }
        let imported = sessions.filter(\.isImported)
        guard imported.count == sessions.count else { throw WorkoutProgramAssignmentError.workoutNotImported }
        var changed = 0
        for session in imported where session.programAssignmentID != program.id {
            session.programAssignmentID = program.id
            session.programAssignmentRawValue = program.name
            session.programAssignmentEvidence = "manual"
            changed += 1
        }
        if changed > 0 { try context.save() }
        return changed
    }

    @discardableResult
    static func clear(_ sessions: [WorkoutSession], in context: ModelContext) throws -> Int {
        let imported = sessions.filter(\.isImported)
        guard imported.count == sessions.count else { throw WorkoutProgramAssignmentError.workoutNotImported }
        var changed = 0
        for session in imported where session.programAssignmentID != nil || session.programAssignmentRawValue != nil {
            session.programAssignmentID = nil
            session.programAssignmentRawValue = nil
            session.programAssignmentEvidence = nil
            changed += 1
        }
        if changed > 0 { try context.save() }
        return changed
    }

    /// Updates cached assignment names for sessions attached to a renamed Program.
    /// Stable IDs identify the affected sessions; provenance and assignment evidence remain unchanged.
    @discardableResult
    static func propagateRename(_ program: Program, to sessions: [WorkoutSession], in context: ModelContext) throws -> Int {
        let renamedSessions = sessions.filter {
            $0.programAssignmentID == program.id && $0.programAssignmentRawValue != program.name
        }
        guard !renamedSessions.isEmpty else { return 0 }
        for session in renamedSessions {
            session.programAssignmentRawValue = program.name
        }
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
        return renamedSessions.count
    }

    static func program(for session: WorkoutSession, in programs: [Program]) -> Program? {
        guard let id = session.programAssignmentID else { return nil }
        return programs.first { $0.id == id }
    }
}

extension WorkoutSession {
    var hasProgramAssignment: Bool { programAssignmentID != nil }
}

extension WorkoutProgramAssignmentError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .workoutNotImported: return "Only imported workouts can be assigned to a Program."
        case .programNotFound: return "The selected Program no longer exists."
        case .unsupportedProgramKind: return "The selected Program is not valid yet."
        }
    }
}

/// Stable presentation hooks for history/detail screens; views can use these without
/// coupling themselves to import provenance or mutation details.
enum WorkoutProgramPresentation {
    static func name(for session: WorkoutSession, programs: [Program]) -> String {
        WorkoutProgramAssignment.program(for: session, in: programs)?.name
            ?? (session.programAssignmentRawValue ?? "Unassigned")
    }
}
