import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var sessions: [WorkoutSession]
    @State private var activeSession: WorkoutSession?
    @State private var programs: [Program] = []
    @State private var activeSelection = ActiveProgramSelection()
    private let programsRepository = ProgramsRepository()
    private let progressionSettingsRepository = ProgressionSettingsRepository()

    private var activeStrongLiftsProgram: Program? {
        programs.first { $0.id == activeSelection.strongLiftsID && $0.kind == .strongLifts && $0.isValid }
    }

    private var selectedProgramWorkout: ProgramWorkout? {
        activeStrongLiftsProgram.flatMap { StrongLiftsProgramSelection.nextWorkout(in: $0, after: sessions) }
    }

    private var nextTemplate: WorkoutTemplate {
        if let selectedProgramWorkout, let activeStrongLiftsProgram,
           let template = ProgramWorkoutConversion.template(from: selectedProgramWorkout, programName: activeStrongLiftsProgram.name) {
            return template
        }
        return StrongLiftsTemplates.template(after: sessions.first(where: { $0.isComplete })?.templateID)
    }

    private var isEmptySelectedCustomWorkout: Bool {
        HomeWorkoutLogic.shouldDisableStart(selectedProgramWorkout: selectedProgramWorkout, template: nextTemplate)
    }

    private var upcomingEntries: [UpcomingScheduleEntry] {
        UpcomingSchedule.entries(
            strongLifts: activeStrongLiftsProgram ?? Program.strongLiftsDefault,
            atg: programs.first { $0.id == activeSelection.atgID && $0.kind == .atg && $0.isValid },
            completedSessions: sessions
        )
    }

    private var nextWorkoutDisplayName: String {
        WorkoutDisplayNaming.displayName(
            programName: activeStrongLiftsProgram?.name,
            workoutName: nextTemplate.name,
            templateID: nextTemplate.id
        )
    }

    private var recentCompletedSessions: [WorkoutSession] {
        HistoryFormatting.recentCompletedSessions(from: sessions)
    }

    var body: some View {
        NavigationStack {
            Group {
                if let activeSession {
                    WorkoutLoggingView(session: activeSession) {
                        complete(activeSession)
                    }
                } else {
                    startView
                }
            }
            .navigationTitle("Cobellifterents")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink("Import") { ImportView() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink("Progression") { ProgressionSettingsView() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink("Programs") { ProgramsView() }
                }
                if activeSession != nil {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel") { activeSession = nil }
                    }
                }
            }
        }
        .onAppear {
            refreshPrograms()
            activeSession = WorkoutSessionRecovery.resumableSession(from: sessions)
        }
    }

    private var startView: some View {
        List {
            Section("Next up") {
                ForEach(upcomingEntries) { entry in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.date, format: .dateTime.weekday(.wide).month(.abbreviated).day())
                            .font(.headline)
                        if entry.kind == .rest {
                            Label("Rest day", systemImage: "bed.double.fill")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(entry.workoutNames, id: \.self) { workoutName in
                                Label(workoutName, systemImage: "figure.strengthtraining.traditional")
                            }
                        }
                    }
                    .accessibilityElement(children: .combine)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Start \(nextWorkoutDisplayName)")
                    .font(.title2)
                    .bold()
                    if isEmptySelectedCustomWorkout {
                        Label("This workout has no exercises. Go to Programs to add exercises.", systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                    } else {
                        ForEach(nextTemplate.exercises) { exercise in
                            Text("\(exercise.name): \(exercise.targetSets)x\(exercise.targetReps)")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Button("Start Workout") { startWorkout() }
                    .buttonStyle(.borderedProminent)
                    .disabled(isEmptySelectedCustomWorkout)
            }

            Section("Recent history") {
                if recentCompletedSessions.isEmpty {
                    ContentUnavailableView("No workouts yet", systemImage: "figure.strengthtraining.traditional", description: Text("Start Workout A to create the first StrongLifts-style log."))
                } else {
                    ForEach(recentCompletedSessions) { session in
                        NavigationLink {
                            WorkoutHistoryDetailView(session: session)
                        } label: {
                            VStack(alignment: .leading) {
                                Text(WorkoutDisplayNaming.displayName(for: session)).bold()
                                Text(session.startedAt, style: .date)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                HStack {
                                    if let assignment = session.programAssignmentRawValue, session.programAssignmentID != nil {
                                        Text(assignment)
                                            .font(.caption)
                                            .foregroundStyle(.purple)
                                    }
                                    Text(session.isComplete ? "Complete" : "In progress")
                                        .font(.caption)
                                        .foregroundStyle(session.isComplete ? .green : .orange)
                                    if session.isImported {
                                        Text("Imported")
                                            .font(.caption)
                                            .foregroundStyle(.blue)
                                    }
                                }
                            }
                        }
                    }
                }
                if HistoryFormatting.shouldShowFullHistoryLink(for: sessions) {
                    NavigationLink("View full history") {
                        WorkoutHistoryView()
                    }
                }
            }
        }
        .onAppear { refreshPrograms() }
    }

    private func startWorkout() {
        guard !isEmptySelectedCustomWorkout else { return }
        let session = WorkoutSession.seeded(
            from: nextTemplate,
            history: sessions,
            settings: progressionSettingsRepository.hasCustomSettings ? progressionSettingsRepository.load() : nil
        )
        modelContext.insert(session)
        try? modelContext.save()
        activeSession = session
    }

    private func complete(_ session: WorkoutSession) {
        session.completedAt = Date()
        try? modelContext.save()
        activeSession = nil
    }

    private func refreshPrograms() {
        programs = programsRepository.load()
        activeSelection = programsRepository.loadActiveSelection(for: programs)
    }
}

private struct WorkoutHistoryRow: View {
    let session: WorkoutSession

    var body: some View {
        NavigationLink {
            WorkoutHistoryDetailView(session: session)
        } label: {
            VStack(alignment: .leading) {
                Text(WorkoutDisplayNaming.displayName(for: session)).bold()
                Text(session.startedAt, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    Text(session.isComplete ? "Complete" : "In progress")
                        .font(.caption)
                        .foregroundStyle(session.isComplete ? .green : .orange)
                    if session.isImported {
                        Text("Imported")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                }
            }
        }
    }
}

struct WorkoutHistoryView: View {
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var sessions: [WorkoutSession]

    var body: some View {
        List {
            if sessions.isEmpty {
                ContentUnavailableView("No workouts yet", systemImage: "figure.strengthtraining.traditional")
            } else {
                ForEach(sessions) { session in
                    WorkoutHistoryRow(session: session)
                }
            }
        }
        .navigationTitle("Workout History")
    }
}

struct WorkoutHistoryDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let session: WorkoutSession
    @State private var showingDeleteConfirmation = false

    private var exerciseGroups: [(id: String, name: String, sets: [WorkoutSetRecord])] {
        let templateOrder = Dictionary(
            uniqueKeysWithValues: (session.templateID.flatMap { id in StrongLiftsTemplates.all.first { $0.id == id } }?.exercises ?? [])
                .enumerated()
                .map { ($0.element.id, $0.offset) }
        )
        return Dictionary(grouping: session.sets, by: \.exerciseID)
            .compactMap { id, sets in
                guard let first = sets.first else { return nil }
                return (id, first.exerciseName, sets.sorted { $0.setNumber < $1.setNumber })
            }
            .sorted {
                let leftOrder = templateOrder[$0.id] ?? $0.sets.compactMap(\.displayOrder).min() ?? Int.max
                let rightOrder = templateOrder[$1.id] ?? $1.sets.compactMap(\.displayOrder).min() ?? Int.max
                return leftOrder == rightOrder ? $0.name < $1.name : leftOrder < rightOrder
            }
    }

    var body: some View {
        List {
            Section {
                LabeledContent("Status", value: session.isComplete ? "Complete" : "In progress")
                LabeledContent("Started", value: session.startedAt.formatted(date: .abbreviated, time: .shortened))
                if let assignment = session.programAssignmentRawValue, session.programAssignmentID != nil {
                    LabeledContent("Program", value: assignment)
                } else if session.isImported {
                    LabeledContent("Program", value: "Unassigned")
                }
                if let completedAt = session.completedAt {
                    LabeledContent("Finished", value: completedAt.formatted(date: .abbreviated, time: .shortened))
                }
                if let bodyWeight = session.bodyWeight {
                    LabeledContent("Body weight", value: HistoryFormatting.weight(bodyWeight))
                }
            }

            if session.isImported {
                Section("Import source") {
                    if let sourceKind = session.importSourceKindRawValue {
                        LabeledContent("Source", value: HistoryFormatting.sourceLabel(sourceKind))
                    }
                    if let fileName = session.importSourceFileName {
                        LabeledContent("File", value: fileName)
                    }
                    if let recordID = session.importSourceRecordID {
                        LabeledContent("Record", value: recordID)
                    }
                }
            }

            ForEach(exerciseGroups, id: \.id) { group in
                Section(group.name) {
                    ForEach(group.sets) { set in
                        HStack {
                            Text("Set \(set.setNumber)")
                            Spacer()
                            Text(HistoryFormatting.setOutcome(completedReps: set.completedReps, targetReps: set.targetReps, weight: set.weight))
                                .multilineTextAlignment(.trailing)
                                .monospacedDigit()
                            Image(systemName: set.isComplete ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(set.isComplete ? .green : .secondary)
                        }
                    }
                }
            }

            if let notes = session.notes, !notes.isEmpty {
                Section("Notes") { Text(notes) }
            }
        }
        .navigationTitle(session.templateName)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Delete", role: .destructive) { showingDeleteConfirmation = true }
            }
        }
        .confirmationDialog("Delete this workout?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete Workout", role: .destructive) {
                deleteWorkout()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This removes the workout and all of its sets from history.")
        }
    }

    private func deleteWorkout() {
        for set in session.sets { modelContext.delete(set) }
        modelContext.delete(session)
        try? modelContext.save()
        dismiss()
    }
}

