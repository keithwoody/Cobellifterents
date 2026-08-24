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

    var groupedSets: [(exerciseID: String, name: String, sets: [WorkoutSetRecord])] {
        let groups = Dictionary(grouping: session.sets, by: \.exerciseID)
        return groups.values.compactMap { sets in
            guard let first = sets.first else { return nil }
            return (first.exerciseID, first.exerciseName, sets.sorted { $0.setNumber < $1.setNumber })
        }
        .sorted { $0.name < $1.name }
    }

    var body: some View {
        List {
            ForEach(groupedSets, id: \.exerciseID) { group in
                Section(group.name) {
                    ForEach(group.sets) { set in
                        HStack {
                            Button {
                                toggle(set)
                            } label: {
                                Image(systemName: set.isComplete ? "checkmark.circle.fill" : "circle")
                            }
                            .buttonStyle(.plain)

                            Text("Set \(set.setNumber)")
                            Spacer()
                            Stepper("\(set.completedReps)/\(set.targetReps) reps", value: $session.sets[session.sets.firstIndex(where: { $0.id == set.id })!].completedReps, in: 0...20)
                                .labelsHidden()
                            Text("\(Int(set.weight)) lb")
                                .monospacedDigit()
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

    private func toggle(_ set: WorkoutSetRecord) {
        set.isComplete.toggle()
        set.completedReps = set.isComplete ? set.targetReps : 0
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [WorkoutSession.self, WorkoutSetRecord.self, ImportedRawRecord.self], inMemory: true)
}
