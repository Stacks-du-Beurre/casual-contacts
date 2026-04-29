import Foundation
import SwiftUI
import Observation
import CoreModels

/// Tracks the currently presented sheets/destinations. A single source of truth
/// owned by the `RootScene`. All flags are plain properties, so SwiftUI reads
/// pick them up through `@Observable`.
@MainActor
@Observable
public final class NavigationRouter {
    public enum LocationPrimerContext: String, Identifiable {
        case create
        case settings
        case sortDistance

        public var id: String { rawValue }
    }

    public var showingCreate = false
    public var showingSettings = false
    public var showingAbout = false
    public var showingInListDeveloperSettings = false
    public var locationPrimerContext: LocationPrimerContext?
    public var selectedRecordForMediumDetail: Record?
    public var selectedRecordForLargeDetail: Record?
    public var tappedRecord: Record?
    public var tappedRecordSourceFrame: CGRect = .zero
    public var editingRecord: Record?
    /// Presents the 78-card letter/shape diagnostic gallery
    /// (`DebugLetterGalleryScene`). Set from the developer settings panel.
    /// The gallery scene itself is `#if DEBUG`-only, so this flag is only
    /// ever observed in DEBUG builds.
    public var showingDebugLetterGallery: Bool = false

    public init() {}
}
