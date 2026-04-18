import Foundation
import CoreText
import DesignSystem

public enum FontRegistration {

    /// Registers all OFL fonts shipped in DesignSystem's resource bundle so that
    /// `Font.custom("Name", size: ...)` can resolve them. Call once at app launch.
    ///
    /// Returns the list of font PostScript names that were available after registration
    /// (some may have already been registered by a prior call — that's fine).
    @discardableResult
    public static func registerBundledFonts() -> [String] {
        let fontBaseNames = [
            "CormorantSC-Bold",
            "CormorantSC-SemiBold",
            "CormorantInfant-Variable",
            "CormorantInfant-SemiBold",
            "IBMPlexMono-Regular"
        ]

        // The DesignSystem target owns the fonts; Bundle.module on a *DesignSystem* symbol
        // resolves to the correct bundle. We hop through CCDesign.bundle to reach it.
        let bundle = CCDesign.bundle

        var registeredNames: [String] = []

        for baseName in fontBaseNames {
            guard let url = bundle.url(forResource: baseName, withExtension: "ttf") else {
                continue
            }
            var cfError: Unmanaged<CFError>?
            let registered = CTFontManagerRegisterFontsForURL(url as CFURL, .process, &cfError)
            if !registered, let error = cfError?.takeRetainedValue() {
                let code = CFErrorGetCode(error)
                // 105 = kCTFontManagerErrorAlreadyRegistered — not a real failure.
                if code != 105 {
                    // Swallow other errors — font just won't resolve and we'll fall back to system.
                    // Production apps would log this.
                    continue
                }
            }
            registeredNames.append(postScriptName(for: baseName))
        }

        return registeredNames
    }

    /// Map our filename to the actual PostScript font name SwiftUI expects.
    private static func postScriptName(for filename: String) -> String {
        switch filename {
        case "CormorantSC-Bold":         return "CormorantSC-Bold"
        case "CormorantSC-SemiBold":     return "CormorantSC-SemiBold"
        case "CormorantInfant-Variable": return "CormorantInfant"
        case "CormorantInfant-SemiBold": return "CormorantInfant-SemiBold"
        case "IBMPlexMono-Regular":      return "IBMPlexMono-Regular"
        default:                         return filename
        }
    }
}