struct WorkoutLoggingView: View {
    @Bindable var session: WorkoutSession
    let onComplete: () -> Void
    @State private var restStartedAt: Date?

    private let restDuration = 90

    var groupedSets: [(exerciseID: String, name: String, displayOrder: Int, sets: [WorkoutSetRecord])] {
        let groups = Dictionary(grouping: session.sets, by: \.exerciseID)
        return groups.values.compactMap { sets in
            guard let first = sets.first else { return nil }
            let displayOrder = sets.compactMap(\.displayOrder).min() ?? Int.max
            return (first.exerciseID, first.exerciseName, displayOrder, sets.sorted { $0.setNumber < $1.setNumber })
        }
        .sorted {
            if $0.displayOrder == $1.displayOrder { return $0.name < $1.name }
            return $0.displayOrder < $1.displayOrder
        }
    }

    var completedSetCount: Int { session.sets.filter(\.isComplete).count }

    var body: some View {
        List {
            Section {
                LabeledContent("Progress", value: "\(completedSetCount)/\(session.sets.count) sets")
                if let started = session.startedAt as Date? {
                    LabeledContent("Started", value: started.formatted(date: .omitted, time: .shortened))
                }
            }

            Section("Workout details") {
                TextField("Body weight (lb)", text: bodyWeightBinding)
                    .keyboardType(.decimalPad)
                TextField("Workout notes", text: notesBinding, axis: .vertical)
                    .lineLimit(2...4)
            }

            Section("Rest timer") {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    HStack {
                        Label(restTimerLabel(at: context.date), systemImage: "timer")
                            .font(.headline)
                        Spacer()
                        Button(restStartedAt == nil ? "Start" : "Restart") {
                            restStartedAt = .now
                        }
                        .buttonStyle(.bordered)
                        if restStartedAt != nil {
                            Button("Clear") { restStartedAt = nil }
                                .buttonStyle(.borderless)
                        }
                    }
                }
            }

            ForEach(groupedSets, id: \.exerciseID) { group in
                Section(group.name) {
                    ForEach(group.sets) { set in
                        StrongLiftsSetRow(set: set) {
                            restStartedAt = .now
                        }
                    }
                }
            }

            Button("Finish Workout") { onComplete() }
                .buttonStyle(.borderedProminent)
                .disabled(!session.sets.allSatisfy(\.isComplete))
        }
        .navigationTitle(session.templateName)
    }

    private var bodyWeightBinding: Binding<String> {
        Binding(
            get: {
                guard let bodyWeight = session.bodyWeight else { return "" }
                return bodyWeight.formatted(.number.precision(.fractionLength(0...1)))
            },
            set: { value in
                session.bodyWeight = Double(value)
            }
        )
    }

    private var notesBinding: Binding<String> {
        Binding(
            get: { session.notes ?? "" },
            set: { session.notes = $0 }
        )
    }

    private func restTimerLabel(at date: Date) -> String {
        guard let restStartedAt else { return "Ready for rest" }
        let elapsed = max(0, Int(date.timeIntervalSince(restStartedAt)))
        let remaining = max(0, restDuration - elapsed)
        return remaining == 0 ? "Rest complete" : "Rest \(remaining)s"
    }
}

