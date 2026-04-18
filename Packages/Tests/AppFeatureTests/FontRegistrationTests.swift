import Testing
import Foundation
import CoreText
@testable import AppFeature

@Suite struct FontRegistrationTests {

    @Test func registerBundledFontsReturnsFourFontNames() {
        let names = FontRegistration.registerBundledFonts()
        #expect(names.contains("CormorantSC-Bold"))
        #expect(names.contains("CormorantSC-SemiBold"))
        #expect(names.contains("CormorantInfant"))
        #expect(names.contains("IBMPlexMono-Regular"))
    }

    @Test func registerBundledFontsIsIdempotent() {
        _ = FontRegistration.registerBundledFonts()
        let secondRun = FontRegistration.registerBundledFonts()
        // Second run should not throw, should return the same names.
        #expect(secondRun.contains("CormorantSC-Bold"))
    }
}
