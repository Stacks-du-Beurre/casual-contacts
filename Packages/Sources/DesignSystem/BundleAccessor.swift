import Foundation

public extension CCDesign {
    /// Publicly-accessible bundle for DesignSystem resources (fonts, asset catalogs).
    /// Needed by AppFeature to register OFL fonts via CTFontManager at launch.
    static var bundle: Bundle { Bundle.module }
}
