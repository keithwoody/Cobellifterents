import Foundation

struct InferredProgram {
    let program: Program
    let needsScheduleEditing: Bool
}

enum ATGProgramPlanner {
    static func assignPrograms(to drafts: [WorkoutSessionDraft]) -> [WorkoutSessionDraft] {
        guard let latest = drafts.map(\.startedAt).max() else { return drafts }
        let recentStart = Calendar.current.date(byAdding: .day, value: -6, to: latest) ?? latest
        let ordered = drafts.sorted { $0.startedAt < $1.startedAt }
        var signatures: [Int: String] = [:]
        var changed = false
        return ordered.map { draft in
            let weekday = Calendar(identifier: .gregorian).component(.weekday, from: draft.startedAt)
            let signature = draft.sets.map(\.exerciseName).joined(separator: "|")
            if let previous = signatures[weekday], previous != signature { changed = true }
            signatures[weekday] = signature
            let assignment: ImportProgramAssignment = draft.startedAt >= recentStart ? .backAbilityZero : (changed ? .ankleAbilityZero : .kneeAbilityZero)
            return WorkoutSessionDraft(sourceKind: draft.sourceKind, sourceFileName: draft.sourceFileName, sourceRecordID: draft.sourceRecordID, templateName: draft.templateName, startedAt: draft.startedAt, completedAt: draft.completedAt, bodyWeight: draft.bodyWeight, notes: draft.notes, sets: draft.sets, programAssignment: assignment, programAssignmentEvidence: "Derived from dated exercise history; latest seven days assigned to Back Ability Zero")
        }
    }

    static func placeholderPrograms(from drafts: [WorkoutSessionDraft]) -> [Program] {
        [ImportProgramAssignment.kneeAbilityZero, .ankleAbilityZero, .backAbilityZero].map { assignment in
            let matching = drafts.filter { $0.programAssignment == assignment }
            let names = matching.flatMap { $0.sets.map(\.exerciseName) }.reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }
            let days = Array(Set(matching.map { weekday(for: $0.startedAt) })).sorted()
            let exercises = names.map { name in ProgramExercise(name: name, targetSets: 1, targetReps: max(1, matching.flatMap { $0.sets.filter { $0.exerciseName == name }.map(\.targetReps) }.max() ?? 1)) }
            return Program(kind: .atg, name: assignment.displayName, workouts: [ProgramWorkout(name: assignment.displayName, exercises: exercises, assignedDays: days)], trainingDays: days, generatedSourceKey: "atg-placeholder:\(assignment.rawValue):\(matching.first?.sourceFileName.lowercased() ?? "import")")
        }
    }

    private static func weekday(for date: Date) -> TrainingDay {
        let value = Calendar(identifier: .gregorian).component(.weekday, from: date)
        return [.sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday][value - 1]
    }
}

/// Pure conversion of imported native sessions into an editable Program.
enum ImportToProgramInference {
    static func infer(from drafts: [WorkoutSessionDraft], sourceKind: ImportSourceKind? = nil) -> InferredProgram? {
        guard !drafts.isEmpty else { return nil }
        let kind = sourceKind ?? drafts[0].sourceKind
        let isStrongLifts = kind == .strongLiftsCSV || drafts.contains { strongIdentity($0.templateName) != nil }
        let programKind: ProgramKind = isStrongLifts ? .strongLifts : .atg
        let name = displayName(fileName: drafts[0].sourceFileName, kind: kind, drafts: drafts)
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

    static func displayName(fileName: String, kind: ImportSourceKind, drafts: [WorkoutSessionDraft] = []) -> String {
        let base = (fileName as NSString).deletingPathExtension.trimmingCharacters(in: .whitespacesAndNewlines)
        let importedName = base.isEmpty ? "Imported \(kind == .strongLiftsCSV ? "StrongLifts" : "ATG") Program" : "Imported \(base)"
        guard kind == .atgCSV else { return importedName }
        let assignments = Set(drafts.map(\.programAssignment))
        if assignments.count == 1, let assignment = assignments.first, assignment != .unassignedAmbiguous {
            return assignment.displayName
        }
        return "\(importedName) (Program assignment needed)"
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
