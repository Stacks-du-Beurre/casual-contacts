import SwiftUI

public struct ZoomSourceID: Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }

    public static let createButton = ZoomSourceID(rawValue: "createButton")
}

public struct RecordZoomID: Hashable, Sendable {
    public let recordID: UUID
    public init(_ recordID: UUID) { self.recordID = recordID }

    fileprivate var matchKey: String { "recordCard_\(recordID.uuidString)" }
}

private struct ZoomNamespaceKey: EnvironmentKey {
    static let defaultValue: Namespace.ID? = nil
}

public extension EnvironmentValues {
    var zoomNamespace: Namespace.ID? {
        get { self[ZoomNamespaceKey.self] }
        set { self[ZoomNamespaceKey.self] = newValue }
    }
}

public extension View {
    func zoomSource(_ id: ZoomSourceID) -> some View {
        modifier(ZoomSourceModifier(matchKey: id.rawValue))
    }

    func zoomDestination(_ id: ZoomSourceID) -> some View {
        modifier(ZoomDestinationModifier(matchKey: id.rawValue))
    }

    func zoomSource(_ id: RecordZoomID) -> some View {
        modifier(ZoomSourceModifier(matchKey: id.matchKey))
    }

    func zoomDestination(_ id: RecordZoomID) -> some View {
        modifier(ZoomDestinationModifier(matchKey: id.matchKey))
    }
}

private struct ZoomSourceModifier: ViewModifier {
    let matchKey: String
    @Environment(\.zoomNamespace) private var namespace

    func body(content: Content) -> some View {
        #if os(iOS)
        if let namespace {
            content.matchedTransitionSource(id: matchKey, in: namespace)
        } else {
            content
        }
        #else
        content
        #endif
    }
}

private struct ZoomDestinationModifier: ViewModifier {
    let matchKey: String
    @Environment(\.zoomNamespace) private var namespace

    func body(content: Content) -> some View {
        #if os(iOS)
        if let namespace {
            content.navigationTransition(.zoom(sourceID: matchKey, in: namespace))
        } else {
            content
        }
        #else
        content
        #endif
    }
}
