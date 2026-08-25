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
    @State private var filterByDate = false
    @State private var startDate = Calendar.current.date(from: DateComponents(year: 2024, month: 1, day: 1)) ?? Date()
    @State private var endDate = Date()
    @State private var selectedCSV: String?
    @State private var programs: [Program] = []
    @State private var selectedSessionIDs: Set<UUID> = []
    @State private var showingBulkConfirmation = false
    @State private var bulkProgram: Program?
    @State private var assignmentError: String?
    private let programsRepository = ProgramsRepository()

    private var selectedSessions: [WorkoutSession] {
        importedSessions.filter { selectedSessionIDs.contains($0.id) }
    }

    private func program(for session: WorkoutSession) -> Program? {
        WorkoutProgramAssignment.program(for: session, in: programs)
    }

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
                if selectedSourceKind == .atgCSV {
                    Toggle("Limit import to date range", isOn: $filterByDate)
                    if filterByDate {
                        DatePicker("Start date", selection: $startDate, displayedComponents: .date)
                        DatePicker("End date", selection: $endDate, in: startDate..., displayedComponents: .date)
                    }
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
                                Text(session.programAssignment == .unassignedAmbiguous ? "Program assignment needed" : session.programAssignment.displayName)
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

            Section("Imported workout Programs") {
                if !selectedSessions.isEmpty {
                    Text("\(selectedSessions.count) selected")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Menu("Assign selected") {
                        ForEach(programs.filter(\.isValid)) { program in
                            Button(program.name) {
                                bulkProgram = program
                                showingBulkConfirmation = true
                            }
                        }
                        Button("Clear assignments", role: .destructive) {
                            bulkProgram = nil
                            showingBulkConfirmation = true
                        }
                    }
                    Button("Clear selection") { selectedSessionIDs.removeAll() }
                }
                ForEach(importedSessions) { session in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: selectedSessionIDs.contains(session.id) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(selectedSessionIDs.contains(session.id) ? .blue : .secondary)
                            Text(session.templateName).bold()
                            Spacer()
                            Text(WorkoutProgramPresentation.name(for: session, programs: programs))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if selectedSessionIDs.contains(session.id) { selectedSessionIDs.remove(session.id) }
                            else { selectedSessionIDs.insert(session.id) }
                        }
                        Picker("Program", selection: Binding<UUID?>(
                            get: { program(for: session)?.id },
                            set: { value in update(session, programID: value) })) {
                            Text("Unassigned").tag(nil as UUID?)
                            ForEach(programs.filter(\.isValid)) { program in Text(program.name).tag(program.id as UUID?) }
                        }
                        .pickerStyle(.menu)
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
        .onChange(of: startDate) { _, _ in rebuildATGPreview() }
        .onChange(of: endDate) { _, _ in rebuildATGPreview() }
        .onChange(of: filterByDate) { _, _ in rebuildATGPreview() }
        .onAppear { programs = programsRepository.load() }
        .alert("Program assignment", isPresented: Binding(get: { assignmentError != nil }, set: { if !$0 { assignmentError = nil } })) {
            Button("OK") { assignmentError = nil }
        } message: { Text(assignmentError ?? "") }
        .confirmationDialog("Change \(selectedSessions.count) workout assignments?", isPresented: $showingBulkConfirmation, titleVisibility: .visible) {
            Button("Confirm", role: bulkProgram == nil ? .destructive : nil) { applyBulkAssignment() }
            Button("Cancel", role: .cancel) { }
        } message: { Text("Imported data, provenance, and exercises will be preserved.") }
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
            selectedCSV = csv
            selectedFileName = url.lastPathComponent
            switch selectedSourceKind {
            case .strongLiftsCSV:
                preview = CSVWorkoutImporter.previewStrongLiftsCSV(csv, sourceFileName: url.lastPathComponent)
            case .atgCSV:
                preview = CSVWorkoutImporter.previewATGCSV(csv, sourceFileName: url.lastPathComponent, startDate: filterByDate ? startDate : nil, endDate: filterByDate ? endDate : nil)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func commitPreview() {
        guard let preview else { return }
        do {
            commitSummary = try ImportCommitter.commit(preview, into: modelContext, createOrUpdateProgram: createOrUpdateProgram)
            programs = programsRepository.load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func rebuildATGPreview() {
        guard selectedSourceKind == .atgCSV, let selectedCSV, let selectedFileName else { return }
        preview = CSVWorkoutImporter.previewATGCSV(selectedCSV, sourceFileName: selectedFileName, startDate: filterByDate ? startDate : nil, endDate: filterByDate ? Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: endDate) : nil)
    }

    private func update(_ session: WorkoutSession, programID: UUID?) {
        do {
            if let programID, let program = programs.first(where: { $0.id == programID }) {
                _ = try WorkoutProgramAssignment.assign(session, to: program, in: modelContext)
            } else {
                _ = try WorkoutProgramAssignment.clear(session, in: modelContext)
            }
        } catch {
            assignmentError = error.localizedDescription
        }
    }

    private func applyBulkAssignment() {
        do {
            if let bulkProgram {
                _ = try WorkoutProgramAssignment.assign(selectedSessions, to: bulkProgram, in: modelContext)
            } else {
                _ = try WorkoutProgramAssignment.clear(selectedSessions, in: modelContext)
            }
            selectedSessionIDs.removeAll()
        } catch {
            assignmentError = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack { ImportView() }
        .modelContainer(for: [WorkoutSession.self, WorkoutSetRecord.self, ImportedRawRecord.self], inMemory: true)
}
