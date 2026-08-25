import Foundation

enum HistoryFormatting {
    static func recentCompletedSessions(from sessions: [WorkoutSession], limit: Int = 5) -> [WorkoutSession] {
        guard limit > 0 else { return [] }
        return Array(sessions.filter(\.isComplete).prefix(limit))
    }

    static func shouldShowFullHistoryLink(for sessions: [WorkoutSession]) -> Bool {
        !sessions.isEmpty
    }

    static func weight(_ value: Double) -> String {
        "\(value.formatted(.number.precision(.fractionLength(value.truncatingRemainder(dividingBy: 1) == 0 ? 0 : 1)))) lb"
    }

    static func setOutcome(completedReps: Int, targetReps: Int, weight: Double) -> String {
        "\(completedReps)/\(targetReps) reps · \(self.weight(weight))"
    }

    static func sourceLabel(_ rawValue: String) -> String {
        switch rawValue {
        case "strongLiftsCSV": return "StrongLifts CSV"
        case "atgCSV": return "ATG CSV"
        default: return rawValue
        }
    }
}