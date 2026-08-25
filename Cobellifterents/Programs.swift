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
    var trainingDays: [TrainingDay]
    var generatedSourceKey: String?

    init(id: UUID = UUID(), kind: ProgramKind, name: String, workouts: [ProgramWorkout], trainingDays: [TrainingDay] = [], generatedSourceKey: String? = nil) {
        self.id = id; self.kind = kind; self.name = name; self.workouts = workouts
        self.trainingDays = (trainingDays.isEmpty && kind == .strongLifts ? [.monday, .wednesday, .friday] : trainingDays).sorted()
        self.generatedSourceKey = generatedSourceKey
    }

    private enum CodingKeys: String, CodingKey { case id, kind, name, workouts, trainingDays, generatedSourceKey }
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(ProgramKind.self, forKey: .kind)
        let workouts = try container.decode([ProgramWorkout].self, forKey: .workouts)
        let days = try container.decodeIfPresent([TrainingDay].self, forKey: .trainingDays)
            ?? Array(Set(workouts.flatMap(\.assignedDays))).sorted()
        self.init(id: try container.decode(UUID.self, forKey: .id), kind: kind,
                  name: try container.decode(String.self, forKey: .name), workouts: workouts,
                  trainingDays: days,
                  generatedSourceKey: try container.decodeIfPresent(String.self, forKey: .generatedSourceKey))
    }

    var selectedTrainingDays: [TrainingDay] {
        kind == .strongLifts ? trainingDays.sorted() : Array(Set(workouts.flatMap(\.assignedDays))).sorted()
    }
    var validationError: ProgramValidationError? {
        switch kind {
        case .atg:
            return (3...5).contains(selectedTrainingDays.count) ? nil : .atgRequiresThreeToFiveDays
        case .strongLifts:
            guard workouts.count == 2, workouts.contains(where: \.isStrongLiftsA), workouts.contains(where: \.isStrongLiftsB) else { return .strongLiftsRequiresAB }
            return nil
        }
    }
    var isValid: Bool { validationError == nil }

    static func new(kind: ProgramKind, name: String) -> Program {
        let source = kind == .strongLifts ? strongLiftsDefault : atgDefault
        let workouts = source.workouts.map { workout in
            ProgramWorkout(identity: workout.identity, name: workout.name, exercises: workout.exercises.map { ProgramExercise(name: $0.name, targetSets: $0.targetSets, targetReps: $0.targetReps) }, assignedDays: workout.assignedDays)
        }
        return Program(kind: kind, name: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? kind.displayName : name, workouts: workouts, trainingDays: source.trainingDays)
    }

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

    // These IDs are part of the persisted assignment contract. Defaults are
    // returned when no programs have been saved yet, so UUID() here would
    // make an assignment point at a different Program after relaunch.
    private static let strongLiftsDefaultID = UUID(uuidString: "7D7D8F1A-1BD2-4B0D-9F2E-7C6F4D2E1A01")!
    private static let atgDefaultID = UUID(uuidString: "7D7D8F1A-1BD2-4B0D-9F2E-7C6F4D2E1A02")!

    static let strongLiftsDefault: Program = {
        func exercise(_ name: String, _ sets: Int = 5, _ reps: Int = 5) -> ProgramExercise { ProgramExercise(name: name, targetSets: sets, targetReps: reps) }
        return Program(id: strongLiftsDefaultID, kind: .strongLifts, name: "StrongLifts 5×5", workouts: [
            ProgramWorkout(identity: "A", name: "Workout A", exercises: [exercise("Squat"), exercise("Bench Press"), exercise("Barbell Row")]),
            ProgramWorkout(identity: "B", name: "Workout B", exercises: [exercise("Squat"), exercise("Overhead Press"), exercise("Deadlift", 1)])
        ])
    }()

    /// A modest strength-and-mobility-inspired starting template; this is not full ATG mobility logging.
    static let atgDefault: Program = Program(id: atgDefaultID, kind: .atg, name: "ATG Basics (modest starter)", workouts: [
        ProgramWorkout(name: "ATG Training", exercises: [
            ProgramExercise(name: "Split Squat", targetSets: 2, targetReps: 5),
            ProgramExercise(name: "Tibialis Raise", targetSets: 2, targetReps: 10),
            ProgramExercise(name: "Calf Raise", targetSets: 2, targetReps: 10)
        ], assignedDays: [.monday, .wednesday, .friday])
    ])

    static var defaults: [Program] { [strongLiftsDefault, atgDefault] }
}

