import Foundation
import SwiftUI
import Observation
import CoreModels

/// @Observable form model — owns editable field state and derives a live Record
/// for use in the preview card.
@MainActor
@Observable
public final class CreateRecordModel {

    public var name: String = ""
    public var description: String = ""
    public var photoData: Data?
    public var location: LocationInfo?
    public var zodiacSign: ZodiacSign?

    /// A provisional Record derived from current form state. ID and timestamps are
    /// stable-within-instance but not final; the real record gets them at save time.
    public var previewRecord: Record {
        Record(
            id: previewID,
            name: name.isEmpty ? "" : name,
            description: description,
            photoID: nil,  // preview doesn't persist photo — just used for "has photo" branch
            location: location,
            zodiacSign: zodiacSign,
            createdAt: fixedCreatedAt,
            updatedAt: fixedCreatedAt,
            metadata: previewMetadata
        )
    }

    public var isSaveable: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public var draft: RecordDraft {
        RecordDraft(
            name: name,
            description: description,
            photo: photoData,
            location: location,
            zodiacSign: zodiacSign
        )
    }

    // MARK: - Stable preview values

    private let previewID = UUID()
    private let fixedCreatedAt = Date()
    private var previewMetadata: RecordMetadata = RecordMetadata(timeOfDay: .midday, moonPhase: .fullMoon)

    public init() {}

    /// Inject the real metadata once location/time are known.
    public func updatePreviewMetadata(_ metadata: RecordMetadata) {
        self.previewMetadata = metadata
    }
}
