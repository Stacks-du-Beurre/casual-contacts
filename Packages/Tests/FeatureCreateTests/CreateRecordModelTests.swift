import Testing
import Foundation
import CoreModels
@testable import FeatureCreate

@MainActor
@Suite struct CreateRecordModelTests {

    private final class FakeFaceDetectionService: FaceDetectionService, @unchecked Sendable {
        let result: NormalizedPoint?
        let delay: Duration
        init(result: NormalizedPoint?, delay: Duration = .zero) {
            self.result = result
            self.delay = delay
        }
        func focusPoint(in imageData: Data) async -> NormalizedPoint? {
            if delay > .zero { try? await Task.sleep(for: delay) }
            return result
        }
    }

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

    @Test func zodiacSignStartsNil() {
        let model = makeModel()
        #expect(model.zodiacSign == nil)
    }

    @Test func zodiacSignUpdateFlowsToPreviewAndDraft() {
        let model = makeModel()
        model.name = "Leo"
        model.zodiacSign = .leo
        #expect(model.previewRecord.zodiacSign == .leo)
        #expect(model.draft.zodiacSign == .leo)
    }

    @Test func previewRecordMirrorsModelState() {
        let model = makeModel()
        model.name = "Alex"
        model.description = "Met at the festival"
        let record = model.previewRecord
        #expect(record.name == "Alex")
        #expect(record.description == "Met at the festival")
        #expect(record.location?.label == "1200 Treat Ave, San Francisco")
        #expect(record.zodiacSign == nil)
        #expect(record.metadata.timeOfDay == .sunset)
        #expect(record.metadata.moonPhase == .fullMoon)
        #expect(record.createdAt == fixedDate)
    }

    @Test func draftZodiacSignIsNilUntilSelected() {
        let model = makeModel()
        model.name = "Jane"
        model.description = "Met at cafe"
        let draft = model.draft
        #expect(draft.name == "Jane")
        #expect(draft.description == "Met at cafe")
        #expect(draft.zodiacSign == nil)
        #expect(draft.location?.label == "1200 Treat Ave, San Francisco")
    }

    @Test func draftCarriesPhotoDataAfterDetection() async {
        let model = makeModel()
        model.name = "Jane"
        let service = FakeFaceDetectionService(result: NormalizedPoint(x: 0.3, y: 0.4))
        model.setPhoto(Data([0xFF, 0xD8, 0xFF]), using: service)
        await Task.yield()
        // Give the detection task a moment to settle.
        for _ in 0..<50 {
            if !model.isDetectingPhoto { break }
            try? await Task.sleep(for: .milliseconds(5))
        }
        #expect(model.draft.photo == Data([0xFF, 0xD8, 0xFF]))
        #expect(model.draft.photoFocus == NormalizedPoint(x: 0.3, y: 0.4))
    }

    @Test func detectingPhotoBlocksSaveAndHidesPhotoFromPreview() async {
        let model = makeModel()
        model.name = "Jane"
        let service = FakeFaceDetectionService(result: .center, delay: .milliseconds(100))
        model.setPhoto(Data([0x01]), using: service)
        // While the detection task is in flight, save is blocked and the
        // preview record carries no photoID (so the card skips PhotoLayer
        // until centering is known).
        #expect(model.isDetectingPhoto)
        #expect(!model.isSaveable)
        #expect(model.previewRecord.photoID == nil)
        // Wait for the detection to complete.
        for _ in 0..<50 {
            if !model.isDetectingPhoto { break }
            try? await Task.sleep(for: .milliseconds(10))
        }
        #expect(!model.isDetectingPhoto)
        #expect(model.isSaveable)
        #expect(model.previewRecord.photoID != nil)
        #expect(model.previewRecord.photoFocus == .center)
    }

    @Test func nilDetectionResultIsPersistedAsNilFocus() async {
        let model = makeModel()
        model.name = "Jane"
        let service = FakeFaceDetectionService(result: nil)
        model.setPhoto(Data([0x01]), using: service)
        for _ in 0..<50 {
            if !model.isDetectingPhoto { break }
            try? await Task.sleep(for: .milliseconds(5))
        }
        #expect(model.draft.photoFocus == nil)
    }

    @Test func replacingPhotoMidDetectionDiscardsStaleResult() async {
        let model = makeModel()
        model.name = "Jane"
        let slowService = FakeFaceDetectionService(
            result: NormalizedPoint(x: 0.1, y: 0.1),
            delay: .milliseconds(200)
        )
        let fastService = FakeFaceDetectionService(result: NormalizedPoint(x: 0.9, y: 0.9))
        model.setPhoto(Data([0x01]), using: slowService)
        // Replace before slowService resolves.
        model.setPhoto(Data([0x02]), using: fastService)
        for _ in 0..<100 {
            if !model.isDetectingPhoto { break }
            try? await Task.sleep(for: .milliseconds(10))
        }
        // The second photo wins.
        #expect(model.draft.photo == Data([0x02]))
        #expect(model.draft.photoFocus == NormalizedPoint(x: 0.9, y: 0.9))
    }

    @Test func editingInitPreloadsTextFields() {
        let record = Record(
            id: UUID(),
            name: "Existing",
            description: "old desc",
            photoID: nil,
            location: location,
            zodiacSign: .virgo,
            createdAt: fixedDate,
            updatedAt: fixedDate,
            metadata: metadata
        )
        let model = CreateRecordModel(editing: record, photoData: nil, photoFocus: nil)
        #expect(model.name == "Existing")
        #expect(model.description == "old desc")
        #expect(model.zodiacSign == .virgo)
        #expect(model.isSaveable)
    }

    @Test func editingInitPinsAmbientFieldsToRecord() {
        let record = Record(
            id: UUID(),
            name: "Pinned",
            description: "",
            photoID: nil,
            location: location,
            zodiacSign: nil,
            createdAt: fixedDate,
            updatedAt: fixedDate,
            metadata: metadata
        )
        let model = CreateRecordModel(editing: record, photoData: nil, photoFocus: nil)
        #expect(model.createdAt == fixedDate)
        #expect(model.metadata.timeOfDay == .sunset)
        #expect(model.metadata.moonPhase == .fullMoon)
        #expect(model.location?.label == location.label)
        #expect(model.guillocheShape == record.guillocheShape)
    }

    @Test func editingInitWithPhotoStartsReadyState() {
        let bytes = Data([0x01, 0x02, 0x03])
        let focus = NormalizedPoint(x: 0.5, y: 0.5)
        let record = Record(
            id: UUID(),
            name: "WithPhoto",
            description: "",
            photoID: PhotoID(filename: "old.jpg"),
            photoFocus: focus,
            location: nil,
            zodiacSign: nil,
            createdAt: fixedDate,
            updatedAt: fixedDate,
            metadata: metadata
        )
        let model = CreateRecordModel(editing: record, photoData: bytes, photoFocus: focus)
        #expect(model.photoData == bytes)
        #expect(model.photoFocus == focus)
        #expect(!model.isDetectingPhoto)
    }

    @Test func editingInitWithoutPhotoStartsNoneState() {
        let record = Record(
            id: UUID(),
            name: "NoPhoto",
            description: "",
            photoID: nil,
            location: nil,
            zodiacSign: nil,
            createdAt: fixedDate,
            updatedAt: fixedDate,
            metadata: metadata
        )
        let model = CreateRecordModel(editing: record, photoData: nil, photoFocus: nil)
        #expect(model.photoData == nil)
    }
}
