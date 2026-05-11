import Foundation
import SwiftUI
import CoreModels
import Visuals

/// Concrete `CardPathProvider` backed by generated Latin Swift paths and
/// on-demand Cyrillic SVG resources.
///
/// `Tools/regenerate-svg.sh` must have been run after asset changes. Latin
/// remains Swift-generated because that catalog is small and already compiled
/// acceptably. Cyrillic blend paths are much larger, so they stay as SVG
/// resources and are parsed once per glyph/shape into the cache below.
public struct RealCardPathProvider: CardPathProvider {

    private let cyrillicCache = GuillocheSVGPathCache()

    public init() {}

    public func rotationPaths(for letter: Character) -> [Path] {
        guard let glyph = Self.glyphIdentifier(for: letter) else { return [] }
        if Self.isCyrillicGlyph(glyph) {
            return cyrillicCache.paths(named: "\(glyph)_Rotation", kind: .rotation)
        }
        return Self.latinRotation(for: glyph) ?? []
    }

    public func blendPaths(for letter: Character, shape: GuillocheShape, density: CCVisuals.Guilloche.LineDensity) -> [Path] {
        // Current catalog has one file per (glyph, shape). Density selection
        // between Cards / Recommended / Preview variants is deferred.
        _ = density

        guard let glyph = Self.glyphIdentifier(for: letter) else { return [] }
        if Self.isCyrillicGlyph(glyph) {
            return cyrillicCache.paths(named: "\(glyph)_\(shape.resourceName)", kind: .blend)
        }
        return Self.latinBlend(for: glyph, shape: shape) ?? []
    }

    // MARK: - Latin generated lookups

    private static func latinRotation(for glyph: String) -> [Path]? {
        switch glyph {
        case "A": return CCVisuals.Guilloche.Rotation.Latin.A_Rotation.all
        case "B": return CCVisuals.Guilloche.Rotation.Latin.B_Rotation.all
        case "C": return CCVisuals.Guilloche.Rotation.Latin.C_Rotation.all
        case "D": return CCVisuals.Guilloche.Rotation.Latin.D_Rotation.all
        case "E": return CCVisuals.Guilloche.Rotation.Latin.E_Rotation.all
        case "F": return CCVisuals.Guilloche.Rotation.Latin.F_Rotation.all
        case "G": return CCVisuals.Guilloche.Rotation.Latin.G_Rotation.all
        case "H": return CCVisuals.Guilloche.Rotation.Latin.H_Rotation.all
        case "I": return CCVisuals.Guilloche.Rotation.Latin.I_Rotation.all
        case "J": return CCVisuals.Guilloche.Rotation.Latin.J_Rotation.all
        case "K": return CCVisuals.Guilloche.Rotation.Latin.K_Rotation.all
        case "L": return CCVisuals.Guilloche.Rotation.Latin.L_Rotation.all
        case "M": return CCVisuals.Guilloche.Rotation.Latin.M_Rotation.all
        case "N": return CCVisuals.Guilloche.Rotation.Latin.N_Rotation.all
        case "O": return CCVisuals.Guilloche.Rotation.Latin.O_Rotation.all
        case "P": return CCVisuals.Guilloche.Rotation.Latin.P_Rotation.all
        case "Q": return CCVisuals.Guilloche.Rotation.Latin.Q_Rotation.all
        case "R": return CCVisuals.Guilloche.Rotation.Latin.R_Rotation.all
        case "S": return CCVisuals.Guilloche.Rotation.Latin.S_Rotation.all
        case "T": return CCVisuals.Guilloche.Rotation.Latin.T_Rotation.all
        case "U": return CCVisuals.Guilloche.Rotation.Latin.U_Rotation.all
        case "V": return CCVisuals.Guilloche.Rotation.Latin.V_Rotation.all
        case "W": return CCVisuals.Guilloche.Rotation.Latin.W_Rotation.all
        case "X": return CCVisuals.Guilloche.Rotation.Latin.X_Rotation.all
        case "Y": return CCVisuals.Guilloche.Rotation.Latin.Y_Rotation.all
        case "Z": return CCVisuals.Guilloche.Rotation.Latin.Z_Rotation.all
        default: return nil
        }
    }

