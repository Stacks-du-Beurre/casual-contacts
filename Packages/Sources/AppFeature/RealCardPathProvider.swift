import Foundation
import SwiftUI
import CoreModels
import Visuals

/// Concrete `CardPathProvider` backed by the auto-generated Swift `Path` constants
/// in `Visuals/Guilloche/Generated/`. `Tools/regenerate-svg.sh` must have been run,
/// otherwise the generated namespaces this file references will not exist and the
/// module will fail to compile.
///
/// The 26 × 3 switch below enumerates every (letter, shape) pair the designer
/// produced; unknown characters or shapes fall through to an empty array so
/// callers can degrade gracefully (e.g. a non-letter initial never matches).
public struct RealCardPathProvider: CardPathProvider {

    public init() {}

    public func rotationPaths(for letter: Character) -> [Path] {
        Self.rotation(for: letter) ?? []
    }

    public func blendPaths(for letter: Character, shape: GuillocheShape, density: CCVisuals.Guilloche.LineDensity) -> [Path] {
        // Current generated catalog has one file per (letter, shape). Density selection
        // between Cards (15 paths) / Recommended / Preview variants is deferred — later
        // tasks swap the lookup based on density.
        _ = density
        return Self.blend(for: letter, shape: shape) ?? []
    }

    // MARK: - Private lookups

    private static func rotation(for letter: Character) -> [Path]? {
        switch letter {
        case "A": return CCVisuals.Guilloche.Rotation.A_Rotation.all
        case "B": return CCVisuals.Guilloche.Rotation.B_Rotation.all
        case "C": return CCVisuals.Guilloche.Rotation.C_Rotation.all
        case "D": return CCVisuals.Guilloche.Rotation.D_Rotation.all
        case "E": return CCVisuals.Guilloche.Rotation.E_Rotation.all
        case "F": return CCVisuals.Guilloche.Rotation.F_Rotation.all
        case "G": return CCVisuals.Guilloche.Rotation.G_Rotation.all
        case "H": return CCVisuals.Guilloche.Rotation.H_Rotation.all
        case "I": return CCVisuals.Guilloche.Rotation.I_Rotation.all
        case "J": return CCVisuals.Guilloche.Rotation.J_Rotation.all
        case "K": return CCVisuals.Guilloche.Rotation.K_Rotation.all
        case "L": return CCVisuals.Guilloche.Rotation.L_Rotation.all
        case "M": return CCVisuals.Guilloche.Rotation.M_Rotation.all
        case "N": return CCVisuals.Guilloche.Rotation.N_Rotation.all
        case "O": return CCVisuals.Guilloche.Rotation.O_Rotation.all
        case "P": return CCVisuals.Guilloche.Rotation.P_Rotation.all
        case "Q": return CCVisuals.Guilloche.Rotation.Q_Rotation.all
        case "R": return CCVisuals.Guilloche.Rotation.R_Rotation.all
        case "S": return CCVisuals.Guilloche.Rotation.S_Rotation.all
        case "T": return CCVisuals.Guilloche.Rotation.T_Rotation.all
        case "U": return CCVisuals.Guilloche.Rotation.U_Rotation.all
        case "V": return CCVisuals.Guilloche.Rotation.V_Rotation.all
        case "W": return CCVisuals.Guilloche.Rotation.W_Rotation.all
        case "X": return CCVisuals.Guilloche.Rotation.X_Rotation.all
        case "Y": return CCVisuals.Guilloche.Rotation.Y_Rotation.all
        case "Z": return CCVisuals.Guilloche.Rotation.Z_Rotation.all
        default: return nil
        }
    }

