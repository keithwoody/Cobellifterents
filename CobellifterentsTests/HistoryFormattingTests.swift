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
}