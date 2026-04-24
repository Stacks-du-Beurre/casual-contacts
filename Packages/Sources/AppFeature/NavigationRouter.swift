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

    public var showingCreate = false
    public var showingSettings = false
    public var showingAbout = false
    public var selectedRecordForMediumDetail: Record?
    public var selectedRecordForLargeDetail: Record?
    public var tappedRecord: Record?
    public var tappedRecordSourceFrame: CGRect = .zero
    public var editingRecord: Record?

    public init() {}
}
