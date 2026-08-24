import SwiftUI

struct ProgramsView: View {
    @State private var programs: [Program]
    @State private var activeSelection: ActiveProgramSelection
    @State private var creating = false
    @State private var conflictDays: [TrainingDay] = []
    @State private var showingConflict = false
    @State private var showingInvalidProgram = false
    private let repository: ProgramsRepository

    init(repository: ProgramsRepository = ProgramsRepository()) {
        self.repository = repository
        let loaded = repository.load()
        _programs = State(initialValue: loaded)
        _activeSelection = State(initialValue: repository.loadActiveSelection(for: loaded))
    }

    var body: some View {
        List {
            ForEach(ProgramKind.allCases) { kind in
                Section(kind.displayName) {
                    ForEach(programs.filter { $0.kind == kind }) { program in
                        HStack {
                            NavigationLink {
                                ProgramDetailView(program: program, onSave: save)
                            } label: {
                                VStack(alignment: .leading) {
                                    HStack(spacing: 6) {
                                        Text(program.name).font(.headline)
                                        if activeSelection.id(for: kind) == program.id {
                                            Text("ACTIVE").font(.caption2.bold()).foregroundStyle(.green)
                                        }
                                    }
                                    Text(kind == .atg ? "Modest starter template • no mobility logging" : "Alternating Workout A / Workout B")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Button(activeSelection.id(for: kind) == program.id ? "Active" : "Set active") { setActive(program) }
                                .buttonStyle(.bordered)
                                .tint(activeSelection.id(for: kind) == program.id ? .green : .accentColor)
                        }
                    }
                }
            }
            if !conflictDays.isEmpty {
                Section("Schedule conflict") {
                    Label("Active programs overlap on \(conflictDays.map(\.shortName).joined(separator: ", ")). Consider changing one program's training days.", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
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
        .alert("Active program schedule conflict", isPresented: $showingConflict) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Your active StrongLifts and ATG programs overlap on \(conflictDays.map(\.shortName).joined(separator: ", ")). Edit one program's training days if you want to avoid this conflict.")
        }
        .alert("Program cannot be active", isPresented: $showingInvalidProgram) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Fix this program's validation issues before marking it active.")
        }
    }

    private func save(_ program: Program) {
        guard let index = programs.firstIndex(where: { $0.id == program.id }) else { return }
        programs[index] = program
        repository.save(programs)
        refreshConflict()
    }

    private func setActive(_ program: Program) {
        guard activeSelection.id(for: program.kind) == program.id || program.isValid else {
            showingInvalidProgram = true
            return
        }
        let previous = activeSelection
        activeSelection = ActiveProgramSelectionLogic.toggled(activeSelection, for: program)
        repository.saveActiveSelection(activeSelection)
        refreshConflict()
        if previous != activeSelection && !conflictDays.isEmpty && activeSelection.id(for: program.kind) == program.id {
            showingConflict = true
        }
    }

    private func refreshConflict() {
        let strong = programs.first { $0.id == activeSelection.strongLiftsID }
        let atg = programs.first { $0.id == activeSelection.atgID }
        conflictDays = strong.flatMap { strongProgram in
            atg.map { ProgramScheduleConflict.overlappingDays(strongLifts: strongProgram, atg: $0) }
        } ?? []
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
                    if program.kind == .atg && !workout.assignedDays.isEmpty { Text(workout.assignedDays.map(\.shortName).joined(separator: " • ")).foregroundStyle(.secondary) }
                    ForEach(workout.exercises) { exercise in
                        HStack { Text(exercise.name); Spacer(); Text("\(exercise.targetSets) × \(exercise.targetReps)").foregroundStyle(.secondary) }
                    }
                }
            }
            if program.kind == .strongLifts {
                Section("Training days") { Text(program.trainingDays.map(\.shortName).joined(separator: " • ")) }
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
                if program.kind == .strongLifts { strongLiftsDaySection }
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
            if program.kind == .atg { dayPicker(for: index) }
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

    private var strongLiftsDaySection: some View {
        Section("StrongLifts training days") {
            dayButtons(selection: Binding(get: { program.trainingDays }, set: { program.trainingDays = $0.sorted() }))
            Text("A and B alternate from the last completed workout; missed days do not change the sequence.").font(.caption).foregroundStyle(.secondary)
        }
    }

    private func dayPicker(for index: Int) -> some View {
        VStack(alignment: .leading) {
            Text("Training days").font(.subheadline)
            dayButtons(selection: Binding(get: { program.workouts[index].assignedDays }, set: { program.workouts[index].assignedDays = $0.sorted() }))
            if program.kind == .atg { Text("ATG requires 3–5 selected days (currently \(program.selectedTrainingDays.count)).").font(.caption).foregroundStyle(.secondary) }
        }
    }

    private func dayButtons(selection: Binding<[TrainingDay]>) -> some View {
        HStack { ForEach(TrainingDay.allCases) { day in
            Button(day.shortName) {
                if selection.wrappedValue.contains(day) { selection.wrappedValue.removeAll { $0 == day } }
                else { selection.wrappedValue.append(day) }
            }.buttonStyle(.bordered).tint(selection.wrappedValue.contains(day) ? .accentColor : .gray)
        }}
    }

    private func editorMessage(_ error: ProgramValidationError) -> String {
        switch error { case .atgRequiresThreeToFiveDays: return "ATG requires 3–5 selected training days."; case .strongLiftsAlternation: return "Choose alternating A/B days."; case .strongLiftsRequiresAB: return "StrongLifts A/B identity is required." }
    }
}
