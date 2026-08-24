import Foundation

struct InferredProgram {
    let program: Program
    let needsScheduleEditing: Bool
}

/// Pure conversion of imported native sessions into an editable Program.
enum ImportToProgramInference {
    static func infer(from drafts: [WorkoutSessionDraft], sourceKind: ImportSourceKind? = nil) -> InferredProgram? {
        guard !drafts.isEmpty else { return nil }
        let kind = sourceKind ?? drafts[0].sourceKind
        let isStrongLifts = kind == .strongLiftsCSV || drafts.contains { strongIdentity($0.templateName) != nil }
        let programKind: ProgramKind = isStrongLifts ? .strongLifts : .atg
        let name = displayName(fileName: drafts[0].sourceFileName, kind: kind)
        let sourceKey = "\(kind.rawValue):\(drafts[0].sourceFileName.lowercased())"
        let templates = orderedUnique(drafts.map { normalized($0.templateName).isEmpty ? "Workout" : $0.templateName.trimmingCharacters(in: .whitespacesAndNewlines) })
        var workouts: [ProgramWorkout] = []
        for template in templates {
            let matching = drafts.filter { (normalized($0.templateName).isEmpty ? "Workout" : $0.templateName.trimmingCharacters(in: .whitespacesAndNewlines)) == template }
            let exerciseNames = orderedUnique(matching.flatMap { $0.sets.map(\.exerciseName) })
            let exercises = exerciseNames.map { exerciseName in
                let sets = matching.flatMap { $0.sets.filter { $0.exerciseName == exerciseName } }
                return ProgramExercise(name: exerciseName, targetSets: representativeSets(sets), targetReps: representativeReps(sets))
            }
            let days = orderedUnique(matching.map { trainingDay(for: $0.startedAt) }).sorted()
            let identity = isStrongLifts ? strongIdentity(template) : nil
            workouts.append(ProgramWorkout(identity: identity, name: template, exercises: exercises, assignedDays: days))
        }
        if isStrongLifts {
            for index in workouts.indices where strongIdentity(workouts[index].name) != nil {
                let identity = strongIdentity(workouts[index].name)!
                workouts[index].identity = identity
                workouts[index].name = "Workout \(identity)"
            }
        } else {
            let allDays = Set(workouts.flatMap(\.assignedDays)).sorted()
            if allDays.count > 5 {
                let allowed = Set(allDays.prefix(5))
                for index in workouts.indices { workouts[index].assignedDays = workouts[index].assignedDays.filter { allowed.contains($0) } }
            }
        }
        let dayCount = Set(workouts.flatMap(\.assignedDays)).count
        return InferredProgram(
            program: Program(kind: programKind, name: name, workouts: workouts, generatedSourceKey: sourceKey),
            needsScheduleEditing: programKind == .atg && !(3...5).contains(dayCount)
        )
    }

    static func displayName(fileName: String, kind: ImportSourceKind) -> String {
        let base = (fileName as NSString).deletingPathExtension.trimmingCharacters(in: .whitespacesAndNewlines)
        return base.isEmpty ? "Imported \(kind == .strongLiftsCSV ? "StrongLifts" : "ATG") Program" : "Imported \(base)"
    }

    private static func normalized(_ value: String) -> String { value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
    private static func orderedUnique<T: Hashable>(_ values: [T]) -> [T] { var seen = Set<T>(); return values.filter { seen.insert($0).inserted } }
    private static func strongIdentity(_ template: String) -> String? {
        switch normalized(template) { case "workout a": return "A"; case "workout b": return "B"; default: return nil }
    }
    private static func representativeSets(_ sets: [WorkoutSetDraft]) -> Int { max(1, sets.map(\.setNumber).max() ?? sets.count) }
    private static func representativeReps(_ sets: [WorkoutSetDraft]) -> Int { max(1, sets.map(\.targetReps).filter { $0 > 0 }.max() ?? 1) }
    private static func trainingDay(for date: Date) -> TrainingDay {
        let weekday = Calendar(identifier: .gregorian).component(.weekday, from: date)
        return [.sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday][weekday - 1]
    }
}
