import Foundation
import SwiftData

enum TemplateID: String, Codable, CaseIterable, Identifiable {
    case strongLiftsA
    case strongLiftsB

    var id: String { rawValue }
}

struct ExerciseTemplate: Identifiable, Equatable {
    let id: String
    let name: String
    let targetSets: Int
    let targetReps: Int
    let startingWeight: Double
    let increment: Double
}

struct WorkoutTemplate: Identifiable, Equatable {
    let id: TemplateID
    let name: String
    let exercises: [ExerciseTemplate]
}

enum StrongLiftsTemplates {
    static let all: [WorkoutTemplate] = [
        WorkoutTemplate(
            id: .strongLiftsA,
            name: "Workout A",
            exercises: [
                ExerciseTemplate(id: "squat", name: "Squat", targetSets: 5, targetReps: 5, startingWeight: 45, increment: 5),
                ExerciseTemplate(id: "bench_press", name: "Bench Press", targetSets: 5, targetReps: 5, startingWeight: 45, increment: 5),
                ExerciseTemplate(id: "barbell_row", name: "Barbell Row", targetSets: 5, targetReps: 5, startingWeight: 65, increment: 5),
            ]
        ),
        WorkoutTemplate(
            id: .strongLiftsB,
            name: "Workout B",
            exercises: [
                ExerciseTemplate(id: "squat", name: "Squat", targetSets: 5, targetReps: 5, startingWeight: 45, increment: 5),
                ExerciseTemplate(id: "overhead_press", name: "Overhead Press", targetSets: 5, targetReps: 5, startingWeight: 45, increment: 5),
                ExerciseTemplate(id: "deadlift", name: "Deadlift", targetSets: 1, targetReps: 5, startingWeight: 95, increment: 10),
            ]
        ),
    ]

    static func template(after templateID: TemplateID?) -> WorkoutTemplate {
        guard templateID == .strongLiftsA else { return all[0] }
        return all[1]
    }
}

struct ProgressionRule: Equatable {
    var increment: Double
    var deloadMultiplier: Double = 0.9
    var failuresBeforeDeload: Int = 3
    var minimumWeight: Double = 45
    var plateGranularity: Double = 5
}

struct ExercisePerformance: Equatable {
    var completedAllTargetReps: Bool
}

enum ProgressionEngine {
    static func nextWeight(currentWeight: Double, consecutiveFailures: Int, performance: ExercisePerformance, rule: ProgressionRule) -> Double {
        if performance.completedAllTargetReps {
            return roundToGranularity(currentWeight + rule.increment, granularity: rule.plateGranularity)
        }

        if consecutiveFailures + 1 >= rule.failuresBeforeDeload {
            return max(
                rule.minimumWeight,
                roundToGranularity(currentWeight * rule.deloadMultiplier, granularity: rule.plateGranularity)
            )
        }

        return currentWeight
    }

    static func roundToGranularity(_ value: Double, granularity: Double) -> Double {
        guard granularity > 0 else { return value }
        return (value / granularity).rounded() * granularity
    }
}

@Model
final class WorkoutSession {
    @Attribute(.unique) var id: UUID
    var templateIDRawValue: String
    var templateName: String
    var startedAt: Date
    var completedAt: Date?
    @Relationship(deleteRule: .cascade, inverse: \WorkoutSetRecord.session) var sets: [WorkoutSetRecord]

    init(id: UUID = UUID(), templateID: TemplateID, templateName: String, startedAt: Date = Date(), completedAt: Date? = nil, sets: [WorkoutSetRecord] = []) {
        self.id = id
        self.templateIDRawValue = templateID.rawValue
        self.templateName = templateName
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.sets = sets
    }

    var templateID: TemplateID? { TemplateID(rawValue: templateIDRawValue) }
    var isComplete: Bool { completedAt != nil }
}

@Model
final class WorkoutSetRecord {
    var exerciseID: String
    var exerciseName: String
    var setNumber: Int
    var targetReps: Int
    var completedReps: Int
    var weight: Double
    var isComplete: Bool
    var session: WorkoutSession?

    init(exerciseID: String, exerciseName: String, setNumber: Int, targetReps: Int, completedReps: Int = 0, weight: Double, isComplete: Bool = false) {
        self.exerciseID = exerciseID
        self.exerciseName = exerciseName
        self.setNumber = setNumber
        self.targetReps = targetReps
        self.completedReps = completedReps
        self.weight = weight
        self.isComplete = isComplete
    }
}

extension WorkoutSession {
    static func seeded(from template: WorkoutTemplate, history: [WorkoutSession]) -> WorkoutSession {
        let session = WorkoutSession(templateID: template.id, templateName: template.name)
        session.sets = template.exercises.flatMap { exercise in
            let nextWeight = WorkoutSession.nextWeight(for: exercise, history: history)
            return (1...exercise.targetSets).map { setNumber in
                WorkoutSetRecord(
                    exerciseID: exercise.id,
                    exerciseName: exercise.name,
                    setNumber: setNumber,
                    targetReps: exercise.targetReps,
                    weight: nextWeight
                )
            }
        }
        return session
    }

    private static func nextWeight(for exercise: ExerciseTemplate, history: [WorkoutSession]) -> Double {
        let completedExerciseSessions = history
            .filter { $0.isComplete }
            .compactMap { session -> [WorkoutSetRecord]? in
                let sets = session.sets.filter { $0.exerciseID == exercise.id }
                return sets.isEmpty ? nil : sets
            }
            .sorted { lhs, rhs in
                guard let leftDate = lhs.first?.session?.completedAt ?? lhs.first?.session?.startedAt,
                      let rightDate = rhs.first?.session?.completedAt ?? rhs.first?.session?.startedAt else {
                    return false
                }
                return leftDate > rightDate
            }

        guard let latest = completedExerciseSessions.first else { return exercise.startingWeight }
        let currentWeight = latest.first?.weight ?? exercise.startingWeight
        let latestSucceeded = latest.allSatisfy { $0.isComplete && $0.completedReps >= $0.targetReps }
        let failures = completedExerciseSessions.prefix(while: { sets in
            !sets.allSatisfy { $0.isComplete && $0.completedReps >= $0.targetReps }
        }).count

        return ProgressionEngine.nextWeight(
            currentWeight: currentWeight,
            consecutiveFailures: failures,
            performance: ExercisePerformance(completedAllTargetReps: latestSucceeded),
            rule: ProgressionRule(increment: exercise.increment, minimumWeight: exercise.startingWeight)
        )
    }
}
