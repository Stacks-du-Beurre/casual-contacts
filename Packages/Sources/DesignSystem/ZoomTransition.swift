import SwiftUI

public struct ZoomSourceID: Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }

    public static let createButton = ZoomSourceID(rawValue: "createButton")
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
        modifier(ZoomSourceModifier(id: id))
    }

    func zoomDestination(_ id: ZoomSourceID) -> some View {
        modifier(ZoomDestinationModifier(id: id))
    }
}

private struct ZoomSourceModifier: ViewModifier {
    let id: ZoomSourceID
    @Environment(\.zoomNamespace) private var namespace

    func body(content: Content) -> some View {
        #if os(iOS)
        if let namespace {
            content.matchedTransitionSource(id: id.rawValue, in: namespace)
        } else {
            content
        }
        #else
        content
        #endif
    }
}

private struct ZoomDestinationModifier: ViewModifier {
    let id: ZoomSourceID
    @Environment(\.zoomNamespace) private var namespace

    func body(content: Content) -> some View {
        #if os(iOS)
        if let namespace {
            content.navigationTransition(.zoom(sourceID: id.rawValue, in: namespace))
        } else {
            content
        }
        #else
        content
        #endif
    }
}
