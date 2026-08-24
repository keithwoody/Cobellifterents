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

    func testManualCreationUsesRequestedNameAndFreshStructureIDs() {
        let first = Program.new(kind: .strongLifts, name: "My 5x5")
        let second = Program.new(kind: .strongLifts, name: "Other")
        XCTAssertEqual(first.name, "My 5x5")
        XCTAssertEqual(first.workouts.map(\.identity), ["A", "B"])
        XCTAssertNotEqual(first.id, second.id)
        XCTAssertNotEqual(first.workouts[0].id, second.workouts[0].id)
    }
}
