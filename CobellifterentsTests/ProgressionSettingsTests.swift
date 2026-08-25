import XCTest
@testable import Cobellifterents

final class ProgressionSettingsTests: XCTestCase {
    func testDefaultsContainSixExercisesAndMatchTemplatePrescriptions() {
        XCTAssertEqual(ExerciseProgressionSetting.defaults.count, 6)
        XCTAssertEqual(ExerciseProgressionSetting.defaults.first { $0.id == "deadlift" }?.increment, 10)
        XCTAssertEqual(ExerciseProgressionSetting.defaults.first { $0.id == "squat" }?.currentWeight, 45)
    }

    func testRepositoryRoundTripsAndPreservesMissingDefaults() {
        let suite = "ProgressionSettingsTests.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suite)!
        defer { userDefaults.removePersistentDomain(forName: suite) }
        let repository = ProgressionSettingsRepository(defaults: userDefaults)
        XCTAssertEqual(repository.load(), ExerciseProgressionSetting.defaults)
        var saved = repository.load()
        saved[0].currentWeight = 135
        saved[0].failureFrequency = 2
        repository.save(saved)
        XCTAssertEqual(repository.load().first?.currentWeight, 135)
        XCTAssertEqual(repository.load().first?.failureFrequency, 2)
    }

    func testGlobalDefaultsPersistAndDoNotOverwriteCustomExerciseValues() {
        let suite = "ProgressionDefaultsTests.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suite)!
        defer { userDefaults.removePersistentDomain(forName: suite) }
        let repository = ProgressionSettingsRepository(defaults: userDefaults)
        var settings = repository.load()
        settings[0].increment = 12
        repository.save(settings)
        repository.updateGlobalDefaults(increment: 7, deloadPercentage: 15, settings: &settings)
        XCTAssertEqual(repository.defaultIncrement, 7)
        XCTAssertEqual(repository.defaultDeloadPercentage, 15)
        XCTAssertEqual(settings[0].increment, 12)
        XCTAssertEqual(settings[1].increment, 7)
        XCTAssertEqual(repository.load()[1].deloadPercentage, 15)
    }

    func testSeededWorkoutUsesCustomSettings() {
        var settings = ExerciseProgressionSetting.defaults
        settings[0].currentWeight = 135
        let session = WorkoutSession.seeded(from: StrongLiftsTemplates.all[0], history: [], settings: settings)
        XCTAssertEqual(session.sets.first?.weight, 135)
    }

    func testLegacySettingsDecodeWithDefaultPrescription() throws {
        let data = #"[{"id":"squat","name":"Squat","currentWeight":45,"increment":5,"deloadPercentage":10,"failureFrequency":3}]"#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode([ExerciseProgressionSetting].self, from: data)
        XCTAssertEqual(decoded.first?.targetSets, 5)
        XCTAssertEqual(decoded.first?.targetReps, 5)
    }
}
