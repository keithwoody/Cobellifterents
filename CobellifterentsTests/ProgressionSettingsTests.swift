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

    func testSeededWorkoutUsesCustomSettings() {
        var settings = ExerciseProgressionSetting.defaults
        settings[0].currentWeight = 135
        let session = WorkoutSession.seeded(from: StrongLiftsTemplates.all[0], history: [], settings: settings)
        XCTAssertEqual(session.sets.first?.weight, 135)
    }
}
