import Foundation

@Observable
@MainActor
public final class CardAnimationDiagnostics {
    public static let shared = CardAnimationDiagnostics()

    public enum Defaults {
        public static let showsOverlay = false
        public static let showsOverlayKey = "CardAnimationDiagnostics.showsOverlay"
    }

    public var showsOverlay: Bool {
        didSet { defaults.set(showsOverlay, forKey: key) }
    }

    public private(set) var mountedCardCount = 0
    public private(set) var activeAnimatingCardCount = 0

    private let defaults: UserDefaults
    private let key: String
    private var mountedCardIDs: Set<UUID> = []
    private var activeAnimatingCardIDs: Set<UUID> = []

    public init(
        defaults: UserDefaults = .standard,
        key: String = Defaults.showsOverlayKey
    ) {
        self.defaults = defaults
        self.key = key
        self.showsOverlay = Self.readBool(defaults, key, fallback: Defaults.showsOverlay)
    }

    public func registerMountedCard(id: UUID) {
        mountedCardIDs.insert(id)
        publishCounts()
    }

    public func updateCardAnimation(id: UUID, isActive: Bool) {
        if isActive {
            activeAnimatingCardIDs.insert(id)
        } else {
            activeAnimatingCardIDs.remove(id)
        }
        publishCounts()
    }

    public func unregisterMountedCard(id: UUID) {
        mountedCardIDs.remove(id)
        activeAnimatingCardIDs.remove(id)
        publishCounts()
    }

    public func reset() {
        showsOverlay = Defaults.showsOverlay
        mountedCardIDs.removeAll()
        activeAnimatingCardIDs.removeAll()
        publishCounts()
    }

    private func publishCounts() {
        mountedCardCount = mountedCardIDs.count
        activeAnimatingCardCount = activeAnimatingCardIDs.count
    }

    private static func readBool(_ defaults: UserDefaults, _ key: String, fallback: Bool) -> Bool {
        defaults.object(forKey: key) == nil ? fallback : defaults.bool(forKey: key)
    }
}
