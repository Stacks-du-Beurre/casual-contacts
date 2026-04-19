import Testing
import Foundation
import CoreModels
@testable import FeatureCreate

@MainActor
@Suite struct CreateRecordModelTests {

    private let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)
    private let metadata = RecordMetadata(timeOfDay: .sunset, moonPhase: .fullMoon)
    private let location = LocationInfo(latitude: 37.77, longitude: -122.41, label: "1200 Treat Ave, San Francisco")

    private func makeModel() -> CreateRecordModel {
        CreateRecordModel(createdAt: fixedDate, metadata: metadata, location: location)
    }

    @Test func emptyFormIsNotSaveable() {
        let model = makeModel()
        #expect(!model.isSaveable)
    }

    @Test func whitespaceOnlyNameIsNotSaveable() {
        let model = makeModel()
        model.name = "   "
        #expect(!model.isSaveable)
    }

    @Test func nonEmptyNameIsSaveable() {
        let model = makeModel()
        model.name = "Jane"
        #expect(model.isSaveable)
    }

    @Test func createdAtIsFixedAtInit() {
        let model = makeModel()
        #expect(model.createdAt == fixedDate)
    }

    @Test func metadataIsStoredVerbatim() {
        let model = makeModel()
        #expect(model.metadata.timeOfDay == .sunset)
        #expect(model.metadata.moonPhase == .fullMoon)
    }

    @Test func locationIsStoredVerbatim() {
        let model = makeModel()
        #expect(model.location?.label == "1200 Treat Ave, San Francisco")
    }

    @Test func randomZodiacSignIsOneOfAllCases() {
        let model = makeModel()
        #expect(ZodiacSign.allCases.contains(model.randomZodiacSign))
    }

    @Test func randomZodiacSignIsStableAcrossReads() {
        let model = makeModel()
        let first = model.randomZodiacSign
        let second = model.randomZodiacSign
        let third = model.randomZodiacSign
        #expect(first == second)
        #expect(second == third)
    }

    @Test func previewRecordMirrorsModelState() {
        let model = makeModel()
        model.name = "Alex"
        model.description = "Met at the festival"
        let record = model.previewRecord
        #expect(record.name == "Alex")
        #expect(record.description == "Met at the festival")
        #expect(record.location?.label == "1200 Treat Ave, San Francisco")
        #expect(record.zodiacSign == model.randomZodiacSign)
        #expect(record.metadata.timeOfDay == .sunset)
        #expect(record.metadata.moonPhase == .fullMoon)
        #expect(record.createdAt == fixedDate)
    }

    @Test func draftUsesRandomZodiacSign() {
        let model = makeModel()
        model.name = "Jane"
        model.description = "Met at cafe"
        let draft = model.draft
        #expect(draft.name == "Jane")
        #expect(draft.description == "Met at cafe")
        #expect(draft.zodiacSign == model.randomZodiacSign)
        #expect(draft.location?.label == "1200 Treat Ave, San Francisco")
    }

    @Test func draftCarriesPhotoData() {
        let model = makeModel()
        model.name = "Jane"
        model.photoData = Data([0xFF, 0xD8, 0xFF])
        #expect(model.draft.photo == Data([0xFF, 0xD8, 0xFF]))
    }
}
