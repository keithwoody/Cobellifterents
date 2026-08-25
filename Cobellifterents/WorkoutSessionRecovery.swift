import Foundation

enum WorkoutSessionRecovery {
    static func resumableSession(from sessions: [WorkoutSession]) -> WorkoutSession? {
        sessions.first { !$0.isComplete && !$0.sets.isEmpty }
    }
}