struct StrongLiftsSetRow: View {
    @Bindable var set: WorkoutSetRecord
    let onCompleted: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Button {
                    toggleComplete()
                } label: {
                    ZStack {
                        Circle()
                            .fill(set.isComplete ? Color.green : Color.secondary.opacity(0.18))
                        Text("\(set.setNumber)")
                            .font(.headline)
                            .foregroundStyle(set.isComplete ? .white : .primary)
                    }
                    .frame(width: 56, height: 56)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(set.isComplete ? "Mark set incomplete" : "Mark set complete")

                Text("Set \(set.setNumber)")
                    .font(.headline)
                Spacer()
                Text(set.isComplete ? "Done" : "Pending")
                    .font(.caption)
                    .foregroundStyle(set.isComplete ? .green : .secondary)
            }

            HStack(spacing: 16) {
                Stepper(value: $set.completedReps, in: 0...30) {
                    VStack(alignment: .leading) {
                        Text("Reps")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(set.completedReps)/\(set.targetReps)")
                            .monospacedDigit()
                    }
                }

                Stepper(value: $set.weight, in: 0...1_000, step: 5) {
                    VStack(alignment: .leading) {
                        Text("Weight")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(set.weight.formatted(.number.precision(.fractionLength(set.weight.truncatingRemainder(dividingBy: 1) == 0 ? 0 : 1)))) lb")
                            .monospacedDigit()
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .onChange(of: set.completedReps) { _, newValue in
            if newValue < set.targetReps {
                set.isComplete = false
            }
        }
    }

    private func toggleComplete() {
        set.isComplete.toggle()
        if set.isComplete && set.completedReps == 0 {
            set.completedReps = set.targetReps
        }
        if set.isComplete {
            onCompleted()
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [WorkoutSession.self, WorkoutSetRecord.self, ImportedRawRecord.self], inMemory: true)
}
