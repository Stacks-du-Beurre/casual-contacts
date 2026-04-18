import SwiftUI

public enum HologramTexture: String, CaseIterable, Sendable {
    case neon1 = "Neon_1"
    case neon2 = "Neon_2"
    case neon3 = "Neon_3"
    case neon4 = "Neon_4"

    // Neon_1 and Neon_2 are watermarked stock-photo previews shipped as placeholders
    // until licensed versions replace them. Do not use in production surfaces.
    public var isLicensed: Bool {
        switch self {
        case .neon1, .neon2: return false
        case .neon3, .neon4: return true
        }
    }
}
