import Testing
@testable import DesignSystem

@Suite struct DesignSystemSmokeTests {
    @Test func namespaceIsAccessible() {
        // Compilation test — if CCDesign resolves, DesignSystem module imports cleanly.
        _ = CCDesign.self
    }
}
