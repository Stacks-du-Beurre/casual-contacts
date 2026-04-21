import Foundation

public enum GuillocheShape: String, CaseIterable, Codable, Sendable {
    case circle, square, polygon

    /// Stable per-UUID fallback used when a `Record` predates the field being
    /// persisted (or a caller hasn't picked a shape yet). Swift's `hashValue` is
    /// process-seeded, so we sum the UUID's raw bytes for a cross-launch stable
    /// value.
    public static func deterministic(for id: UUID) -> GuillocheShape {
        var byteSum: Int = 0
        withUnsafeBytes(of: id.uuid) { bytes in
            for byte in bytes { byteSum &+= Int(byte) }
        }
        let cases = GuillocheShape.allCases
        return cases[byteSum % cases.count]
    }
}
