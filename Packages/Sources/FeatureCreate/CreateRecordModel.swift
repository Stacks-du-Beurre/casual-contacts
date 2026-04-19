import Foundation
import SwiftUI
import Observation
import CoreModels

/// Editable form state for the create-record flow. Owns the name, description,
/// and photo data that the user types/picks. All other fields (`createdAt`,
/// `metadata`, `location`, `randomZodiacSign`) are fixed at init: they reflect
/// the ambient context at the moment the sheet opened.
@MainActor
@Observable
public final class CreateRecordModel {

    // User-editable state.
    public var name: String = ""
    public var description: String = ""
    public var photoData: Data?

    // Fixed at init — non-editable.
    public let createdAt: Date
    public let metadata: RecordMetadata
    public let location: LocationInfo?

    /// A random sign chosen once per instance. Temporary: the real zodiac
    /// picker replaces this in a later plan. Visible-only; does not drive
    /// interactive state.
    public let randomZodiacSign: ZodiacSign

    public init(
        createdAt: Date,
        metadata: RecordMetadata,
        location: LocationInfo?,
        randomZodiacSign: ZodiacSign? = nil
    ) {
        self.createdAt = createdAt
        self.metadata = metadata
        self.location = location
        // ZodiacSign has 12 cases; allCases.randomElement()! is safe.
        self.randomZodiacSign = randomZodiacSign ?? ZodiacSign.allCases.randomElement()!
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
            zodiacSign: randomZodiacSign
        )
    }

    /// Provisional `Record` used to drive the `CardBackdrop` preview while the
    /// user is still editing. The ID is stable within-instance but not final;
    /// the persisted record gets a fresh ID at save time via `RecordStore`.
    public var previewRecord: Record {
        Record(
            id: previewID,
            name: name,
            description: description,
            photoID: photoData == nil ? nil : previewPhotoID,
            location: location,
            zodiacSign: randomZodiacSign,
            createdAt: createdAt,
            updatedAt: createdAt,
            metadata: metadata
        )
    }

    private let previewID = UUID()
    private let previewPhotoID = PhotoID(filename: "preview.jpg")
}
