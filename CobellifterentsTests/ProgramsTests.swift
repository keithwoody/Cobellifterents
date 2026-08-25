import XCTest
@testable import Cobellifterents

final class ProgramsTests: XCTestCase {
    func testDefaultsHaveStrongLiftsABAndModestATG() {
        XCTAssertEqual(Program.defaults.map(\.kind), [.strongLifts, .atg])
        XCTAssertEqual(Program.strongLiftsDefault.workouts.map(\.identity), ["A", "B"])
        XCTAssertEqual(Program.strongLiftsDefault.trainingDays, [.monday, .wednesday, .friday])
        XCTAssertTrue(Program.strongLiftsDefault.workouts.allSatisfy { $0.assignedDays.isEmpty })
        XCTAssertTrue(Program.atgDefault.isValid)
        XCTAssertLessThanOrEqual(Program.atgDefault.workouts.flatMap(\.exercises).count, 5)
    }

    func testProgramCodableRoundTripPreservesExerciseOrder() throws {
        let original = Program.atgDefault
        let data = try JSONEncoder().encode(original)
        XCTAssertEqual(try JSONDecoder().decode(Program.self, from: data), original)
        XCTAssertEqual(original.workouts[0].exercises.map(\.name), ["Split Squat", "Tibialis Raise", "Calf Raise"])
    }

    func testRepositoryFallsBackAndPersistsVersionedPrograms() {
        let suite = "ProgramsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let repository = ProgramsRepository(defaults: defaults)
        XCTAssertEqual(repository.load(), Program.defaults)
        var saved = repository.load()
        saved[0].name = "My StrongLifts"
        repository.save(saved)
        XCTAssertEqual(repository.load().first?.name, "My StrongLifts")
        defaults.set(Data("bad".utf8), forKey: "programs.v1")
        XCTAssertEqual(repository.load(), Program.defaults)
    }

    func testRepositoryPersistsNewStrongLiftsExerciseAcrossSaveAndReload() {
        let suite = "ProgramsEditorPersistenceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let repository = ProgramsRepository(defaults: defaults)
        var edited = Program.strongLiftsDefault
        edited.addExercise(to: 0)
        edited.workouts[0].exercises[3].name = "Pull-Up"
        let selection = ActiveProgramSelection(strongLiftsID: edited.id)

        repository.save([edited])
        repository.saveActiveSelection(selection)

        let reloaded = try! XCTUnwrap(repository.load().first)
        XCTAssertEqual(reloaded.workouts[0].exercises.map(\.name), ["Squat", "Bench Press", "Barbell Row", "Pull-Up"])
        XCTAssertEqual(repository.loadActiveSelection(for: [reloaded]).strongLiftsID, edited.id)
    }

    func testStrongLiftsNormalizationRepairsOneSidedProgramAndPreservesExistingWorkout() {
        let existing = ProgramWorkout(id: UUID(), identity: "A", name: "My A",
                                      exercises: [ProgramExercise(name: "Custom Lift", targetSets: 4, targetReps: 6)],
                                      assignedDays: [.tuesday])
        let program = Program(id: UUID(), kind: .strongLifts, name: "Legacy", workouts: [existing],
                              trainingDays: [.monday, .wednesday, .friday], generatedSourceKey: "legacy")

        let normalized = ProgramNormalization.normalized(program)

        XCTAssertEqual(normalized.workouts.map(\.identity), ["A", "B"])
        XCTAssertEqual(normalized.workouts[0], existing)
        XCTAssertEqual(normalized.workouts[1].name, "Workout B")
        XCTAssertTrue(normalized.workouts[1].exercises.isEmpty)
        XCTAssertTrue(normalized.workouts[1].assignedDays.isEmpty)
        XCTAssertNotEqual(normalized.workouts[1].id, existing.id)
        XCTAssertEqual(normalized.id, program.id)
        XCTAssertEqual(normalized.name, program.name)
        XCTAssertEqual(normalized.trainingDays, program.trainingDays)
        XCTAssertEqual(normalized.generatedSourceKey, program.generatedSourceKey)
    }

