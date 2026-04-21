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

    public enum PhotoState: Equatable, Sendable {
        case none
        /// Detection in flight. The create flow shows a spinner in place of the
        /// photo until this resolves to `.ready`.
        case detecting(Data)
        case ready(Data, NormalizedPoint?)

        public var data: Data? {
            switch self {
            case .none: return nil
            case .detecting(let d): return d
            case .ready(let d, _): return d
            }
        }

        public var focus: NormalizedPoint? {
            if case .ready(_, let focus) = self { return focus }
            return nil
        }

        public var isDetecting: Bool {
            if case .detecting = self { return true }
            return false
        }
    }

    // User-editable state.
    public var name: String = ""
    public var description: String = ""
    public private(set) var photoState: PhotoState = .none

    // Fixed at init — non-editable.
    public let createdAt: Date
    public let metadata: RecordMetadata
    public let location: LocationInfo?

    /// A random sign chosen once per instance. Temporary: the real zodiac
    /// picker replaces this in a later plan. Visible-only; does not drive
    /// interactive state.
    public let randomZodiacSign: ZodiacSign

    /// Guilloche shape picked once at init so the preview backdrop matches what
    /// gets persisted on save — otherwise the saved record's shape silently
    /// re-rolls when `SwiftDataRecordStore.create` assigns a fresh UUID.
    public let guillocheShape: GuillocheShape

    public init(
        createdAt: Date,
        metadata: RecordMetadata,
        location: LocationInfo?,
        randomZodiacSign: ZodiacSign? = nil,
        guillocheShape: GuillocheShape? = nil
    ) {
        self.createdAt = createdAt
        self.metadata = metadata
        self.location = location
        // ZodiacSign has 12 cases; allCases.randomElement()! is safe.
        self.randomZodiacSign = randomZodiacSign ?? ZodiacSign.allCases.randomElement()!
        self.guillocheShape = guillocheShape ?? GuillocheShape.allCases.randomElement()!
    }

    /// Kicks off face detection and resolves the model's `photoState` when the
    /// service returns. If the user replaces or clears the photo mid-detection,
    /// the stale result is dropped — the most recent `setPhoto` call wins.
    public func setPhoto(_ data: Data, using service: any FaceDetectionService) {
        photoState = .detecting(data)
        Task { @MainActor [weak self] in
            let focus = await service.focusPoint(in: data)
            guard let self else { return }
            // Only commit if the state still reflects the same in-flight photo.
            if case .detecting(let current) = self.photoState, current == data {
                self.photoState = .ready(data, focus)
            }
        }
    }

    public func clearPhoto() {
        photoState = .none
    }

    public var photoData: Data? { photoState.data }
    public var photoFocus: NormalizedPoint? { photoState.focus }
    public var isDetectingPhoto: Bool { photoState.isDetecting }

    /// Save is blocked during detection so the persisted record always reflects
    /// the detection outcome (centered photo in the card, not a mid-analysis
    /// placeholder).
    public var isSaveable: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isDetectingPhoto
    }

    public var draft: RecordDraft {
        RecordDraft(
            name: name,
            description: description,
            photo: photoData,
            photoFocus: photoFocus,
            location: location,
            zodiacSign: randomZodiacSign,
            guillocheShape: guillocheShape
        )
    }

    /// Provisional `Record` used to drive the `CardBackdrop` preview while the
    /// user is still editing. The ID is stable within-instance but not final;
    /// the persisted record gets a fresh ID at save time via `RecordStore`.
    public var previewRecord: Record {
        // Only expose a photo in the preview once detection has resolved —
        // while `.detecting`, the form layer shows a spinner in place of a
        // half-rendered photo that would shift once detection landed.
        let previewPhoto: PhotoID?
        let previewFocus: NormalizedPoint?
        switch photoState {
        case .none, .detecting:
            previewPhoto = nil
            previewFocus = nil
        case .ready(_, let focus):
            previewPhoto = previewPhotoID
            previewFocus = focus
        }
        return Record(
            id: previewID,
            name: name,
            description: description,
            photoID: previewPhoto,
            photoFocus: previewFocus,
            location: location,
            zodiacSign: randomZodiacSign,
            createdAt: createdAt,
            updatedAt: createdAt,
            metadata: metadata,
            guillocheShape: guillocheShape
        )
    }

    private let previewID = UUID()
    private let previewPhotoID = PhotoID(filename: "preview.jpg")
}