enum StrongLiftsScheduling {
    static func nextWorkoutIdentity(after lastCompletedIdentity: String?) -> String {
        lastCompletedIdentity == "A" ? "B" : "A"
    }
}

enum StrongLiftsProgramSelection {
    static func nextWorkout(in program: Program, after sessions: [WorkoutSession]) -> ProgramWorkout? {
        guard program.kind == .strongLifts, program.isValid else { return nil }
        let lastIdentity = sessions.first(where: { $0.isComplete })?.templateID.flatMap { id in
            id == .strongLiftsA ? "A" : (id == .strongLiftsB ? "B" : nil)
        }
        let identity = StrongLiftsScheduling.nextWorkoutIdentity(after: lastIdentity)
        return program.workouts.first(where: { $0.identity == identity })
    }
}

enum ProgramWorkoutConversion {
    static func template(from workout: ProgramWorkout) -> WorkoutTemplate? {
        template(from: workout, programName: nil)
    }

    static func template(from workout: ProgramWorkout, programName: String?) -> WorkoutTemplate? {
        guard let identity = workout.identity, let templateID = TemplateID(rawValue: "strongLifts\(identity)") else { return nil }
        let displayName = programName.map { WorkoutDisplayNaming.combined(programName: $0, workoutName: workout.name) } ?? workout.name
        return WorkoutTemplate(id: templateID, name: displayName, exercises: workout.exercises.map { exercise in
            ExerciseTemplate(id: exercise.id.uuidString, name: exercise.name, targetSets: exercise.targetSets, targetReps: exercise.targetReps,
                             startingWeight: defaultStartingWeight(for: exercise), increment: defaultIncrement(for: exercise))
        })
    }

    private static func defaultStartingWeight(for exercise: ProgramExercise) -> Double {
        ExerciseProgressionSetting.defaults.first { $0.name.caseInsensitiveCompare(exercise.name) == .orderedSame }?.currentWeight ?? 45
    }

    private static func defaultIncrement(for exercise: ProgramExercise) -> Double {
        ExerciseProgressionSetting.defaults.first { $0.name.caseInsensitiveCompare(exercise.name) == .orderedSame }?.increment ?? 5
    }
}

enum HomeWorkoutLogic {
    static func shouldDisableStart(selectedProgramWorkout: ProgramWorkout?, template: WorkoutTemplate) -> Bool {
        selectedProgramWorkout != nil && template.exercises.isEmpty
    }
}

struct ProgramsEnvelope: Codable, Equatable { var version: Int; var programs: [Program] }

enum ProgramNormalization {
    /// Repairs the fixed StrongLifts shape without replacing any persisted workout data.
    static func normalized(_ program: Program) -> Program {
        guard program.kind == .strongLifts else { return program }

        let workoutA = program.workouts.first(where: \.isStrongLiftsA)
        let workoutB = program.workouts.first(where: \.isStrongLiftsB)
        let existingWorkouts = [workoutA, workoutB].compactMap { $0 }
        guard workoutA != nil, workoutB != nil, program.workouts == existingWorkouts else {
            let repairedWorkouts = [
                workoutA ?? ProgramWorkout(identity: "A", name: "Workout A", exercises: [], assignedDays: []),
                workoutB ?? ProgramWorkout(identity: "B", name: "Workout B", exercises: [], assignedDays: [])
            ]
            return Program(id: program.id, kind: program.kind, name: program.name, workouts: repairedWorkouts,
                           trainingDays: program.trainingDays, generatedSourceKey: program.generatedSourceKey)
        }
        return program
    }

    static func normalized(_ programs: [Program]) -> [Program] {
        programs.map { normalized($0) }
    }
}

/// Independent active selections, persisted separately so existing programs.v1 data remains backward compatible.
struct ActiveProgramSelection: Codable, Equatable {
    var strongLiftsID: UUID?
    var atgID: UUID?

    init(strongLiftsID: UUID? = nil, atgID: UUID? = nil) {
        self.strongLiftsID = strongLiftsID; self.atgID = atgID
    }
    private enum CodingKeys: String, CodingKey { case strongLiftsID, atgID }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        strongLiftsID = try c.decodeIfPresent(UUID.self, forKey: .strongLiftsID)
        atgID = try c.decodeIfPresent(UUID.self, forKey: .atgID)
    }
    func id(for kind: ProgramKind) -> UUID? { kind == .strongLifts ? strongLiftsID : atgID }
}

