import Foundation

/// Simulator-only ablations for the moving-card performance harness. Never
/// removes content in a production build or outside the explicit harness.
enum CardRenderProbe {
    static let deferMissingMaterials = enabled("-MotionDeferMissingMaterials")
    static let layeredGuilloche = enabled("-MotionLayeredGuilloche")
    static let omitGradient = enabled("-MotionOmitGradient")
    static let omitGuilloche = enabled("-MotionOmitGuilloche")
    static let omitText = enabled("-MotionOmitText")
    static let omitMaterial = enabled("-MotionOmitMaterial")
    static let omitHologram = enabled("-MotionOmitHologram")

    private static func enabled(_ flag: String) -> Bool {
        #if DEBUG && targetEnvironment(simulator)
        let arguments = ProcessInfo.processInfo.arguments
        return arguments.contains("-MotionPerformanceHarness") && arguments.contains(flag)
        #else
        return false
        #endif
    }
}
