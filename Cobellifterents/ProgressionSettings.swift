import Foundation

final class ProgressionSettingsRepository {
    private let defaults: UserDefaults
    private let key = "progressionSettings"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var hasCustomSettings: Bool {
        defaults.data(forKey: key) != nil
    }

    func load() -> [ExerciseProgressionSetting] {
        guard let data = defaults.data(forKey: key),
              let settings = try? JSONDecoder().decode([ExerciseProgressionSetting].self, from: data),
              !settings.isEmpty else {
            return ExerciseProgressionSetting.defaults
        }
        return ExerciseProgressionSetting.defaults.map { fallback in
            settings.first(where: { $0.id == fallback.id }) ?? fallback
        }
    }

    func save(_ settings: [ExerciseProgressionSetting]) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: key)
    }
}