enum ActiveProgramSelectionLogic {
    /// Activating replaces the program of the same kind; activating it again deactivates it.
    static func toggled(_ selection: ActiveProgramSelection, for program: Program) -> ActiveProgramSelection {
        var result = selection
        let newID = selection.id(for: program.kind) == program.id ? nil : program.id
        switch program.kind {
        case .strongLifts: result.strongLiftsID = newID
        case .atg: result.atgID = newID
        }
        return result
    }

    static func normalized(_ selection: ActiveProgramSelection, for programs: [Program]) -> ActiveProgramSelection {
        let strongIDs = Set(programs.filter { $0.kind == .strongLifts && $0.isValid }.map(\.id))
        let atgIDs = Set(programs.filter { $0.kind == .atg && $0.isValid }.map(\.id))
        return ActiveProgramSelection(
            strongLiftsID: selection.strongLiftsID.flatMap { strongIDs.contains($0) ? $0 : nil },
            atgID: selection.atgID.flatMap { atgIDs.contains($0) ? $0 : nil })
    }
}

enum ProgramScheduleConflict {
    static func overlappingDays(strongLifts: Program, atg: Program) -> [TrainingDay] {
        guard strongLifts.kind == .strongLifts, atg.kind == .atg else { return [] }
        return Array(Set(strongLifts.selectedTrainingDays).intersection(atg.selectedTrainingDays)).sorted()
    }
    static func hasConflict(strongLifts: Program, atg: Program) -> Bool {
        !overlappingDays(strongLifts: strongLifts, atg: atg).isEmpty
    }
}

struct ActiveProgramsEnvelope: Codable, Equatable {
    var version: Int
    var selection: ActiveProgramSelection
}

final class ProgramsRepository {
    private let defaults: UserDefaults
    private let key = "programs.v1"
    private let activeSelectionKey = "programs.active.v1"
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    func load() -> [Program] {
        guard let data = defaults.data(forKey: key), let envelope = try? JSONDecoder().decode(ProgramsEnvelope.self, from: data), envelope.version == 1, !envelope.programs.isEmpty else { return Program.defaults }
        let normalizedPrograms = ProgramNormalization.normalized(envelope.programs)
        if normalizedPrograms != envelope.programs { save(normalizedPrograms) }
        return normalizedPrograms
    }
    func save(_ programs: [Program]) {
        guard let data = try? JSONEncoder().encode(ProgramsEnvelope(version: 1, programs: programs)) else { return }
        defaults.set(data, forKey: key)
    }

    func loadActiveSelection() -> ActiveProgramSelection {
        guard let data = defaults.data(forKey: activeSelectionKey),
              let envelope = try? JSONDecoder().decode(ActiveProgramsEnvelope.self, from: data),
              envelope.version == 1 else { return ActiveProgramSelection() }
        return envelope.selection
    }

    func loadActiveSelection(for programs: [Program]) -> ActiveProgramSelection {
        ActiveProgramSelectionLogic.normalized(loadActiveSelection(), for: programs)
    }

    func saveActiveSelection(_ selection: ActiveProgramSelection) {
        guard let data = try? JSONEncoder().encode(ActiveProgramsEnvelope(version: 1, selection: selection)) else { return }
        defaults.set(data, forKey: activeSelectionKey)
    }

    @discardableResult
    func toggleActive(_ program: Program) -> ActiveProgramSelection {
        let selection = ActiveProgramSelectionLogic.toggled(loadActiveSelection(), for: program)
        saveActiveSelection(selection)
        return selection
    }

    @discardableResult
    func upsertGenerated(_ program: Program) -> (programs: [Program], inserted: Bool) {
        var programs = load()
        guard let sourceKey = program.generatedSourceKey else { return (programs, false) }
        if let index = programs.firstIndex(where: { $0.generatedSourceKey == sourceKey }) {
            let existingID = programs[index].id
            programs[index] = Program(id: existingID, kind: program.kind, name: program.name, workouts: program.workouts, trainingDays: program.trainingDays, generatedSourceKey: sourceKey)
            save(programs)
            return (programs, false)
        }
        programs.append(program)
        save(programs)
        return (programs, true)
    }
}
