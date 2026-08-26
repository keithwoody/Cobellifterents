import Foundation
import SwiftData

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
    case strongLiftsRequiresTrainingDays
    case strongLiftsAlternation
    case atgRequiresThreeToFiveDays
}

struct Program: Codable, Equatable, Identifiable {
    let id: UUID
    var kind: ProgramKind
    var name: String
    var workouts: [ProgramWorkout]
    var trainingDays: [TrainingDay]
    /// Weekdays explicitly marked as recovery days. This is separate from workout assignments so it can be persisted and shown in the calendar.
    var restDays: [TrainingDay]
    var generatedSourceKey: String?

    init(id: UUID = UUID(), kind: ProgramKind, name: String, workouts: [ProgramWorkout], trainingDays: [TrainingDay] = [], restDays: [TrainingDay] = [], generatedSourceKey: String? = nil) {
        self.id = id; self.kind = kind; self.name = name; self.workouts = workouts
        self.trainingDays = (trainingDays.isEmpty && kind == .strongLifts ? [.monday, .wednesday, .friday] : trainingDays).sorted()
        self.restDays = restDays.sorted()
        self.generatedSourceKey = generatedSourceKey
    }

    private enum CodingKeys: String, CodingKey { case id, kind, name, workouts, trainingDays, restDays, generatedSourceKey }
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(ProgramKind.self, forKey: .kind)
        let workouts = try container.decode([ProgramWorkout].self, forKey: .workouts)
        let days = try container.decodeIfPresent([TrainingDay].self, forKey: .trainingDays)
            ?? Array(Set(workouts.flatMap(\.assignedDays))).sorted()
        self.init(id: try container.decode(UUID.self, forKey: .id), kind: kind,
                  name: try container.decode(String.self, forKey: .name), workouts: workouts,
                  trainingDays: days,
                  restDays: try container.decodeIfPresent([TrainingDay].self, forKey: .restDays) ?? [],
                  generatedSourceKey: try container.decodeIfPresent(String.self, forKey: .generatedSourceKey))
    }

    var selectedTrainingDays: [TrainingDay] {
        kind == .strongLifts ? trainingDays.sorted() : Array(Set(workouts.flatMap(\.assignedDays))).sorted()
    }

    var scheduledTrainingDays: [TrainingDay] {
        selectedTrainingDays.filter { !restDays.contains($0) }
    }

    mutating func toggleRestDay(_ day: TrainingDay) {
        if restDays.contains(day) {
            restDays.removeAll { $0 == day }
        } else {
            restDays.append(day)
            if kind == .strongLifts {
                trainingDays.removeAll { $0 == day }
            } else {
                for index in workouts.indices { workouts[index].assignedDays.removeAll { $0 == day } }
            }
        }
        restDays.sort()
        trainingDays.sort()
    }
    var validationError: ProgramValidationError? {
        switch kind {
        case .atg:
            return (3...5).contains(selectedTrainingDays.count) ? nil : .atgRequiresThreeToFiveDays
        case .strongLifts:
            guard workouts.count == 2, workouts.contains(where: \.isStrongLiftsA), workouts.contains(where: \.isStrongLiftsB) else { return .strongLiftsRequiresAB }
            guard !scheduledTrainingDays.isEmpty else { return .strongLiftsRequiresTrainingDays }
            return nil
        }
    }
    var isValid: Bool { validationError == nil }
    var isBuiltIn: Bool { id == Self.strongLiftsDefaultID || id == Self.atgDefaultID }

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
        let templateID: TemplateID
        if let identity = workout.identity, let strongLiftsID = TemplateID(rawValue: "strongLifts\(identity)") {
            templateID = strongLiftsID
        } else if workout.identity == nil {
            templateID = .atgImported
        } else {
            return nil
        }
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
                           trainingDays: program.trainingDays, restDays: program.restDays, generatedSourceKey: program.generatedSourceKey)
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

struct UpcomingScheduleEntry: Equatable, Identifiable {
    enum Kind: Equatable { case workout, rest, restDay }

    let date: Date
    let kind: Kind
    let workoutNames: [String]
    let workout: ProgramWorkout?

