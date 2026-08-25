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
        if createOrUpdateProgram {
            let programs: [Program] = preview.sourceKind == .atgCSV
                ? ATGProgramPlanner.placeholderPrograms(from: ATGProgramPlanner.assignPrograms(to: preview.workoutSessions))
                : (ImportToProgramInference.infer(from: preview.workoutSessions, sourceKind: preview.sourceKind).map { [$0.program] } ?? [])
            var results: [ImportProgramCommitResult] = []
            for program in programs {
                let result = programsRepository.upsertGenerated(program)
                results.append(ImportProgramCommitResult(name: program.name, status: result.inserted ? "Created" : "Updated", needsScheduleEditing: program.kind == .atg && !(3...5).contains(program.selectedTrainingDays.count)))
            }
            if !results.isEmpty {
                summary.programResult = ImportProgramCommitResult(name: results.map(\.name).joined(separator: ", "), status: results.map(\.status).joined(separator: "/"), needsScheduleEditing: results.contains { $0.needsScheduleEditing })
            }
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
