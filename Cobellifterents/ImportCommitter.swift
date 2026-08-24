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
        for rawDraft in preview.rawRecords {
            if try rawRecordExists(rawDraft.sourceRecordID, in: modelContext) { summary.skippedRawRecords += 1 }
            else { modelContext.insert(WorkoutImportMapper.importedRawRecord(from: rawDraft)); summary.insertedRawRecords += 1 }
        }
        for sessionDraft in preview.workoutSessions {
            if try workoutSessionExists(sessionDraft.sourceRecordID, in: modelContext) { summary.skippedWorkoutSessions += 1 }
            else { modelContext.insert(WorkoutImportMapper.importedSession(from: sessionDraft)); summary.insertedWorkoutSessions += 1 }
        }
        try modelContext.save()
        if createOrUpdateProgram, let inferred = ImportToProgramInference.infer(from: preview.workoutSessions, sourceKind: preview.sourceKind) {
            let result = programsRepository.upsertGenerated(inferred.program)
            summary.programResult = ImportProgramCommitResult(name: inferred.program.name, status: result.inserted ? "Created" : "Updated", needsScheduleEditing: inferred.needsScheduleEditing)
        }
        return summary
    }

    private static func rawRecordExists(_ id: String, in context: ModelContext) throws -> Bool {
        var descriptor = FetchDescriptor<ImportedRawRecord>(predicate: #Predicate { $0.sourceRecordID == id }); descriptor.fetchLimit = 1
        return try !context.fetch(descriptor).isEmpty
    }
    private static func workoutSessionExists(_ id: String, in context: ModelContext) throws -> Bool {
        var descriptor = FetchDescriptor<WorkoutSession>(predicate: #Predicate { $0.importSourceRecordID == id }); descriptor.fetchLimit = 1
        return try !context.fetch(descriptor).isEmpty
    }
}