    private static func latinBlend(for glyph: String, shape: GuillocheShape) -> [Path]? {
        switch (glyph, shape) {
        case ("A", .circle): return CCVisuals.Guilloche.Blend.Latin.A_Circle.all
        case ("A", .square): return CCVisuals.Guilloche.Blend.Latin.A_Square.all
        case ("A", .polygon): return CCVisuals.Guilloche.Blend.Latin.A_Polygon.all
        case ("B", .circle): return CCVisuals.Guilloche.Blend.Latin.B_Circle.all
        case ("B", .square): return CCVisuals.Guilloche.Blend.Latin.B_Square.all
        case ("B", .polygon): return CCVisuals.Guilloche.Blend.Latin.B_Polygon.all
        case ("C", .circle): return CCVisuals.Guilloche.Blend.Latin.C_Circle.all
        case ("C", .square): return CCVisuals.Guilloche.Blend.Latin.C_Square.all
        case ("C", .polygon): return CCVisuals.Guilloche.Blend.Latin.C_Polygon.all
        case ("D", .circle): return CCVisuals.Guilloche.Blend.Latin.D_Circle.all
        case ("D", .square): return CCVisuals.Guilloche.Blend.Latin.D_Square.all
        case ("D", .polygon): return CCVisuals.Guilloche.Blend.Latin.D_Polygon.all
        case ("E", .circle): return CCVisuals.Guilloche.Blend.Latin.E_Circle.all
        case ("E", .square): return CCVisuals.Guilloche.Blend.Latin.E_Square.all
        case ("E", .polygon): return CCVisuals.Guilloche.Blend.Latin.E_Polygon.all
        case ("F", .circle): return CCVisuals.Guilloche.Blend.Latin.F_Circle.all
        case ("F", .square): return CCVisuals.Guilloche.Blend.Latin.F_Square.all
        case ("F", .polygon): return CCVisuals.Guilloche.Blend.Latin.F_Polygon.all
        case ("G", .circle): return CCVisuals.Guilloche.Blend.Latin.G_Circle.all
        case ("G", .square): return CCVisuals.Guilloche.Blend.Latin.G_Square.all
        case ("G", .polygon): return CCVisuals.Guilloche.Blend.Latin.G_Polygon.all
        case ("H", .circle): return CCVisuals.Guilloche.Blend.Latin.H_Circle.all
        case ("H", .square): return CCVisuals.Guilloche.Blend.Latin.H_Square.all
        case ("H", .polygon): return CCVisuals.Guilloche.Blend.Latin.H_Polygon.all
        case ("I", .circle): return CCVisuals.Guilloche.Blend.Latin.I_Circle.all
        case ("I", .square): return CCVisuals.Guilloche.Blend.Latin.I_Square.all
        case ("I", .polygon): return CCVisuals.Guilloche.Blend.Latin.I_Polygon.all
        case ("J", .circle): return CCVisuals.Guilloche.Blend.Latin.J_Circle.all
        case ("J", .square): return CCVisuals.Guilloche.Blend.Latin.J_Square.all
        case ("J", .polygon): return CCVisuals.Guilloche.Blend.Latin.J_Polygon.all
        case ("K", .circle): return CCVisuals.Guilloche.Blend.Latin.K_Circle.all
        case ("K", .square): return CCVisuals.Guilloche.Blend.Latin.K_Square.all
        case ("K", .polygon): return CCVisuals.Guilloche.Blend.Latin.K_Polygon.all
        case ("L", .circle): return CCVisuals.Guilloche.Blend.Latin.L_Circle.all
        case ("L", .square): return CCVisuals.Guilloche.Blend.Latin.L_Square.all
        case ("L", .polygon): return CCVisuals.Guilloche.Blend.Latin.L_Polygon.all
        case ("M", .circle): return CCVisuals.Guilloche.Blend.Latin.M_Circle.all
        case ("M", .square): return CCVisuals.Guilloche.Blend.Latin.M_Square.all
        case ("M", .polygon): return CCVisuals.Guilloche.Blend.Latin.M_Polygon.all
        case ("N", .circle): return CCVisuals.Guilloche.Blend.Latin.N_Circle.all
        case ("N", .square): return CCVisuals.Guilloche.Blend.Latin.N_Square.all
        case ("N", .polygon): return CCVisuals.Guilloche.Blend.Latin.N_Polygon.all
        case ("O", .circle): return CCVisuals.Guilloche.Blend.Latin.O_Circle.all
        case ("O", .square): return CCVisuals.Guilloche.Blend.Latin.O_Square.all
        case ("O", .polygon): return CCVisuals.Guilloche.Blend.Latin.O_Polygon.all
        case ("P", .circle): return CCVisuals.Guilloche.Blend.Latin.P_Circle.all
        case ("P", .square): return CCVisuals.Guilloche.Blend.Latin.P_Square.all
        case ("P", .polygon): return CCVisuals.Guilloche.Blend.Latin.P_Polygon.all
        case ("Q", .circle): return CCVisuals.Guilloche.Blend.Latin.Q_Circle.all
        case ("Q", .square): return CCVisuals.Guilloche.Blend.Latin.Q_Square.all
        case ("Q", .polygon): return CCVisuals.Guilloche.Blend.Latin.Q_Polygon.all
        case ("R", .circle): return CCVisuals.Guilloche.Blend.Latin.R_Circle.all
        case ("R", .square): return CCVisuals.Guilloche.Blend.Latin.R_Square.all
        case ("R", .polygon): return CCVisuals.Guilloche.Blend.Latin.R_Polygon.all
        case ("S", .circle): return CCVisuals.Guilloche.Blend.Latin.S_Circle.all
        case ("S", .square): return CCVisuals.Guilloche.Blend.Latin.S_Square.all
        case ("S", .polygon): return CCVisuals.Guilloche.Blend.Latin.S_Polygon.all
        case ("T", .circle): return CCVisuals.Guilloche.Blend.Latin.T_Circle.all
        case ("T", .square): return CCVisuals.Guilloche.Blend.Latin.T_Square.all
        case ("T", .polygon): return CCVisuals.Guilloche.Blend.Latin.T_Polygon.all
        case ("U", .circle): return CCVisuals.Guilloche.Blend.Latin.U_Circle.all
        case ("U", .square): return CCVisuals.Guilloche.Blend.Latin.U_Square.all
        case ("U", .polygon): return CCVisuals.Guilloche.Blend.Latin.U_Polygon.all
        case ("V", .circle): return CCVisuals.Guilloche.Blend.Latin.V_Circle.all
        case ("V", .square): return CCVisuals.Guilloche.Blend.Latin.V_Square.all
        case ("V", .polygon): return CCVisuals.Guilloche.Blend.Latin.V_Polygon.all
        case ("W", .circle): return CCVisuals.Guilloche.Blend.Latin.W_Circle.all
        case ("W", .square): return CCVisuals.Guilloche.Blend.Latin.W_Square.all
        case ("W", .polygon): return CCVisuals.Guilloche.Blend.Latin.W_Polygon.all
        case ("X", .circle): return CCVisuals.Guilloche.Blend.Latin.X_Circle.all
        case ("X", .square): return CCVisuals.Guilloche.Blend.Latin.X_Square.all
        case ("X", .polygon): return CCVisuals.Guilloche.Blend.Latin.X_Polygon.all
        case ("Y", .circle): return CCVisuals.Guilloche.Blend.Latin.Y_Circle.all
        case ("Y", .square): return CCVisuals.Guilloche.Blend.Latin.Y_Square.all
        case ("Y", .polygon): return CCVisuals.Guilloche.Blend.Latin.Y_Polygon.all
        case ("Z", .circle): return CCVisuals.Guilloche.Blend.Latin.Z_Circle.all
        case ("Z", .square): return CCVisuals.Guilloche.Blend.Latin.Z_Square.all
        case ("Z", .polygon): return CCVisuals.Guilloche.Blend.Latin.Z_Polygon.all
        default: return nil
        }
    }