    func testRepositoryRepairsAndPersistsOneSidedStrongLiftsProgram() throws {
        let suite = "ProgramsRepairTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let repository = ProgramsRepository(defaults: defaults)
        let existing = ProgramWorkout(identity: "B", name: "Saved B",
                                      exercises: [ProgramExercise(name: "Deadlift")], assignedDays: [.friday])
        let legacy = Program(id: UUID(), kind: .strongLifts, name: "Saved Legacy", workouts: [existing])
        repository.save([legacy])

        let loaded = repository.load()

        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].workouts.map(\.identity), ["A", "B"])
        XCTAssertEqual(loaded[0].workouts[1], existing)
        XCTAssertEqual(loaded[0].workouts[0].name, "Workout A")
        XCTAssertTrue(loaded[0].workouts[0].exercises.isEmpty)
        XCTAssertTrue(loaded[0].workouts[0].assignedDays.isEmpty)
        let persisted = try XCTUnwrap(defaults.data(forKey: "programs.v1"))
        let envelope = try JSONDecoder().decode(ProgramsEnvelope.self, from: persisted)
        XCTAssertEqual(envelope.programs, loaded)
    }

    func testScheduleValidationForStrongLiftsAndATG() {
        var strongLifts = Program.strongLiftsDefault
        XCTAssertTrue(strongLifts.isValid)
        strongLifts.workouts[1].assignedDays = [.monday]
        XCTAssertTrue(strongLifts.isValid)

        var atg = Program.atgDefault
        atg.workouts[0].assignedDays = [.monday, .tuesday]
        XCTAssertEqual(atg.validationError, .atgRequiresThreeToFiveDays)
        atg.workouts[0].assignedDays = [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday]
        XCTAssertEqual(atg.validationError, .atgRequiresThreeToFiveDays)
        atg.workouts[0].assignedDays = [.monday, .wednesday, .friday, .sunday]
        XCTAssertTrue(atg.isValid)
    }

    func testLegacyStrongLiftsCodableDerivesProgramDays() throws {
        var legacy = Program.strongLiftsDefault
        legacy.workouts[0].assignedDays = [.monday, .friday]
        legacy.workouts[1].assignedDays = [.wednesday]
        var object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(legacy)) as! [String: Any]
        object.removeValue(forKey: "trainingDays")
        let data = try JSONSerialization.data(withJSONObject: object)
        let decoded = try JSONDecoder().decode(Program.self, from: data)
        XCTAssertEqual(decoded.trainingDays, [.monday, .wednesday, .friday])
    }

    func testStrongLiftsNextWorkoutFollowsLastCompletedNotCalendar() {
        XCTAssertEqual(StrongLiftsScheduling.nextWorkoutIdentity(after: nil), "A")
        XCTAssertEqual(StrongLiftsScheduling.nextWorkoutIdentity(after: "A"), "B")
        // Friday B was missed after Wednesday A: Monday still starts B.
        XCTAssertEqual(StrongLiftsScheduling.nextWorkoutIdentity(after: "A"), "B")
        XCTAssertEqual(StrongLiftsScheduling.nextWorkoutIdentity(after: "B"), "A")
    }

    func testEditingHelpersOnlyAddAndRemoveATGWorkoutsAndPreserveOrder() {
        var atg = Program.atgDefault
        atg.addExercise(to: 0)
        XCTAssertEqual(atg.workouts[0].exercises.count, 4)
        atg.removeExercise(workoutIndex: 0, at: IndexSet(integer: 1))
        XCTAssertEqual(atg.workouts[0].exercises.map(\.name), ["Split Squat", "Calf Raise", "New Exercise"])
        atg.addWorkout()
        XCTAssertEqual(atg.workouts.count, 2)
        var strongLifts = Program.strongLiftsDefault
        strongLifts.addWorkout()
        XCTAssertEqual(strongLifts.workouts.count, 2)
    }

    func testActiveSelectionReplacesAndTogglesWithinEachKind() {
        let strongOne = Program.new(kind: .strongLifts, name: "One")
        let strongTwo = Program.new(kind: .strongLifts, name: "Two")
        let atgOne = Program.new(kind: .atg, name: "ATG One")
        var selection = ActiveProgramSelectionLogic.toggled(ActiveProgramSelection(), for: strongOne)
        selection = ActiveProgramSelectionLogic.toggled(selection, for: atgOne)
        XCTAssertEqual(selection, ActiveProgramSelection(strongLiftsID: strongOne.id, atgID: atgOne.id))
        selection = ActiveProgramSelectionLogic.toggled(selection, for: strongTwo)
        XCTAssertEqual(selection.strongLiftsID, strongTwo.id)
        XCTAssertEqual(selection.atgID, atgOne.id)
        XCTAssertNil(ActiveProgramSelectionLogic.toggled(selection, for: strongTwo).strongLiftsID)
    }

    func testActiveSelectionPersistenceRoundTripAndLegacySafeDefault() {
        let suite = "ProgramsActiveTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let repository = ProgramsRepository(defaults: defaults)
        XCTAssertEqual(repository.loadActiveSelection(), ActiveProgramSelection())
        let selection = ActiveProgramSelection(strongLiftsID: UUID(), atgID: UUID())
        repository.saveActiveSelection(selection)
        XCTAssertEqual(repository.loadActiveSelection(), selection)
        defaults.set(Data("legacy".utf8), forKey: "programs.active.v1")
        XCTAssertEqual(repository.loadActiveSelection(), ActiveProgramSelection())
    }

    func testClearingStrongLiftsSelectionPreservesATGSelectionAndPersistsNil() {
        let suite = "ProgramsClearActiveTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let repository = ProgramsRepository(defaults: defaults)
        let atgID = UUID()
        repository.saveActiveSelection(ActiveProgramSelection(strongLiftsID: UUID(), atgID: atgID))

        var selection = repository.loadActiveSelection()
        selection.strongLiftsID = nil
        repository.saveActiveSelection(selection)

        XCTAssertEqual(repository.loadActiveSelection(), ActiveProgramSelection(strongLiftsID: nil, atgID: atgID))
    }

    func testActiveScheduleConflictDetection() {
        var strong = Program.strongLiftsDefault
        var atg = Program.atgDefault
        atg.workouts[0].assignedDays = [.tuesday, .thursday, .saturday]
        XCTAssertFalse(ProgramScheduleConflict.hasConflict(strongLifts: strong, atg: atg))
        atg.workouts[0].assignedDays = [.monday, .thursday, .saturday]
        XCTAssertEqual(ProgramScheduleConflict.overlappingDays(strongLifts: strong, atg: atg), [.monday])
        XCTAssertTrue(ProgramScheduleConflict.hasConflict(strongLifts: strong, atg: atg))
        strong.trainingDays = [.sunday]
        XCTAssertFalse(ProgramScheduleConflict.hasConflict(strongLifts: strong, atg: atg))
    }

    func testProgramWorkoutConvertsToTemplateAndSeedsCustomSession() {
        let workout = ProgramWorkout(identity: "A", name: "Custom A", exercises: [
            ProgramExercise(name: "My Squat", targetSets: 2, targetReps: 8),
            ProgramExercise(name: "Bench Press", targetSets: 1, targetReps: 10)
        ])
        let template = try! XCTUnwrap(ProgramWorkoutConversion.template(from: workout))
        let session = WorkoutSession.seeded(from: template, history: [], settings: ExerciseProgressionSetting.defaults)

        XCTAssertEqual(template.id, .strongLiftsA)
        XCTAssertEqual(template.name, "Custom A")
        XCTAssertEqual(session.sets.map(\.exerciseName), ["My Squat", "My Squat", "Bench Press"])
        XCTAssertEqual(session.sets.map(\.targetReps), [8, 8, 10])
        XCTAssertEqual(session.sets.map(\.displayOrder), [0, 0, 1])
        XCTAssertEqual(session.sets.first?.weight, 45)
    }

    func testEmptyProgramWorkoutConvertsButCannotStartZeroSetSession() {
        let workout = ProgramWorkout(identity: "A", name: "Empty A", exercises: [])
        let template = try! XCTUnwrap(ProgramWorkoutConversion.template(from: workout))

        XCTAssertTrue(template.exercises.isEmpty)
        XCTAssertTrue(HomeWorkoutLogic.shouldDisableStart(selectedProgramWorkout: workout, template: template))
        XCTAssertTrue(WorkoutSession.seeded(from: template, history: [], settings: nil).sets.isEmpty)
    }

    func testActiveStrongLiftsProgramSelectsNextABAfterCompletedHistory() {
        var program = Program.new(kind: .strongLifts, name: "Custom StrongLifts")
        program.workouts[0].name = "My A"
        program.workouts[1].name = "My B"
        let completedA = WorkoutSession(templateID: .strongLiftsA, templateName: "My A", completedAt: Date())

        XCTAssertEqual(StrongLiftsProgramSelection.nextWorkout(in: program, after: [completedA])?.identity, "B")
        XCTAssertEqual(StrongLiftsProgramSelection.nextWorkout(in: program, after: [])?.identity, "A")
    }

    func testProgramSelectionFallsBackToLegacyTemplateWhenNoActiveProgram() {
        let completedA = WorkoutSession(templateID: .strongLiftsA, templateName: "Workout A", completedAt: Date())
        let noProgram: Program? = nil
        let template = noProgram.flatMap { program in
            StrongLiftsProgramSelection.nextWorkout(in: program, after: [completedA]).flatMap(ProgramWorkoutConversion.template)
        } ?? StrongLiftsTemplates.template(after: completedA.templateID)

        XCTAssertEqual(template.name, "Workout B")
        XCTAssertEqual(template.exercises.map(\.targetSets), [5, 5, 1])
        XCTAssertEqual(template.exercises.map(\.name), ["Squat", "Overhead Press", "Deadlift"])
    }
    func testManualCreationUsesRequestedNameAndFreshStructureIDs() {
        let first = Program.new(kind: .strongLifts, name: "My 5x5")
        let second = Program.new(kind: .strongLifts, name: "Other")
        XCTAssertEqual(first.name, "My 5x5")
        XCTAssertEqual(first.workouts.map(\.identity), ["A", "B"])
        XCTAssertNotEqual(first.id, second.id)
        XCTAssertNotEqual(first.workouts[0].id, second.workouts[0].id)
    }
}
