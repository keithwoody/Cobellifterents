import Foundation

final class ProgressionSettingsRepository {
    private let defaults: UserDefaults
    private let key = "progressionSettings"
    private let defaultIncrementKey = "progressionDefaultIncrement"
    private let defaultDeloadKey = "progressionDefaultDeloadPercentage"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var hasCustomSettings: Bool { defaults.data(forKey: key) != nil }
    var defaultIncrement: Double {
        get { defaults.object(forKey: defaultIncrementKey) as? Double ?? 5 }
        set { defaults.set(newValue, forKey: defaultIncrementKey) }
    }
    var defaultDeloadPercentage: Double {
        get { defaults.object(forKey: defaultDeloadKey) as? Double ?? 10 }
        set { defaults.set(newValue, forKey: defaultDeloadKey) }
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

    func updateGlobalDefaults(increment: Double, deloadPercentage: Double, settings: inout [ExerciseProgressionSetting]) {
        let oldIncrement = defaultIncrement
        let oldDeload = defaultDeloadPercentage
        for index in settings.indices {
            if settings[index].increment == oldIncrement { settings[index].increment = increment }
            if settings[index].deloadPercentage == oldDeload { settings[index].deloadPercentage = deloadPercentage }
        }
        defaultIncrement = increment
        defaultDeloadPercentage = deloadPercentage
        save(settings)
    }

}
