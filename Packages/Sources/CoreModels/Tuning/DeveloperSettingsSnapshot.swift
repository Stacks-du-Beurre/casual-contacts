import Foundation

public struct DeveloperSettingsSnapshot: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var exportedAt: Date
    public var source: Source
    public var settings: Settings

    public init(
        schemaVersion: Int,
        exportedAt: Date,
        source: Source,
        settings: Settings
    ) {
        self.schemaVersion = schemaVersion
        self.exportedAt = exportedAt
        self.source = source
        self.settings = settings
    }

    public struct Source: Codable, Equatable, Sendable {
        public var appBundleIdentifier: String
        public var appVersion: String
        public var buildNumber: String

        public init(appBundleIdentifier: String, appVersion: String, buildNumber: String) {
            self.appBundleIdentifier = appBundleIdentifier
            self.appVersion = appVersion
            self.buildNumber = buildNumber
        }
    }

    public struct Settings: Codable, Equatable, Sendable {
        public var motion: Motion
        public var hologram: Hologram
        public var cardBackdrop: CardBackdrop
        public var diagnostics: Diagnostics
        public var gradientAndFiligree: GradientAndFiligree
        public var elementDepth: ElementDepth
        public var zodiacAndPhoto: ZodiacAndPhoto
        public var mediumCard: MediumCard

        public init(
            motion: Motion,
            hologram: Hologram,
            cardBackdrop: CardBackdrop,
            diagnostics: Diagnostics,
            gradientAndFiligree: GradientAndFiligree,
            elementDepth: ElementDepth,
            zodiacAndPhoto: ZodiacAndPhoto,
            mediumCard: MediumCard
        ) {
            self.motion = motion
            self.hologram = hologram
            self.cardBackdrop = cardBackdrop
            self.diagnostics = diagnostics
            self.gradientAndFiligree = gradientAndFiligree
            self.elementDepth = elementDepth
            self.zodiacAndPhoto = zodiacAndPhoto
            self.mediumCard = mediumCard
        }

        public struct Motion: Codable, Equatable, Sendable {
            public var relativeFullScaleDegrees: Double
            public var saveButtonGradientGain: Double
            public var zeroPointSettleDuration: Double

            public init(
                relativeFullScaleDegrees: Double,
                saveButtonGradientGain: Double,
                zeroPointSettleDuration: Double
            ) {
                self.relativeFullScaleDegrees = relativeFullScaleDegrees
                self.saveButtonGradientGain = saveButtonGradientGain
                self.zeroPointSettleDuration = zeroPointSettleDuration
            }
        }

        public struct Hologram: Codable, Equatable, Sendable {
            public var backdropBlurOpacity: Double
            public var whiteFillOpacity: Double
            public var lightenOpacity: Double
            public var luminosityOpacity: Double
            public var translationScaleX: Double
            public var translationScaleY: Double
            public var rotationDegrees: Double

            public init(
                backdropBlurOpacity: Double,
                whiteFillOpacity: Double,
                lightenOpacity: Double,
                luminosityOpacity: Double,
                translationScaleX: Double,
                translationScaleY: Double,
                rotationDegrees: Double
            ) {
                self.backdropBlurOpacity = backdropBlurOpacity
                self.whiteFillOpacity = whiteFillOpacity
                self.lightenOpacity = lightenOpacity
                self.luminosityOpacity = luminosityOpacity
                self.translationScaleX = translationScaleX
                self.translationScaleY = translationScaleY
                self.rotationDegrees = rotationDegrees
            }
        }

        public struct CardBackdrop: Codable, Equatable, Sendable {
            public var depthScale: Double
            public var hideBackdrop: Bool
            public var reverseDepthOrder: Bool
            public var reverseMotionDirection: Bool
            public var rotationGuillocheMovesInsteadOfRotates: Bool
            public var guillocheMovementScaleX: Double
            public var guillocheMovementScaleY: Double

            public init(
                depthScale: Double,
                hideBackdrop: Bool,
                reverseDepthOrder: Bool,
                reverseMotionDirection: Bool,
                rotationGuillocheMovesInsteadOfRotates: Bool,
                guillocheMovementScaleX: Double,
                guillocheMovementScaleY: Double
            ) {
                self.depthScale = depthScale
                self.hideBackdrop = hideBackdrop
                self.reverseDepthOrder = reverseDepthOrder
                self.reverseMotionDirection = reverseMotionDirection
                self.rotationGuillocheMovesInsteadOfRotates = rotationGuillocheMovesInsteadOfRotates
                self.guillocheMovementScaleX = guillocheMovementScaleX
                self.guillocheMovementScaleY = guillocheMovementScaleY
            }
        }

        public struct Diagnostics: Codable, Equatable, Sendable {
            public var showsCardAnimationOverlay: Bool

            public init(showsCardAnimationOverlay: Bool) {
                self.showsCardAnimationOverlay = showsCardAnimationOverlay
            }
        }

        public struct GradientAndFiligree: Codable, Equatable, Sendable {
            public var emptyStateEdgeReach: Double
            public var emptyStateRotationDegrees: Double
            public var cardRotationDegrees: Double
            public var emptyStateOpacity: Double
            public var cardOpacity: Double
            public var cardPhotoOpacity: Double

            public init(
                emptyStateEdgeReach: Double,
                emptyStateRotationDegrees: Double,
                cardRotationDegrees: Double,
                emptyStateOpacity: Double,
                cardOpacity: Double,
                cardPhotoOpacity: Double
            ) {
                self.emptyStateEdgeReach = emptyStateEdgeReach
                self.emptyStateRotationDegrees = emptyStateRotationDegrees
                self.cardRotationDegrees = cardRotationDegrees
                self.emptyStateOpacity = emptyStateOpacity
                self.cardOpacity = cardOpacity
                self.cardPhotoOpacity = cardPhotoOpacity
            }
        }

        public struct ElementDepth: Codable, Equatable, Sendable {
            public var perspectiveAmount: Double
            public var isSkewEnabled: Bool
            public var skewAmount: Double
            public var moonPhaseLayer: Int
            public var zodiacGlyphLayer: Int
            public var zodiacConstellationLayer: Int

            public init(
                perspectiveAmount: Double,
                isSkewEnabled: Bool,
                skewAmount: Double,
                moonPhaseLayer: Int,
                zodiacGlyphLayer: Int,
                zodiacConstellationLayer: Int
            ) {
                self.perspectiveAmount = perspectiveAmount
                self.isSkewEnabled = isSkewEnabled
                self.skewAmount = skewAmount
                self.moonPhaseLayer = moonPhaseLayer
                self.zodiacGlyphLayer = zodiacGlyphLayer
                self.zodiacConstellationLayer = zodiacConstellationLayer
            }
        }

        public struct ZodiacAndPhoto: Codable, Equatable, Sendable {
            public var zodiacRotationDegrees: Double
            public var photoFaceZoom: Double
            public var photoOpacity: Double

            public init(zodiacRotationDegrees: Double, photoFaceZoom: Double, photoOpacity: Double) {
                self.zodiacRotationDegrees = zodiacRotationDegrees
                self.photoFaceZoom = photoFaceZoom
                self.photoOpacity = photoOpacity
            }
        }

        public struct MediumCard: Codable, Equatable, Sendable {
            public var aspectRatio: Double

            public init(aspectRatio: Double) {
                self.aspectRatio = aspectRatio
            }
        }
    }
}