    // MARK: - Glyph normalization

    private static func glyphIdentifier(for letter: Character) -> String? {
        let uppercased = String(letter).uppercased()
        guard uppercased.unicodeScalars.count == 1,
              let scalar = uppercased.unicodeScalars.first
        else { return nil }

        if (65...90).contains(scalar.value) {
            return String(scalar)
        }

        if supportedCyrillicScalars.contains(scalar.value) {
            return String(format: "U%04X", scalar.value)
        }

        return nil
    }

    private static func isCyrillicGlyph(_ glyph: String) -> Bool {
        glyph.hasPrefix("U04")
    }

    private static let supportedCyrillicScalars: Set<UInt32> = [
        0x0401,
        0x0410, 0x0411, 0x0412, 0x0413, 0x0414, 0x0415, 0x0416,
        0x0417, 0x0418, 0x0419, 0x041A, 0x041B, 0x041C, 0x041D,
        0x041E, 0x041F, 0x0420, 0x0421, 0x0422, 0x0423, 0x0424,
        0x0425, 0x0426, 0x0427, 0x0428, 0x0429, 0x042A, 0x042B,
        0x042C, 0x042D, 0x042E, 0x042F
    ]
}

private final class GuillocheSVGPathCache: @unchecked Sendable {
    private let lock = NSLock()
    private var cache: [String: [Path]] = [:]

    func paths(named name: String, kind: CCVisuals.Guilloche.SVGResource.Kind) -> [Path] {
        let key = "\(kind.resourceDirectory)/\(name)"

        lock.lock()
        if let cached = cache[key] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        let parsed = CCVisuals.Guilloche.SVGResource.paths(named: name, kind: kind)

        lock.lock()
        cache[key] = parsed
        lock.unlock()

        return parsed
    }
}

private extension GuillocheShape {
    var resourceName: String {
        switch self {
        case .circle: "Circle"
        case .square: "Square"
        case .polygon: "Polygon"
        }
    }
}
