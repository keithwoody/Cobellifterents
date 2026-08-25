import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct ImportView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var rawRecords: [ImportedRawRecord]
    @Query(filter: #Predicate<WorkoutSession> { session in session.importSourceRecordID != nil }) private var importedSessions: [WorkoutSession]

    @State private var selectedSourceKind: ImportSourceKind = .strongLiftsCSV
    @State private var preview: ImportPreview?
    @State private var selectedFileName: String?
    @State private var errorMessage: String?
    @State private var commitSummary: ImportCommitSummary?
    @State private var isFileImporterPresented = false
    @State private var createOrUpdateProgram = true

    var body: some View {
        List {
            Section("Source") {
                Picker("Format", selection: $selectedSourceKind) {
                    Text("StrongLifts CSV").tag(ImportSourceKind.strongLiftsCSV)
                    Text("ATG CSV").tag(ImportSourceKind.atgCSV)
                }
                Button("Choose CSV") { isFileImporterPresented = true }
                if let selectedFileName {
                    Text(selectedFileName).foregroundStyle(.secondary)
                }
            }

            if let preview {
                Section("Preview") {
                    LabeledContent("Raw rows", value: preview.rawRecords.count.formatted())
                    LabeledContent("Native sessions", value: preview.workoutSessions.count.formatted())
                    LabeledContent("Issues", value: preview.issues.count.formatted())
                    Toggle("Create or update a program from this import", isOn: $createOrUpdateProgram)
                        .disabled(preview.workoutSessions.isEmpty)
                    if preview.workoutSessions.isEmpty { Text("No native sessions found; no program will be created.").font(.caption).foregroundStyle(.secondary) }
                    if let first = preview.workoutSessions.first, let last = preview.workoutSessions.last {
                        LabeledContent("Date range") {
                            Text("\(first.startedAt.formatted(date: .abbreviated, time: .omitted)) – \(last.startedAt.formatted(date: .abbreviated, time: .omitted))")
                        }
                    }
                    Button("Import Previewed Data") { commitPreview() }
                        .buttonStyle(.borderedProminent)
                }

                if !preview.issues.isEmpty {
                    Section("Issues") {
                        ForEach(Array(preview.issues.prefix(25).enumerated()), id: \.offset) { _, issue in
                            VStack(alignment: .leading) {
                                Text("Row \(issue.rowNumber)").bold()
                                Text(issue.message).foregroundStyle(.secondary)
                            }
                        }
                        if preview.issues.count > 25 {
                            Text("\(preview.issues.count - 25) more issues not shown")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Sessions to create") {
                    ForEach(Array(preview.workoutSessions.prefix(25).enumerated()), id: \.element.sourceRecordID) { _, session in
                        VStack(alignment: .leading) {
                            Text(session.templateName).bold()
                            Text(session.startedAt.formatted(date: .abbreviated, time: .shortened))
                            if preview.sourceKind == .atgCSV {
                                Text(session.programAssignment.displayName)
                                    .font(.caption)
                                    .foregroundStyle(session.programAssignment == .unassignedAmbiguous ? .orange : .secondary)
                            }
                            Text("\(session.sets.count) sets")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if preview.workoutSessions.count > 25 {
                        Text("\(preview.workoutSessions.count - 25) more sessions not shown")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let commitSummary {
                Section("Last import") {
                    LabeledContent("Inserted raw rows", value: commitSummary.insertedRawRecords.formatted())
                    LabeledContent("Skipped raw rows", value: commitSummary.skippedRawRecords.formatted())
                    LabeledContent("Inserted sessions", value: commitSummary.insertedWorkoutSessions.formatted())
                    LabeledContent("Skipped sessions", value: commitSummary.skippedWorkoutSessions.formatted())
                    if let result = commitSummary.programResult {
                        LabeledContent("Program", value: result.name)
                        Text(result.needsScheduleEditing ? "\(result.status): edit the schedule to select 3–5 days." : "\(result.status) and ready to use.")
                            .font(.caption).foregroundStyle(result.needsScheduleEditing ? .orange : .secondary)
                    }
                }
            }

            Section("Imported totals") {
                LabeledContent("Raw provenance records", value: rawRecords.count.formatted())
                LabeledContent("Imported sessions", value: importedSessions.count.formatted())
            }

            if let errorMessage {
                Section("Error") {
                    Text(errorMessage).foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Import")
        .fileImporter(
            isPresented: $isFileImporterPresented,
            allowedContentTypes: [.commaSeparatedText, .plainText, UTType(filenameExtension: "csv")!],
            allowsMultipleSelection: false,
            onCompletion: handleFileImport
        )
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        errorMessage = nil
        commitSummary = nil

        do {
            guard let url = try result.get().first else { return }
            let didStartAccessing = url.startAccessingSecurityScopedResource()
            defer {
                if didStartAccessing { url.stopAccessingSecurityScopedResource() }
            }
            let csv = try String(contentsOf: url, encoding: .utf8)
            selectedFileName = url.lastPathComponent
            switch selectedSourceKind {
            case .strongLiftsCSV:
                preview = CSVWorkoutImporter.previewStrongLiftsCSV(csv, sourceFileName: url.lastPathComponent)
            case .atgCSV:
                preview = CSVWorkoutImporter.previewATGCSV(csv, sourceFileName: url.lastPathComponent)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func commitPreview() {
        guard let preview else { return }
        do {
            commitSummary = try ImportCommitter.commit(preview, into: modelContext, createOrUpdateProgram: createOrUpdateProgram)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack { ImportView() }
        .modelContainer(for: [WorkoutSession.self, WorkoutSetRecord.self, ImportedRawRecord.self], inMemory: true)
}