    init(date: Date, kind: Kind, workoutNames: [String], workout: ProgramWorkout? = nil) {
        self.date = date
        self.kind = kind
        self.workoutNames = workoutNames
        self.workout = workout
    }

    var id: Date { date }
    var title: String { kind == .rest || kind == .restDay ? "Rest Day" : (workout?.name ?? workoutNames.first ?? "Workout") }
}

struct UpcomingStartableWorkout {
    let date: Date
    let workout: ProgramWorkout
    let template: WorkoutTemplate
}

enum UpcomingSchedule {
    /// Returns the next three calendar days, starting today, for the active programs.
    /// A day without a scheduled workout is retained as an explicit rest entry.
    static func entries(
        from date: Date = Date(),
        calendar: Calendar = .current,
        strongLifts: Program?,
        atg: Program?,
        completedSessions: [WorkoutSession] = []
    ) -> [UpcomingScheduleEntry] {
        let start = calendar.startOfDay(for: date)
        let strongProgram = strongLifts?.kind == .strongLifts ? strongLifts : nil
        let atgProgram = atg?.kind == .atg ? atg : nil
        guard strongProgram != nil || atgProgram != nil else { return [] }

        var nextStrongIdentity = strongProgram.flatMap { program in
            StrongLiftsProgramSelection.nextWorkout(in: program, after: completedSessions)?.identity
        }
        return (0..<3).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            let weekday = calendar.component(.weekday, from: day)
            let trainingDay = TrainingDay.from(calendarWeekday: weekday)
            var names: [String] = []

            if let strongProgram, strongProgram.trainingDays.contains(trainingDay),
               let identity = nextStrongIdentity,
               let workout = strongProgram.workouts.first(where: { $0.identity == identity }) {
                names.append(WorkoutDisplayNaming.combined(programName: strongProgram.name, workoutName: workout.name))
                nextStrongIdentity = identity == "A" ? "B" : "A"
            }
            if let atgProgram {
                names.append(contentsOf: atgProgram.workouts.filter { $0.assignedDays.contains(trainingDay) }.map {
                    WorkoutDisplayNaming.combined(programName: atgProgram.name, workoutName: $0.name)
                })
            }
            return UpcomingScheduleEntry(date: day, kind: names.isEmpty ? .rest : .workout, workoutNames: names)
        }
    }

    static func entries(for program: Program, from startDate: Date = Date(), limit: Int = 3, calendar: Calendar = .current) -> [UpcomingScheduleEntry] {
        guard limit > 0, program.isValid, !program.scheduledTrainingDays.isEmpty else { return [] }
        var date = calendar.startOfDay(for: startDate)
        var result: [UpcomingScheduleEntry] = []
        var occurrence = 0
        while result.count < limit {
            let day = TrainingDay.from(calendarWeekday: calendar.component(.weekday, from: date))
            if program.restDays.contains(day) {
                result.append(UpcomingScheduleEntry(date: date, kind: .restDay, workoutNames: []))
            } else if program.scheduledTrainingDays.contains(day), let workout = program.kind == .strongLifts ? program.workouts.first(where: { $0.identity == (occurrence.isMultiple(of: 2) ? "A" : "B") }) : program.workouts.first(where: { $0.assignedDays.contains(day) }) {
                result.append(UpcomingScheduleEntry(date: date, kind: .workout, workoutNames: [workout.name], workout: workout))
                occurrence += 1
            }
            date = calendar.date(byAdding: .day, value: 1, to: date) ?? date.addingTimeInterval(86_400)
        }
        return result
    }

    /// Selects the first scheduled workout with exercises, skipping rest days and
    /// scheduled-but-empty workouts. This is the source of truth for the home
    /// start card as well as the upcoming schedule display.
    static func nextStartableWorkout(
        from date: Date = Date(),
        calendar: Calendar = .current,
        strongLifts: Program?,
        atg: Program?,
        completedSessions: [WorkoutSession] = []
    ) -> UpcomingStartableWorkout? {
        let strongProgram = strongLifts?.kind == .strongLifts && strongLifts?.isValid == true ? strongLifts : nil
        let atgProgram = atg?.kind == .atg && atg?.isValid == true ? atg : nil
        guard strongProgram != nil || atgProgram != nil else { return nil }

        var nextStrongIdentity = strongProgram.flatMap {
            StrongLiftsProgramSelection.nextWorkout(in: $0, after: completedSessions)?.identity
        }
        let start = calendar.startOfDay(for: date)

        // One full week is sufficient for the weekly schedules supported by the app.
        for offset in 0..<7 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: start) else { continue }
            let trainingDay = TrainingDay.from(calendarWeekday: calendar.component(.weekday, from: day))
            var scheduled: [(ProgramWorkout, String?)] = []

            if let strongProgram, strongProgram.trainingDays.contains(trainingDay),
               let identity = nextStrongIdentity,
               let workout = strongProgram.workouts.first(where: { $0.identity == identity }) {
                scheduled.append((workout, strongProgram.name))
                nextStrongIdentity = identity == "A" ? "B" : "A"
            }
            if let atgProgram {
                scheduled.append(contentsOf: atgProgram.workouts.filter { $0.assignedDays.contains(trainingDay) }.map { ($0, atgProgram.name) })
            }

            for (workout, programName) in scheduled {
                guard let template = ProgramWorkoutConversion.template(from: workout, programName: programName),
                      !template.exercises.isEmpty else { continue }
                return UpcomingStartableWorkout(date: day, workout: workout, template: template)
            }
        }
        return nil
    }
}

