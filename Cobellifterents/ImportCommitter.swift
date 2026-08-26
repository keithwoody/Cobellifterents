import Foundation
import SwiftData

struct ImportProgramCommitResult: Equatable {
    let name: String
    let status: String
    let needsScheduleEditing: Bool
}

struct ImportCommitSummary: Equatable {
    var insertedRawRecords: Int
    var skippedRawRecords: Int
    var insertedWorkoutSessions: Int
    var skippedWorkoutSessions: Int
    var programResult: ImportProgramCommitResult?
}

enum ImportCommitter {
    static func commit(_ preview: ImportPreview, into modelContext: ModelContext, programsRepository: ProgramsRepository = ProgramsRepository(), createOrUpdateProgram: Bool = true) throws -> ImportCommitSummary {
        var summary = ImportCommitSummary(insertedRawRecords: 0, skippedRawRecords: 0, insertedWorkoutSessions: 0, skippedWorkoutSessions: 0, programResult: nil)
        let generatedPrograms: [Program]
        if createOrUpdateProgram {
            let plannedPrograms: [Program] = preview.sourceKind == .atgCSV
                ? ATGProgramPlanner.placeholderPrograms(from: ATGProgramPlanner.assignPrograms(to: preview.workoutSessions))
                : (ImportToProgramInference.infer(from: preview.workoutSessions, sourceKind: preview.sourceKind).map { [$0.program] } ?? [])
            var resolvedPrograms: [Program] = []
            var results: [ImportProgramCommitResult] = []
            for program in plannedPrograms {
                let upserted = programsRepository.upsertGenerated(program)
                if let resolved = upserted.programs.first(where: { $0.generatedSourceKey == program.generatedSourceKey }) {
                    resolvedPrograms.append(resolved)
                }
                results.append(ImportProgramCommitResult(name: program.name, status: upserted.inserted ? "Created" : "Updated", needsScheduleEditing: program.kind == .atg && !(3...5).contains(program.selectedTrainingDays.count)))
            }
            generatedPrograms = resolvedPrograms
            if !results.isEmpty {
                summary.programResult = ImportProgramCommitResult(name: results.map(\.name).joined(separator: ", "), status: results.map(\.status).joined(separator: "/"), needsScheduleEditing: results.contains { $0.needsScheduleEditing })
            }
        } else {
            generatedPrograms = []
        }
        let generatedProgramIDs = Dictionary(uniqueKeysWithValues: generatedPrograms.compactMap { program -> (String, UUID)? in
            guard let sourceKey = program.generatedSourceKey else { return nil }
            return (sourceKey, program.id)
        })
        let assignmentIDs = Dictionary(uniqueKeysWithValues: generatedPrograms.compactMap { program -> (ImportProgramAssignment, UUID)? in
            guard let sourceKey = program.generatedSourceKey,
                  let assignmentRawValue = sourceKey.split(separator: ":").dropFirst().first,
                  let assignment = ImportProgramAssignment(rawValue: String(assignmentRawValue)) else { return nil }
            return (assignment, program.id)
        })
        for rawDraft in preview.rawRecords {
            if try rawRecordExists(rawDraft.sourceRecordID, in: modelContext) { summary.skippedRawRecords += 1 }
            else { modelContext.insert(WorkoutImportMapper.importedRawRecord(from: rawDraft)); summary.insertedRawRecords += 1 }
        }
        for sessionDraft in preview.workoutSessions {
            let generatedProgramID = generatedProgramIDs[ImportToProgramInference.generatedSourceKey(for: sessionDraft)]
            let assignedProgramID = generatedProgramID ?? assignmentIDs[sessionDraft.programAssignment]
            let assignedProgramName = generatedProgramID.flatMap { id in generatedPrograms.first { $0.id == id }?.name }
            if let existing = try workoutSession(sessionDraft.sourceRecordID, in: modelContext) {
                summary.skippedWorkoutSessions += 1
                // Re-running an import may be the first run after this repair. Fill
                // only an absent generated assignment so a later manual choice wins.
                if existing.programAssignmentID == nil,
                   let assignedProgramID {
                    existing.programAssignmentID = assignedProgramID
                    existing.programAssignmentRawValue = assignedProgramName ?? sessionDraft.programAssignment.rawValue
                    existing.programAssignmentEvidence = assignedProgramName == nil ? sessionDraft.programAssignmentEvidence : "Generated from imported source"
                }
            } else {
                let session = WorkoutImportMapper.importedSession(from: sessionDraft, programAssignmentID: assignedProgramID)
                if let assignedProgramName {
                    session.programAssignmentRawValue = assignedProgramName
                    session.programAssignmentEvidence = "Generated from imported source"
                }
                modelContext.insert(session)
                summary.insertedWorkoutSessions += 1
            }
        }
        try modelContext.save()
        return summary
    }

    private static func rawRecordExists(_ id: String, in context: ModelContext) throws -> Bool {
        var descriptor = FetchDescriptor<ImportedRawRecord>(predicate: #Predicate { $0.sourceRecordID == id }); descriptor.fetchLimit = 1
        return try !context.fetch(descriptor).isEmpty
    }
    private static func workoutSession(_ id: String, in context: ModelContext) throws -> WorkoutSession? {
        var descriptor = FetchDescriptor<WorkoutSession>(predicate: #Predicate { $0.importSourceRecordID == id }); descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}
