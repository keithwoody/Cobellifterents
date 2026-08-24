import SwiftUI

struct ProgressionSettingsView: View {
    private let repository: ProgressionSettingsRepository
    @State private var settings: [ExerciseProgressionSetting]

    init(repository: ProgressionSettingsRepository = ProgressionSettingsRepository()) {
        self.repository = repository
        _settings = State(initialValue: repository.load())
    }

    var body: some View {
        Form {
            Section {
                Text("Adjust the starting prescription used for new workouts. Changes are saved on this device.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            ForEach($settings) { $setting in
                Section(setting.name) {
                    settingField("Current weight (lb)", value: $setting.currentWeight, step: 5)
                    settingField("Increment (lb)", value: $setting.increment, step: 5)
                    settingField("Deload (%)", value: $setting.deloadPercentage, step: 1)
                    Stepper("Failures before deload: \(setting.failureFrequency)", value: $setting.failureFrequency, in: 1...10)
                }
            }
        }
        .navigationTitle("Progression")
        .onChange(of: settings) { _, newValue in repository.save(newValue) }
    }

    private func settingField(_ title: String, value: Binding<Double>, step: Double) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField(title, value: value, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 90)
            Stepper("", value: value, in: 0...1_000, step: step)
                .labelsHidden()
        }
    }
}
