import SwiftUI

struct ProgramsView: View {
    @State private var programs: [Program]
    @State private var creating = false
    private let repository: ProgramsRepository

    init(repository: ProgramsRepository = ProgramsRepository()) {
        self.repository = repository
        _programs = State(initialValue: repository.load())
    }

    var body: some View {
        List {
            ForEach(ProgramKind.allCases) { kind in
                Section(kind.displayName) {
                    ForEach(programs.filter { $0.kind == kind }) { program in
                        NavigationLink {
                            ProgramDetailView(program: program, onSave: save)
                        } label: {
                            VStack(alignment: .leading) {
                                Text(program.name).font(.headline)
                                Text(kind == .atg ? "Modest starter template • no mobility logging" : "Alternating Workout A / Workout B")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Programs")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { creating = true } label: { Label("Create Program", systemImage: "plus") } } }
        .sheet(isPresented: $creating) { CreateProgramView { program in
            programs.append(program)
            repository.save(programs)
            creating = false
        } }
    }

    private func save(_ program: Program) {
        guard let index = programs.firstIndex(where: { $0.id == program.id }) else { return }
        programs[index] = program
        repository.save(programs)
    }
}

struct ProgramDetailView: View {
    let program: Program
    let onSave: (Program) -> Void
    @State private var editing = false

    var body: some View {
        List {
            Section {
                Text(program.kind == .atg ? "A modest 3–5 day starter program. This app does not provide full ATG mobility logging." : "StrongLifts preserves A/B workout identity and alternation.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            ForEach(program.workouts) { workout in
                Section(workout.name) {
                    if !workout.assignedDays.isEmpty { Text(workout.assignedDays.map(\.shortName).joined(separator: " • ")).foregroundStyle(.secondary) }
                    ForEach(workout.exercises) { exercise in
                        HStack { Text(exercise.name); Spacer(); Text("\(exercise.targetSets) × \(exercise.targetReps)").foregroundStyle(.secondary) }
                    }
                }
            }
            if let error = program.validationError { Text(validationMessage(error)).foregroundStyle(.red) }
        }
        .navigationTitle(program.name)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Edit") { editing = true } } }
        .sheet(isPresented: $editing) { ProgramEditorView(program: program, onSave: { onSave($0); editing = false }) }
    }

    private func validationMessage(_ error: ProgramValidationError) -> String {
        switch error { case .atgRequiresThreeToFiveDays: return "Select 3–5 training days to save this ATG program."; case .strongLiftsAlternation: return "StrongLifts days must alternate A and B."; case .strongLiftsRequiresAB: return "StrongLifts requires Workout A and Workout B." }
    }
}

struct ProgramEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var program: Program
    let onSave: (Program) -> Void

    init(program: Program, onSave: @escaping (Program) -> Void) { _program = State(initialValue: program); self.onSave = onSave }

    var body: some View {
        NavigationStack {
            Form {
                Section("Program") { TextField("Name", text: $program.name) }
                ForEach(program.workouts.indices, id: \.self) { workoutIndex in
                    workoutSection(workoutIndex)
                }
                if program.kind == .atg {
                    Section { Button("Add workout") { program.addWorkout() }; if program.workouts.count > 1 { Button("Remove last workout", role: .destructive) { program.workouts.removeLast() } } }
                }
                if let error = program.validationError { Section { Label(editorMessage(error), systemImage: "exclamationmark.triangle").foregroundStyle(.orange) } }
            }
            .navigationTitle("Edit Program")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { onSave(program); dismiss() }.disabled(!program.isValid || program.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
            }
        }
    }

    @ViewBuilder private func workoutSection(_ index: Int) -> some View {
        Section {
            TextField("Workout name", text: Binding(get: { program.workouts[index].name }, set: { program.workouts[index].name = $0 }))
            dayPicker(for: index)
            ForEach(program.workouts[index].exercises.indices, id: \.self) { exerciseIndex in
                VStack(alignment: .leading) {
                    TextField("Exercise name", text: Binding(get: { program.workouts[index].exercises[exerciseIndex].name }, set: { program.workouts[index].exercises[exerciseIndex].name = $0 }))
                    HStack {
                        Stepper("Sets: \(program.workouts[index].exercises[exerciseIndex].targetSets)", value: Binding(get: { program.workouts[index].exercises[exerciseIndex].targetSets }, set: { program.workouts[index].exercises[exerciseIndex].targetSets = max(1, $0) }), in: 1...20)
                        Stepper("Reps: \(program.workouts[index].exercises[exerciseIndex].targetReps)", value: Binding(get: { program.workouts[index].exercises[exerciseIndex].targetReps }, set: { program.workouts[index].exercises[exerciseIndex].targetReps = max(1, $0) }), in: 1...100)
                    }.font(.caption)
                }
            }
            Button("Add exercise") { program.addExercise(to: index) }
            if program.kind == .atg && program.workouts[index].exercises.count > 1 { Button("Remove last exercise", role: .destructive) { program.workouts[index].exercises.removeLast() } }
        } header: { Text(program.kind == .strongLifts ? "Workout \(program.workouts[index].identity ?? "")" : program.workouts[index].name) }
    }

    private func dayPicker(for index: Int) -> some View {
        VStack(alignment: .leading) {
            Text("Training days").font(.subheadline)
            HStack { ForEach(TrainingDay.allCases) { day in
                Button(day.shortName) {
                    if program.workouts[index].assignedDays.contains(day) { program.workouts[index].assignedDays.removeAll { $0 == day } }
                    else { program.workouts[index].assignedDays.append(day); program.workouts[index].assignedDays.sort() }
                }.buttonStyle(.bordered).tint(program.workouts[index].assignedDays.contains(day) ? .accentColor : .gray)
            }}
            if program.kind == .atg { Text("ATG requires 3–5 selected days (currently \(program.selectedTrainingDays.count)).").font(.caption).foregroundStyle(.secondary) }
        }
    }

    private func editorMessage(_ error: ProgramValidationError) -> String {
        switch error { case .atgRequiresThreeToFiveDays: return "ATG requires 3–5 selected training days."; case .strongLiftsAlternation: return "Choose alternating A/B days."; case .strongLiftsRequiresAB: return "StrongLifts A/B identity is required." }
    }
}
