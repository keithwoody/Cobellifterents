import Foundation

enum ProgramKind: String, Codable, CaseIterable, Identifiable {
    case strongLifts
    case atg

    var id: String { rawValue }
    var displayName: String { rawValue == "strongLifts" ? "StrongLifts" : "ATG" }
}

enum TrainingDay: String, Codable, CaseIterable, Identifiable, Comparable {
    case monday, tuesday, wednesday, thursday, friday, saturday, sunday
    var id: String { rawValue }
    var shortName: String { String(rawValue.prefix(3)).capitalized }
    private var sortIndex: Int { Self.allCases.firstIndex(of: self)! }
    static func < (lhs: TrainingDay, rhs: TrainingDay) -> Bool { lhs.sortIndex < rhs.sortIndex }
}

struct ProgramExercise: Codable, Equatable, Identifiable {
    let id: UUID
    var name: String
    var targetSets: Int
    var targetReps: Int

    init(id: UUID = UUID(), name: String, targetSets: Int = 3, targetReps: Int = 5) {
        self.id = id; self.name = name; self.targetSets = max(1, targetSets); self.targetReps = max(1, targetReps)
    }
}

struct ProgramWorkout: Codable, Equatable, Identifiable {
    let id: UUID
    var identity: String?
    var name: String
    var exercises: [ProgramExercise]
    var assignedDays: [TrainingDay]

    init(id: UUID = UUID(), identity: String? = nil, name: String, exercises: [ProgramExercise], assignedDays: [TrainingDay] = []) {
        self.id = id; self.identity = identity; self.name = name; self.exercises = exercises; self.assignedDays = assignedDays.sorted()
    }
    var isStrongLiftsA: Bool { identity == "A" }
    var isStrongLiftsB: Bool { identity == "B" }
}

enum ProgramValidationError: Equatable, Error {
    case strongLiftsRequiresAB
    case strongLiftsAlternation
    case atgRequiresThreeToFiveDays
}

struct Program: Codable, Equatable, Identifiable {
    let id: UUID
    var kind: ProgramKind
    var name: String
    var workouts: [ProgramWorkout]

    init(id: UUID = UUID(), kind: ProgramKind, name: String, workouts: [ProgramWorkout]) {
        self.id = id; self.kind = kind; self.name = name; self.workouts = workouts
    }

    var selectedTrainingDays: [TrainingDay] { Array(Set(workouts.flatMap(\.assignedDays))).sorted() }
    var validationError: ProgramValidationError? {
        switch kind {
        case .atg:
            return (3...5).contains(selectedTrainingDays.count) ? nil : .atgRequiresThreeToFiveDays
        case .strongLifts:
            guard workouts.count == 2, workouts.contains(where: \.isStrongLiftsA), workouts.contains(where: \.isStrongLiftsB) else { return .strongLiftsRequiresAB }
            let ordered = workouts.flatMap { workout in workout.assignedDays.map { ($0, workout.identity) } }.sorted { $0.0 < $1.0 }
            guard ordered.count > 1 else { return nil }
            for pair in zip(ordered, ordered.dropFirst()) where pair.0.0 == pair.1.0 || pair.0.1 == pair.1.1 { return .strongLiftsAlternation }
            return nil
        }
    }
    var isValid: Bool { validationError == nil }

    mutating func addWorkout() {
        guard kind == .atg else { return }
        workouts.append(ProgramWorkout(name: "Workout \(workouts.count + 1)", exercises: [ProgramExercise(name: "New Exercise")]))
    }
    mutating func removeWorkout(at offsets: IndexSet) {
        guard kind == .atg else { return }
        for index in offsets.sorted(by: >) where workouts.indices.contains(index) { workouts.remove(at: index) }
    }
    mutating func addExercise(to workoutIndex: Int) {
        guard workouts.indices.contains(workoutIndex) else { return }
        workouts[workoutIndex].exercises.append(ProgramExercise(name: "New Exercise"))
    }
    mutating func removeExercise(workoutIndex: Int, at offsets: IndexSet) {
        guard workouts.indices.contains(workoutIndex) else { return }
        for index in offsets.sorted(by: >) where workouts[workoutIndex].exercises.indices.contains(index) { workouts[workoutIndex].exercises.remove(at: index) }
    }

    static let strongLiftsDefault: Program = {
        func exercise(_ name: String, _ sets: Int = 5, _ reps: Int = 5) -> ProgramExercise { ProgramExercise(name: name, targetSets: sets, targetReps: reps) }
        return Program(kind: .strongLifts, name: "StrongLifts 5×5", workouts: [
            ProgramWorkout(identity: "A", name: "Workout A", exercises: [exercise("Squat"), exercise("Bench Press"), exercise("Barbell Row")], assignedDays: [.monday, .friday]),
            ProgramWorkout(identity: "B", name: "Workout B", exercises: [exercise("Squat"), exercise("Overhead Press"), exercise("Deadlift", 1)], assignedDays: [.wednesday])
        ])
    }()

    /// A modest strength-and-mobility-inspired starting template; this is not full ATG mobility logging.
    static let atgDefault: Program = Program(kind: .atg, name: "ATG Basics (modest starter)", workouts: [
        ProgramWorkout(name: "ATG Training", exercises: [
            ProgramExercise(name: "Split Squat", targetSets: 2, targetReps: 5),
            ProgramExercise(name: "Tibialis Raise", targetSets: 2, targetReps: 10),
            ProgramExercise(name: "Calf Raise", targetSets: 2, targetReps: 10)
        ], assignedDays: [.monday, .wednesday, .friday])
    ])

    static var defaults: [Program] { [strongLiftsDefault, atgDefault] }
}

struct ProgramsEnvelope: Codable, Equatable { var version: Int; var programs: [Program] }

final class ProgramsRepository {
    private let defaults: UserDefaults
    private let key = "programs.v1"
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    func load() -> [Program] {
        guard let data = defaults.data(forKey: key), let envelope = try? JSONDecoder().decode(ProgramsEnvelope.self, from: data), envelope.version == 1, !envelope.programs.isEmpty else { return Program.defaults }
        return envelope.programs
    }
    func save(_ programs: [Program]) {
        guard let data = try? JSONEncoder().encode(ProgramsEnvelope(version: 1, programs: programs)) else { return }
        defaults.set(data, forKey: key)
    }
}
