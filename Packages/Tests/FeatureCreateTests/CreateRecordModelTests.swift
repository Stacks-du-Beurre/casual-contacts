import Testing
import Foundation
import CoreModels
@testable import FeatureCreate

@MainActor
@Suite struct CreateRecordModelTests {

    @Test func emptyFormIsNotSaveable() {
        let model = CreateRecordModel()
        #expect(!model.isSaveable)
    }

    @Test func whitespaceOnlyNameIsNotSaveable() {
        let model = CreateRecordModel()
        model.name = "   "
        #expect(!model.isSaveable)
    }

    @Test func nonEmptyNameIsSaveable() {
        let model = CreateRecordModel()
        model.name = "Jane"
        #expect(model.isSaveable)
    }

    @Test func previewReflectsCurrentName() {
        let model = CreateRecordModel()
        model.name = "Alex"
        #expect(model.previewRecord.name == "Alex")
    }

    @Test func draftContainsAllFields() {
        let model = CreateRecordModel()
        model.name = "Jane"
        model.description = "Met at cafe"
        model.zodiacSign = .virgo
        let draft = model.draft
        #expect(draft.name == "Jane")
        #expect(draft.description == "Met at cafe")
        #expect(draft.zodiacSign == .virgo)
    }
}
