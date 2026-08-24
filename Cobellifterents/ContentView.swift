import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var sessions: [WorkoutSession]
    @State private var activeSession: WorkoutSession?

    private var nextTemplate: WorkoutTemplate {
        StrongLiftsTemplates.template(after: sessions.first(where: { $0.isComplete })?.templateID)
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
                if activeSession != nil {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel") { activeSession = nil }
                    }
                }
            }
        }
        .onAppear {
            activeSession = sessions.first(where: { !$0.isComplete })
        }
    }

    private var startView: some View {
        List {
            Section("Next up") {
                VStack(alignment: .leading, spacing: 8) {
                    Text(nextTemplate.name).font(.title2).bold()
                    ForEach(nextTemplate.exercises) { exercise in
                        Text("\(exercise.name): \(exercise.targetSets)x\(exercise.targetReps)")
                            .foregroundStyle(.secondary)
                    }
                }
                Button("Start \(nextTemplate.name)") { startWorkout() }
                    .buttonStyle(.borderedProminent)
            }

            Section("Recent history") {
                if sessions.isEmpty {
                    ContentUnavailableView("No workouts yet", systemImage: "figure.strengthtraining.traditional", description: Text("Start Workout A to create the first StrongLifts-style log."))
                } else {
                    ForEach(sessions) { session in
                        VStack(alignment: .leading) {
                            Text(session.templateName).bold()
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
        }
    }

    private func startWorkout() {
        let session = WorkoutSession.seeded(from: nextTemplate, history: sessions)
        modelContext.insert(session)
        try? modelContext.save()
        activeSession = session
    }

    private func complete(_ session: WorkoutSession) {
        session.completedAt = Date()
        try? modelContext.save()
        activeSession = nil
    }
}

struct WorkoutLoggingView: View {
    @Bindable var session: WorkoutSession
    let onComplete: () -> Void

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

            ForEach(groupedSets, id: \.exerciseID) { group in
                Section(group.name) {
                    ForEach(group.sets) { set in
                        StrongLiftsSetRow(set: set)
                    }
                }
            }

            Button("Finish Workout") { onComplete() }
                .buttonStyle(.borderedProminent)
                .disabled(!session.sets.allSatisfy(\.isComplete))
        }
        .navigationTitle(session.templateName)
    }
}

struct StrongLiftsSetRow: View {
    @Bindable var set: WorkoutSetRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Button {
                    toggleComplete()
                } label: {
                    Label(set.isComplete ? "Complete" : "Mark complete", systemImage: set.isComplete ? "checkmark.circle.fill" : "circle")
                        .labelStyle(.iconOnly)
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .foregroundStyle(set.isComplete ? .green : .secondary)
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
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [WorkoutSession.self, WorkoutSetRecord.self, ImportedRawRecord.self], inMemory: true)
}
