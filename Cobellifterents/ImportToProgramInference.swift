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
        var workouts: [ProgramWorkout] = []
        var inferredTrainingDays: [TrainingDay] = []
        if isStrongLifts {
            // StrongLifts has a fixed two-workout shape. Unknown names are ignored rather
            // than becoming unrelated editable workouts in the generated program.
            for identity in ["A", "B"] {
                let matching = drafts.filter { strongIdentity($0.templateName) == identity }
                let exerciseNames = orderedUnique(matching.flatMap { $0.sets.map(\.exerciseName) })
                let exercises = exerciseNames.map { exerciseName in
                    let sets = matching.flatMap { $0.sets.filter { $0.exerciseName == exerciseName } }
                    return ProgramExercise(name: exerciseName, targetSets: representativeSets(sets), targetReps: representativeReps(sets))
                }
                let days = orderedUnique(matching.map { trainingDay(for: $0.startedAt) }).sorted()
                inferredTrainingDays.append(contentsOf: days)
                workouts.append(ProgramWorkout(identity: identity, name: "Workout \(identity)", exercises: exercises))
            }
            inferredTrainingDays = orderedUnique(inferredTrainingDays).sorted()
        } else {
            let templates = orderedUnique(drafts.map { normalized($0.templateName).isEmpty ? "Workout" : $0.templateName.trimmingCharacters(in: .whitespacesAndNewlines) })
            for template in templates {
                let matching = drafts.filter { (normalized($0.templateName).isEmpty ? "Workout" : $0.templateName.trimmingCharacters(in: .whitespacesAndNewlines)) == template }
                let exerciseNames = orderedUnique(matching.flatMap { $0.sets.map(\.exerciseName) })
                let exercises = exerciseNames.map { exerciseName in
                    let sets = matching.flatMap { $0.sets.filter { $0.exerciseName == exerciseName } }
                    return ProgramExercise(name: exerciseName, targetSets: representativeSets(sets), targetReps: representativeReps(sets))
                }
                let days = orderedUnique(matching.map { trainingDay(for: $0.startedAt) }).sorted()
                workouts.append(ProgramWorkout(identity: nil, name: template, exercises: exercises, assignedDays: days))
            }
        }
        if !isStrongLifts {
            let allDays = Set(workouts.flatMap(\.assignedDays)).sorted()
            if allDays.count > 5 {
                let allowed = Set(allDays.prefix(5))
                for index in workouts.indices { workouts[index].assignedDays = workouts[index].assignedDays.filter { allowed.contains($0) } }
            }
        }
        let dayCount = Set(workouts.flatMap(\.assignedDays)).count
        return InferredProgram(
            program: Program(kind: programKind, name: name, workouts: workouts, trainingDays: inferredTrainingDays, generatedSourceKey: sourceKey),
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
        let tokens = normalized(template)
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
        if tokens.count == 1, let token = tokens.first, token == "a" || token == "b" {
            return token.uppercased()
        }
        guard let workoutIndex = tokens.firstIndex(of: "workout"), tokens.index(after: workoutIndex) < tokens.endIndex else { return nil }
        let identity = tokens[tokens.index(after: workoutIndex)]
        return identity == "a" || identity == "b" ? identity.uppercased() : nil
    }
    private static func representativeSets(_ sets: [WorkoutSetDraft]) -> Int { max(1, sets.map(\.setNumber).max() ?? sets.count) }
    private static func representativeReps(_ sets: [WorkoutSetDraft]) -> Int { max(1, sets.map(\.targetReps).filter { $0 > 0 }.max() ?? 1) }
    private static func trainingDay(for date: Date) -> TrainingDay {
        let weekday = Calendar(identifier: .gregorian).component(.weekday, from: date)
        return [.sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday][weekday - 1]
    }
}
