import XCTest
@testable import Cobellifterents

final class HistoryFormattingTests: XCTestCase {
    func testSetOutcomeIncludesCompletedAndTargetRepsAndWeight() {
        XCTAssertEqual(HistoryFormatting.setOutcome(completedReps: 4, targetReps: 5, weight: 135), "4/5 reps · 135 lb")
    }

    func testWeightFormatsWholeAndFractionalPounds() {
        XCTAssertEqual(HistoryFormatting.weight(45), "45 lb")
        XCTAssertEqual(HistoryFormatting.weight(47.5), "47.5 lb")
    }

    func testSourceLabelMakesKnownImportSourcesReadable() {
        XCTAssertEqual(HistoryFormatting.sourceLabel("strongLiftsCSV"), "StrongLifts CSV")
        XCTAssertEqual(HistoryFormatting.sourceLabel("other"), "other")
    }

    func testRecentCompletedSessionsLimitsToFiveAndExcludesInProgressSessions() {
        var sessions: [WorkoutSession] = []
        for index in 0..<7 {
            let completedAt: Date? = index == 1 ? nil : Date(timeIntervalSince1970: Double(index + 100))
            sessions.append(WorkoutSession(
                templateID: .strongLiftsA,
                templateName: "Workout A",
                startedAt: Date(timeIntervalSince1970: Double(index)),
                completedAt: completedAt
            ))
        }

        let recent = HistoryFormatting.recentCompletedSessions(from: sessions)

        XCTAssertEqual(recent.count, 5)
        XCTAssertTrue(recent.allSatisfy { $0.isComplete })
        XCTAssertFalse(recent.contains(where: { $0.startedAt == sessions[1].startedAt }))
    }

    func testRecentCompletedSessionsReturnsEmptyForNonPositiveLimit() {
        let session = WorkoutSession(templateID: .strongLiftsA, templateName: "Workout A", completedAt: Date())

        XCTAssertTrue(HistoryFormatting.recentCompletedSessions(from: [session], limit: 0).isEmpty)
    }

    func testFullHistoryLinkIsShownWhenOnlyIncompleteSessionsExist() {
        let session = WorkoutSession(templateID: .strongLiftsA, templateName: "Workout A")

        XCTAssertTrue(HistoryFormatting.shouldShowFullHistoryLink(for: [session]))
        XCTAssertFalse(HistoryFormatting.shouldShowFullHistoryLink(for: []))
    }
}