private extension TrainingDay {
    static func from(calendarWeekday: Int) -> TrainingDay {
        switch calendarWeekday {
        case 1: return .sunday
        case 2: return .monday
        case 3: return .tuesday
        case 4: return .wednesday
        case 5: return .thursday
        case 6: return .friday
        default: return .saturday
        }
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

enum ProgramDeletionError: Equatable, Error {
    case protectedProgram
}

extension ProgramDeletionError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .protectedProgram: return "Built-in Programs cannot be deleted."
        }
    }
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
    func delete(_ program: Program, sessions: [WorkoutSession], in context: ModelContext, saveContext: (() throws -> Void)? = nil) throws -> [Program] {
        guard !program.isBuiltIn else { throw ProgramDeletionError.protectedProgram }
        let assignedSessions = sessions.filter { $0.programAssignmentID == program.id }
        let previousAssignments = assignedSessions.map {
            ($0, $0.programAssignmentID, $0.programAssignmentRawValue, $0.programAssignmentEvidence)
        }
        for session in assignedSessions {
            session.programAssignmentID = nil
            session.programAssignmentRawValue = nil
            session.programAssignmentEvidence = nil
        }
        do {
            if !assignedSessions.isEmpty {
                if let saveContext { try saveContext() } else { try context.save() }
            }
        } catch {
            context.rollback()
            for (session, id, rawValue, evidence) in previousAssignments {
                session.programAssignmentID = id
                session.programAssignmentRawValue = rawValue
                session.programAssignmentEvidence = evidence
            }
            throw error
        }

        let remaining = load().filter { $0.id != program.id }
        let programs = remaining.isEmpty ? Program.defaults : remaining
        save(programs)

        var selection = loadActiveSelection()
        if selection.id(for: program.kind) == program.id {
            switch program.kind {
            case .strongLifts: selection.strongLiftsID = nil
            case .atg: selection.atgID = nil
            }
            saveActiveSelection(selection)
        }
        return programs
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
            // Generated content can be refreshed on every import, but the name is
            // user-owned once the Program has been created. Do not make an import
            // idempotency pass silently undo an explicit rename.
            let existingName = programs[index].name.trimmingCharacters(in: .whitespacesAndNewlines)
            let name = existingName.isEmpty ? program.name : programs[index].name
            programs[index] = Program(id: existingID, kind: program.kind, name: name, workouts: program.workouts, trainingDays: program.trainingDays, restDays: program.restDays, generatedSourceKey: sourceKey)
            save(programs)
            return (programs, false)
        }
        programs.append(program)
        save(programs)
        return (programs, true)
    }
}


