import Foundation

public extension CCVisuals {
    /// Public bundle accessor so downstream modules (e.g. FeatureCreate) can
    /// load shared SVG assets from the Visuals asset catalogs via
    /// `Image(name:bundle: CCVisuals.bundle)` or `NSDataAsset(name:bundle:)`.
    static var bundle: Bundle { .module }
}
