import Foundation
import SwiftData

struct ImportCommitSummary: Equatable {
    var insertedRawRecords: Int
    var skippedRawRecords: Int
    var insertedWorkoutSessions: Int
    var skippedWorkoutSessions: Int
}

enum ImportCommitter {
    static func commit(_ preview: ImportPreview, into modelContext: ModelContext) throws -> ImportCommitSummary {
        var summary = ImportCommitSummary(insertedRawRecords: 0, skippedRawRecords: 0, insertedWorkoutSessions: 0, skippedWorkoutSessions: 0)

        for rawDraft in preview.rawRecords {
            if try rawRecordExists(rawDraft.sourceRecordID, in: modelContext) {
                summary.skippedRawRecords += 1
            } else {
                modelContext.insert(WorkoutImportMapper.importedRawRecord(from: rawDraft))
                summary.insertedRawRecords += 1
            }
        }

        for sessionDraft in preview.workoutSessions {
            if try workoutSessionExists(sessionDraft.sourceRecordID, in: modelContext) {
                summary.skippedWorkoutSessions += 1
            } else {
                modelContext.insert(WorkoutImportMapper.importedSession(from: sessionDraft))
                summary.insertedWorkoutSessions += 1
            }
        }

        try modelContext.save()
        return summary
    }

    private static func rawRecordExists(_ sourceRecordID: String, in modelContext: ModelContext) throws -> Bool {
        var descriptor = FetchDescriptor<ImportedRawRecord>(predicate: #Predicate { record in
            record.sourceRecordID == sourceRecordID
        })
        descriptor.fetchLimit = 1
        return try !modelContext.fetch(descriptor).isEmpty
    }

    private static func workoutSessionExists(_ sourceRecordID: String, in modelContext: ModelContext) throws -> Bool {
        var descriptor = FetchDescriptor<WorkoutSession>(predicate: #Predicate { session in
            session.importSourceRecordID == sourceRecordID
        })
        descriptor.fetchLimit = 1
        return try !modelContext.fetch(descriptor).isEmpty
    }
}