    private static func blend(for letter: Character, shape: GuillocheShape) -> [Path]? {
        // Generated file names follow pattern: <Letter>_<Shape>.swift (e.g., A_Circle, A_Square, A_Polygon)
        // Each file defines CCVisuals.Guilloche.Blend.<Letter>_<Shape>.all
        // This switch enumerates all 26 × 3 = 78 combinations (generated via blend_switch.py).
        switch (letter, shape) {
        case ("A", .circle):  return CCVisuals.Guilloche.Blend.A_Circle.all
        case ("A", .square):  return CCVisuals.Guilloche.Blend.A_Square.all
        case ("A", .polygon): return CCVisuals.Guilloche.Blend.A_Polygon.all
        case ("B", .circle):  return CCVisuals.Guilloche.Blend.B_Circle.all
        case ("B", .square):  return CCVisuals.Guilloche.Blend.B_Square.all
        case ("B", .polygon): return CCVisuals.Guilloche.Blend.B_Polygon.all
        case ("C", .circle):  return CCVisuals.Guilloche.Blend.C_Circle.all
        case ("C", .square):  return CCVisuals.Guilloche.Blend.C_Square.all
        case ("C", .polygon): return CCVisuals.Guilloche.Blend.C_Polygon.all
        case ("D", .circle):  return CCVisuals.Guilloche.Blend.D_Circle.all
        case ("D", .square):  return CCVisuals.Guilloche.Blend.D_Square.all
        case ("D", .polygon): return CCVisuals.Guilloche.Blend.D_Polygon.all
        case ("E", .circle):  return CCVisuals.Guilloche.Blend.E_Circle.all
        case ("E", .square):  return CCVisuals.Guilloche.Blend.E_Square.all
        case ("E", .polygon): return CCVisuals.Guilloche.Blend.E_Polygon.all
        case ("F", .circle):  return CCVisuals.Guilloche.Blend.F_Circle.all
        case ("F", .square):  return CCVisuals.Guilloche.Blend.F_Square.all
        case ("F", .polygon): return CCVisuals.Guilloche.Blend.F_Polygon.all
        case ("G", .circle):  return CCVisuals.Guilloche.Blend.G_Circle.all
        case ("G", .square):  return CCVisuals.Guilloche.Blend.G_Square.all
        case ("G", .polygon): return CCVisuals.Guilloche.Blend.G_Polygon.all
        case ("H", .circle):  return CCVisuals.Guilloche.Blend.H_Circle.all
        case ("H", .square):  return CCVisuals.Guilloche.Blend.H_Square.all
        case ("H", .polygon): return CCVisuals.Guilloche.Blend.H_Polygon.all
        case ("I", .circle):  return CCVisuals.Guilloche.Blend.I_Circle.all
        case ("I", .square):  return CCVisuals.Guilloche.Blend.I_Square.all
        case ("I", .polygon): return CCVisuals.Guilloche.Blend.I_Polygon.all
        case ("J", .circle):  return CCVisuals.Guilloche.Blend.J_Circle.all
        case ("J", .square):  return CCVisuals.Guilloche.Blend.J_Square.all
        case ("J", .polygon): return CCVisuals.Guilloche.Blend.J_Polygon.all
        case ("K", .circle):  return CCVisuals.Guilloche.Blend.K_Circle.all
        case ("K", .square):  return CCVisuals.Guilloche.Blend.K_Square.all
        case ("K", .polygon): return CCVisuals.Guilloche.Blend.K_Polygon.all
        case ("L", .circle):  return CCVisuals.Guilloche.Blend.L_Circle.all
        case ("L", .square):  return CCVisuals.Guilloche.Blend.L_Square.all
        case ("L", .polygon): return CCVisuals.Guilloche.Blend.L_Polygon.all
        case ("M", .circle):  return CCVisuals.Guilloche.Blend.M_Circle.all
        case ("M", .square):  return CCVisuals.Guilloche.Blend.M_Square.all
        case ("M", .polygon): return CCVisuals.Guilloche.Blend.M_Polygon.all
        case ("N", .circle):  return CCVisuals.Guilloche.Blend.N_Circle.all
        case ("N", .square):  return CCVisuals.Guilloche.Blend.N_Square.all
        case ("N", .polygon): return CCVisuals.Guilloche.Blend.N_Polygon.all
        case ("O", .circle):  return CCVisuals.Guilloche.Blend.O_Circle.all
        case ("O", .square):  return CCVisuals.Guilloche.Blend.O_Square.all
        case ("O", .polygon): return CCVisuals.Guilloche.Blend.O_Polygon.all
        case ("P", .circle):  return CCVisuals.Guilloche.Blend.P_Circle.all
        case ("P", .square):  return CCVisuals.Guilloche.Blend.P_Square.all
        case ("P", .polygon): return CCVisuals.Guilloche.Blend.P_Polygon.all
        case ("Q", .circle):  return CCVisuals.Guilloche.Blend.Q_Circle.all
        case ("Q", .square):  return CCVisuals.Guilloche.Blend.Q_Square.all
        case ("Q", .polygon): return CCVisuals.Guilloche.Blend.Q_Polygon.all
        case ("R", .circle):  return CCVisuals.Guilloche.Blend.R_Circle.all
        case ("R", .square):  return CCVisuals.Guilloche.Blend.R_Square.all
        case ("R", .polygon): return CCVisuals.Guilloche.Blend.R_Polygon.all
        case ("S", .circle):  return CCVisuals.Guilloche.Blend.S_Circle.all
        case ("S", .square):  return CCVisuals.Guilloche.Blend.S_Square.all
        case ("S", .polygon): return CCVisuals.Guilloche.Blend.S_Polygon.all
        case ("T", .circle):  return CCVisuals.Guilloche.Blend.T_Circle.all
        case ("T", .square):  return CCVisuals.Guilloche.Blend.T_Square.all
        case ("T", .polygon): return CCVisuals.Guilloche.Blend.T_Polygon.all
        case ("U", .circle):  return CCVisuals.Guilloche.Blend.U_Circle.all
        case ("U", .square):  return CCVisuals.Guilloche.Blend.U_Square.all
        case ("U", .polygon): return CCVisuals.Guilloche.Blend.U_Polygon.all
        case ("V", .circle):  return CCVisuals.Guilloche.Blend.V_Circle.all
        case ("V", .square):  return CCVisuals.Guilloche.Blend.V_Square.all
        case ("V", .polygon): return CCVisuals.Guilloche.Blend.V_Polygon.all
        case ("W", .circle):  return CCVisuals.Guilloche.Blend.W_Circle.all
        case ("W", .square):  return CCVisuals.Guilloche.Blend.W_Square.all
        case ("W", .polygon): return CCVisuals.Guilloche.Blend.W_Polygon.all
        case ("X", .circle):  return CCVisuals.Guilloche.Blend.X_Circle.all
        case ("X", .square):  return CCVisuals.Guilloche.Blend.X_Square.all
        case ("X", .polygon): return CCVisuals.Guilloche.Blend.X_Polygon.all
        case ("Y", .circle):  return CCVisuals.Guilloche.Blend.Y_Circle.all
        case ("Y", .square):  return CCVisuals.Guilloche.Blend.Y_Square.all
        case ("Y", .polygon): return CCVisuals.Guilloche.Blend.Y_Polygon.all
        case ("Z", .circle):  return CCVisuals.Guilloche.Blend.Z_Circle.all
        case ("Z", .square):  return CCVisuals.Guilloche.Blend.Z_Square.all
        case ("Z", .polygon): return CCVisuals.Guilloche.Blend.Z_Polygon.all
        default: return nil
        }
    }
}
