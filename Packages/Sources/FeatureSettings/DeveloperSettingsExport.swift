import Foundation
import CoreModels
import Visuals

struct DeveloperSettingsUploadConfiguration: Equatable {
    let endpoint: URL
    let token: String

    init(endpoint: URL, token: String) {
        self.endpoint = endpoint
        self.token = token
    }

    init?(info: [String: Any]) {
        guard
            let endpointString = info["CCDeveloperSettingsUploadURL"] as? String,
            endpointString.isEmpty == false,
            endpointString.contains("$(") == false,
            let endpoint = URL(string: endpointString),
            let token = info["CCDeveloperSettingsUploadToken"] as? String,
            token.isEmpty == false,
            token.contains("$(") == false
        else {
            return nil
        }

        self.init(endpoint: endpoint, token: token)
    }

    static func current(bundle: Bundle = .main) -> DeveloperSettingsUploadConfiguration? {
        DeveloperSettingsUploadConfiguration(info: bundle.infoDictionary ?? [:])
    }
}

@MainActor
struct DeveloperSettingsUploadClient {
    enum UploadError: Error, Equatable {
        case invalidResponse
        case rejected(statusCode: Int)
    }

    typealias Send = (URLRequest, Data) async throws -> (Data, HTTPURLResponse)

    let configuration: DeveloperSettingsUploadConfiguration
    private let send: Send

    init(
        configuration: DeveloperSettingsUploadConfiguration,
        send: @escaping Send = DeveloperSettingsUploadClient.liveSend
    ) {
        self.configuration = configuration
        self.send = send
    }

    func upload(_ snapshot: DeveloperSettingsSnapshot) async throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        let body = try encoder.encode(snapshot)

        var request = URLRequest(url: configuration.endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(configuration.token)", forHTTPHeaderField: "Authorization")

        let (_, response) = try await send(request, body)
        guard (200..<300).contains(response.statusCode) else {
            throw UploadError.rejected(statusCode: response.statusCode)
        }
    }

    private static func liveSend(_ request: URLRequest, _ body: Data) async throws -> (Data, HTTPURLResponse) {
        var request = request
        request.httpBody = body
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw UploadError.invalidResponse
        }
        return (data, httpResponse)
    }
}

@MainActor
enum DeveloperSettingsSnapshotBuilder {
    static func current(
        exportedAt: Date = Date(),
        bundle: Bundle = .main,
        tuning: HologramTuning = .shared,
        gradientTuning: EmptyStateGradientTuning = .shared,
        cardBlendTuning: CardBlendTuning = .shared,
        zodiacTuning: ZodiacHologramTuning = .shared,
        rotationTuning: GuillocheRotationTuning = .shared,
        photoFocusTuning: PhotoFocusTuning = .shared,
        mediumCardTuning: MediumCardSizeTuning = .shared,
        elementDepthTuning: CardElementDepthTuning = .shared,
        motionTuning: MotionTuning = .shared,
        cardAnimationDiagnostics: CardAnimationDiagnostics = .shared
    ) -> DeveloperSettingsSnapshot {
        DeveloperSettingsSnapshot(
            schemaVersion: DeveloperSettingsSnapshot.currentSchemaVersion,
            exportedAt: exportedAt,
            source: .init(
                appBundleIdentifier: bundle.bundleIdentifier ?? "unknown",
                appVersion: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown",
                buildNumber: bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"
            ),
            settings: .init(
                motion: .init(
                    relativeFullScaleDegrees: motionTuning.relativeFullScaleDegrees,
                    saveButtonGradientGain: motionTuning.saveButtonGradientGain,
                    zeroPointSettleDuration: motionTuning.zeroPointSettleDuration
                ),
                hologram: .init(
                    backdropBlurOpacity: tuning.backdropBlurOpacity,
                    whiteFillOpacity: tuning.whiteFillOpacity,
                    lightenOpacity: tuning.lightenOpacity,
                    luminosityOpacity: tuning.luminosityOpacity,
                    translationScaleX: tuning.translationScaleX,
                    translationScaleY: tuning.translationScaleY,
                    rotationDegrees: tuning.rotationDegrees
                ),
                cardBackdrop: .init(
                    depthScale: cardBlendTuning.depthScale,
                    hideBackdrop: cardBlendTuning.hideBackdrop,
                    reverseDepthOrder: cardBlendTuning.reverseDepthOrder,
                    reverseMotionDirection: cardBlendTuning.reverseMotionDirection,
                    rotationGuillocheMovesInsteadOfRotates: cardBlendTuning.rotationGuillocheMovesInsteadOfRotates,
                    guillocheMovementScaleX: cardBlendTuning.guillocheMovementScaleX,
                    guillocheMovementScaleY: cardBlendTuning.guillocheMovementScaleY
                ),
                diagnostics: .init(
                    showsCardAnimationOverlay: cardAnimationDiagnostics.showsOverlay
                ),
                gradientAndFiligree: .init(
                    emptyStateEdgeReach: gradientTuning.edgeReach,
                    emptyStateRotationDegrees: rotationTuning.emptyStateRotationDegrees,
                    cardRotationDegrees: rotationTuning.cardRotationDegrees,
                    emptyStateOpacity: rotationTuning.emptyStateOpacity,
                    cardOpacity: rotationTuning.cardOpacity,
                    cardPhotoOpacity: rotationTuning.cardPhotoOpacity
                ),
                elementDepth: .init(
                    perspectiveAmount: elementDepthTuning.perspectiveAmount,
                    isSkewEnabled: elementDepthTuning.isSkewEnabled,
                    skewAmount: elementDepthTuning.skewAmount,
                    moonPhaseLayer: elementDepthTuning.moonPhaseLayer,
                    zodiacGlyphLayer: elementDepthTuning.zodiacGlyphLayer,
                    zodiacConstellationLayer: elementDepthTuning.zodiacConstellationLayer
                ),
                zodiacAndPhoto: .init(
                    zodiacRotationDegrees: zodiacTuning.rotationDegrees,
                    photoFaceZoom: photoFocusTuning.faceZoom,
                    photoOpacity: photoFocusTuning.opacity
                ),
                mediumCard: .init(aspectRatio: mediumCardTuning.aspectRatio)
            )
        )
    }
}
