import SwiftUI

struct ProgressionSettingsView: View {
    private let repository: ProgressionSettingsRepository
    @State private var settings: [ExerciseProgressionSetting]
    @State private var defaultIncrement: Double
    @State private var defaultDeloadPercentage: Double

    init(repository: ProgressionSettingsRepository = ProgressionSettingsRepository()) {
        self.repository = repository
        _settings = State(initialValue: repository.load())
        _defaultIncrement = State(initialValue: repository.defaultIncrement)
        _defaultDeloadPercentage = State(initialValue: repository.defaultDeloadPercentage)
    }

    var body: some View {
        Form {
            Section("Defaults for new exercises") {
                Text("These defaults update exercises that still use the previous default. Custom exercise values are preserved.")
                    .font(.subheadline).foregroundStyle(.secondary)
                numberField("Default increment (lb)", value: $defaultIncrement, step: 5)
                numberField("Default deload (%)", value: $defaultDeloadPercentage, step: 1)
            }
            exerciseSection(for: .strongLiftsA)
            exerciseSection(for: .strongLiftsB)
        }
        .navigationTitle("Progression")
        .onChange(of: defaultIncrement) { _, value in updateDefaults(increment: value, deload: defaultDeloadPercentage) }
        .onChange(of: defaultDeloadPercentage) { _, value in updateDefaults(increment: defaultIncrement, deload: value) }
    }

    @ViewBuilder private func exerciseSection(for templateID: TemplateID) -> some View {
        Section(templateID == .strongLiftsA ? "Workout A" : "Workout B") {
            ForEach(StrongLiftsTemplates.all.first(where: { $0.id == templateID })?.exercises ?? []) { exercise in
                if let index = settings.firstIndex(where: { $0.id == exercise.id }) {
                    NavigationLink {
                        ExerciseProgressionDetailView(setting: settings[index], otherSettings: settings.filter { $0.id != exercise.id }) { updated in
                            settings[index] = updated
                            repository.save(settings)
                        }
                    } label: {
                        VStack(alignment: .leading) {
                            Text(exercise.name)
                            Text("\(settings[index].targetSets) x \(settings[index].targetReps)  •  \(settings[index].currentWeight.formatted()) lb")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private func updateDefaults(increment: Double, deload: Double) {
        repository.updateGlobalDefaults(increment: increment, deloadPercentage: deload, settings: &settings)
    }

    private func numberField(_ title: String, value: Binding<Double>, step: Double) -> some View {
        HStack {
            Text(title); Spacer()
            TextField(title, value: value, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 85)
            Stepper("", value: value, in: 0...1_000, step: step).labelsHidden()
        }
    }
}

private struct ExerciseProgressionDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let original: ExerciseProgressionSetting
    let otherSettings: [ExerciseProgressionSetting]
    @State private var setting: ExerciseProgressionSetting
    let onSave: (ExerciseProgressionSetting) -> Void

    init(setting: ExerciseProgressionSetting, otherSettings: [ExerciseProgressionSetting], onSave: @escaping (ExerciseProgressionSetting) -> Void) {
        self.original = setting; self.otherSettings = otherSettings; self.onSave = onSave
        _setting = State(initialValue: setting)
    }

    var body: some View {
        Form {
            Section("Prescription") {
                numberField("Sets", value: Binding(get: { Double(setting.targetSets) }, set: { setting.targetSets = max(1, Int($0)) }), step: 1)
                numberField("Reps", value: Binding(get: { Double(setting.targetReps) }, set: { setting.targetReps = max(1, Int($0)) }), step: 1)
                numberField("Exercise weight (lb)", value: $setting.currentWeight, step: 5)
            }
            Section("Progression") {
                numberField("Increment (lb)", value: $setting.increment, step: 5)
                numberField("Deload (%)", value: $setting.deloadPercentage, step: 1)
                Stepper("Failures before deload: \(setting.failureFrequency)", value: $setting.failureFrequency, in: 1...10)
            }
            Section {
                Button("Reset to default") { setting = ExerciseProgressionSetting.defaults.first(where: { $0.id == setting.id }) ?? original }
                Menu("Copy settings from…") {
                    ForEach(otherSettings) { source in
                        Button(source.name) {
                            setting.currentWeight = source.currentWeight
                            setting.increment = source.increment
                            setting.deloadPercentage = source.deloadPercentage
                            setting.failureFrequency = source.failureFrequency
                            setting.targetSets = source.targetSets
                            setting.targetReps = source.targetReps
                        }
                    }
                }
            }
        }
        .navigationTitle(setting.name)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    onSave(setting)
                    dismiss()
                }
            }
        }
    }

    private func numberField(_ title: String, value: Binding<Double>, step: Double) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField(title, value: value, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 85)
            Stepper("", value: value, in: 0...1_000, step: step).labelsHidden()
        }
    }
}
