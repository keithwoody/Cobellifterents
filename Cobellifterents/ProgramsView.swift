import SwiftUI
import SwiftData

struct ProgramsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var sessions: [WorkoutSession]
    @State private var programs: [Program]
    @State private var activeSelection: ActiveProgramSelection
    @State private var creating = false
    @State private var conflictDays: [TrainingDay] = []
    @State private var showingConflict = false
    @State private var showingInvalidProgram = false
    @State private var showingDeletionError = false
    @State private var deletionErrorMessage = ""
    @State private var programPendingDeletion: Program?
    @State private var showingProgramDeleteConfirmation = false
    @State private var showingClearHistoryConfirmation = false
    @State private var clearHistoryError: String?
    private let repository: ProgramsRepository

    init(repository: ProgramsRepository = ProgramsRepository()) {
        self.repository = repository
        let loaded = repository.load()
        let selection = repository.loadActiveSelection(for: loaded)
        _programs = State(initialValue: loaded)
        _activeSelection = State(initialValue: selection)
        _conflictDays = State(initialValue: Self.conflictDays(in: loaded, selection: selection))
    }

    var body: some View {
        List {
            ForEach(ProgramKind.allCases) { kind in
                Section(kind.displayName) {
                    if kind == .strongLifts {
                        HStack {
                            VStack(alignment: .leading) {
                                HStack(spacing: 6) {
                                    Text("Built-in StrongLifts 5×5").font(.headline)
                                    if activeSelection.strongLiftsID == nil {
                                        Text("ACTIVE").font(.caption2.bold()).foregroundStyle(.green)
                                    }
                                }
                                Text("Use the standard Workout A / Workout B template")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button(activeSelection.strongLiftsID == nil ? "Active" : "Use 5×5") {
                                useBuiltInStrongLifts()
                            }
                            .buttonStyle(.bordered)
                            .tint(activeSelection.strongLiftsID == nil ? .green : .accentColor)
                        }
                    }
                    ForEach(programs.filter { $0.kind == kind }) { program in
                        HStack {
                            NavigationLink {
                                ProgramDetailView(program: program, onSave: save, onDelete: delete)
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
                            if !program.isBuiltIn {
                                Button(role: .destructive) {
                                    programPendingDeletion = program
                                    showingProgramDeleteConfirmation = true
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .accessibilityLabel("Delete \(program.name)")
                            }
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
            Section("Danger zone") {
                Button("Clear Workout History", role: .destructive) {
                    showingClearHistoryConfirmation = true
                }
                Text("Deletes all workouts, sets, and imported source records. Programs and settings are preserved.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
        .alert("Program could not be deleted", isPresented: $showingDeletionError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(deletionErrorMessage)
        }
        .confirmationDialog("Delete Program?", isPresented: $showingProgramDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete Program", role: .destructive) {
                if let programPendingDeletion {
                    _ = delete(programPendingDeletion)
                }
                programPendingDeletion = nil
            }
            Button("Cancel", role: .cancel) {
                programPendingDeletion = nil
            }
        } message: {
            Text("Workout history will be preserved and marked unassigned.")
        }
        .confirmationDialog("Clear all workout history?", isPresented: $showingClearHistoryConfirmation, titleVisibility: .visible) {
            Button("Clear Workout History", role: .destructive) {
                clearWorkoutHistory()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This permanently deletes every workout session, all dependent sets, and all imported raw/provenance records. Programs, active Program selections, and other settings will remain.")
        }
        .alert("Could Not Clear Workout History", isPresented: clearHistoryErrorBinding) {
            Button("OK", role: .cancel) { clearHistoryError = nil }
        } message: {
            Text(clearHistoryError ?? "The workout history was not changed.")
        }
    }

    private func save(_ program: Program) {
        guard let index = programs.firstIndex(where: { $0.id == program.id }) else { return }
        programs[index] = program
        repository.save(programs)
        refreshConflict()
    }

    private func delete(_ program: Program) -> Bool {
        guard !program.isBuiltIn else { return false }
        do {
            programs = try repository.delete(program, sessions: sessions, in: modelContext)
            activeSelection = repository.loadActiveSelection(for: programs)
            refreshConflict()
            return true
        } catch {
            deletionErrorMessage = error.localizedDescription
            showingDeletionError = true
            return false
        }
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
        conflictDays = Self.conflictDays(in: programs, selection: activeSelection)
    }

    private func useBuiltInStrongLifts() {
        guard activeSelection.strongLiftsID != nil else { return }
        activeSelection.strongLiftsID = nil
        repository.saveActiveSelection(activeSelection)
        refreshConflict()
    }

    private func clearWorkoutHistory() {
        do {
            try WorkoutHistoryClearer.clear(in: modelContext)
            programs = repository.ensureBuiltIns()
            activeSelection = repository.loadActiveSelection(for: programs)
            refreshConflict()
        } catch {
            clearHistoryError = error.localizedDescription
        }
    }

    private var clearHistoryErrorBinding: Binding<Bool> {
        Binding(
            get: { clearHistoryError != nil },
            set: { if !$0 { clearHistoryError = nil } }
        )
    }

    private static func conflictDays(in programs: [Program], selection: ActiveProgramSelection) -> [TrainingDay] {
        let strong = programs.first { $0.id == selection.strongLiftsID }
        let atg = programs.first { $0.id == selection.atgID }
        return strong.flatMap { strongProgram in
            atg.map { ProgramScheduleConflict.overlappingDays(strongLifts: strongProgram, atg: $0) }
        } ?? []
    }
}

struct ProgramDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let program: Program
    let onSave: (Program) -> Void
    let onDelete: (Program) -> Bool
    @State private var editing = false
    @State private var showingDeleteConfirmation = false
    @State private var displayedProgram: Program

    init(program: Program, onSave: @escaping (Program) -> Void, onDelete: @escaping (Program) -> Bool) {
        self.program = program
        self.onSave = onSave
        self.onDelete = onDelete
        _displayedProgram = State(initialValue: program)
    }

    var body: some View {
        List {
            Section {
                Text(displayedProgram.kind == .atg ? "A modest 3–5 day starter program. This app does not provide full ATG mobility logging." : "StrongLifts preserves A/B workout identity and alternation.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            ForEach(displayedProgram.workouts) { workout in
                Section(workout.name) {
                    if displayedProgram.kind == .atg && !workout.assignedDays.isEmpty { Text(workout.assignedDays.map(\.shortName).joined(separator: " • ")).foregroundStyle(.secondary) }
                    ForEach(workout.exercises) { exercise in
                        HStack { Text(exercise.name); Spacer(); Text("\(exercise.targetSets) × \(exercise.targetReps)").foregroundStyle(.secondary) }
                    }
                }
            }
            if displayedProgram.kind == .strongLifts {
                Section("Training days") { Text(displayedProgram.trainingDays.map(\.shortName).joined(separator: " • ")) }
            }
            Section("Rest days") {
                if displayedProgram.restDays.isEmpty { Text("None selected").foregroundStyle(.secondary) }
                else { Text(displayedProgram.restDays.map(\.shortName).joined(separator: " • ")) }
            }
            if let error = displayedProgram.validationError { Text(validationMessage(error)).foregroundStyle(.red) }
        }
        .navigationTitle(displayedProgram.name)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { Button("Edit") { editing = true } }
            if !displayedProgram.isBuiltIn {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Delete", role: .destructive) { showingDeleteConfirmation = true }
                }
            }
        }
        .confirmationDialog("Delete Program?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete Program", role: .destructive) {
                if onDelete(displayedProgram) { dismiss() }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("All workout history will be preserved and marked unassigned.")
        }
        .sheet(isPresented: $editing) {
            ProgramEditorView(program: displayedProgram, onSave: { savedProgram in
                displayedProgram = savedProgram
                onSave(savedProgram)
                editing = false
            })
        }
    }

    private func validationMessage(_ error: ProgramValidationError) -> String {
        switch error { case .atgRequiresThreeToFiveDays: return "Select 3–5 training days to save this ATG program."; case .strongLiftsAlternation: return "StrongLifts days must alternate A and B."; case .strongLiftsRequiresAB: return "StrongLifts requires Workout A and Workout B."; case .strongLiftsRequiresTrainingDays: return "Select at least one non-rest training day." }
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
            restDaySection
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
            if program.workouts[index].exercises.isEmpty {
                Label("No exercises yet", systemImage: "square.stack.3d.up")
                    .foregroundStyle(.secondary)
                Button { program.addExercise(to: index) } label: {
                    Label("Add exercise", systemImage: "plus.circle.fill")
                }
            } else {
                ForEach(program.workouts[index].exercises.indices, id: \.self) { exerciseIndex in
                    VStack(alignment: .leading) {
                        TextField("Exercise name", text: Binding(get: { program.workouts[index].exercises[exerciseIndex].name }, set: { program.workouts[index].exercises[exerciseIndex].name = $0 }))
                        HStack {
                            Stepper("Sets: \(program.workouts[index].exercises[exerciseIndex].targetSets)", value: Binding(get: { program.workouts[index].exercises[exerciseIndex].targetSets }, set: { program.workouts[index].exercises[exerciseIndex].targetSets = max(1, $0) }), in: 1...20)
                            Stepper("Reps: \(program.workouts[index].exercises[exerciseIndex].targetReps)", value: Binding(get: { program.workouts[index].exercises[exerciseIndex].targetReps }, set: { program.workouts[index].exercises[exerciseIndex].targetReps = max(1, $0) }), in: 1...100)
                        }.font(.caption)
                    }
                }
                Button { program.addExercise(to: index) } label: {
                    Label("Add exercise", systemImage: "plus.circle.fill")
                }
            }
            if program.kind == .atg && program.workouts[index].exercises.count > 1 { Button("Remove last exercise", role: .destructive) { program.workouts[index].exercises.removeLast() } }
        } header: { Text(program.kind == .strongLifts ? "Workout \(program.workouts[index].identity ?? "")" : program.workouts[index].name) }
    }

    private var restDaySection: some View {
        Section("Rest days") {
            dayButtons(selection: Binding(
                get: { program.restDays },
                set: { program.restDays = $0.sorted() }
            ), onToggle: { day in program.toggleRestDay(day) })
            Text("Rest days appear in Next Up and never create a workout.")
                .font(.caption).foregroundStyle(.secondary)
        }
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

    private func dayButtons(selection: Binding<[TrainingDay]>, onToggle: ((TrainingDay) -> Void)? = nil) -> some View {
        HStack { ForEach(TrainingDay.allCases) { day in
            Button(day.shortName) {
                if let onToggle { onToggle(day) }
                else if selection.wrappedValue.contains(day) { selection.wrappedValue.removeAll { $0 == day } }
                else { selection.wrappedValue.append(day) }
            }.buttonStyle(.bordered).tint(selection.wrappedValue.contains(day) ? .accentColor : .gray)
        }}
    }

    private func editorMessage(_ error: ProgramValidationError) -> String {
        switch error { case .atgRequiresThreeToFiveDays: return "ATG requires 3–5 selected training days."; case .strongLiftsAlternation: return "Choose alternating A/B days."; case .strongLiftsRequiresAB: return "StrongLifts A/B identity is required."; case .strongLiftsRequiresTrainingDays: return "Select at least one non-rest training day." }
    }
}
