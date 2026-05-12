import Foundation
import Testing
import CoreModels
@testable import FeatureSettings

@Suite @MainActor struct DeveloperSettingsUploadTests {
    @Test func configurationIsDisabledWhenEndpointOrTokenIsMissing() {
        #expect(DeveloperSettingsUploadConfiguration(info: [:]) == nil)
        #expect(DeveloperSettingsUploadConfiguration(info: ["CCDeveloperSettingsUploadURL": "https://casualcontacts.app/api/developer-settings"]) == nil)
        #expect(DeveloperSettingsUploadConfiguration(info: ["CCDeveloperSettingsUploadToken": "secret"]) == nil)
    }

    @Test func configurationReadsEndpointAndTokenFromInfoDictionary() throws {
        let configuration = try #require(DeveloperSettingsUploadConfiguration(info: [
            "CCDeveloperSettingsUploadURL": "https://casualcontacts.app/api/developer-settings",
            "CCDeveloperSettingsUploadToken": "secret"
        ]))

        #expect(configuration.endpoint == URL(string: "https://casualcontacts.app/api/developer-settings"))
        #expect(configuration.token == "secret")
    }

    @Test func uploadClientPostsSnapshotWithBearerToken() async throws {
        let snapshot = DeveloperSettingsSnapshot.testFixture()
        var capturedRequest: URLRequest?
        var capturedBody: Data?
        let client = DeveloperSettingsUploadClient(
            configuration: DeveloperSettingsUploadConfiguration(
                endpoint: try #require(URL(string: "https://casualcontacts.app/api/developer-settings")),
                token: "secret"
            ),
            send: { request, body in
                capturedRequest = request
                capturedBody = body
                return (Data(#"{"ok":true}"#.utf8), HTTPURLResponse(
                    url: request.url!,
                    statusCode: 201,
                    httpVersion: nil,
                    headerFields: nil
                )!)
            }
        )

        try await client.upload(snapshot)

        #expect(capturedRequest?.httpMethod == "POST")
        #expect(capturedRequest?.value(forHTTPHeaderField: "Authorization") == "Bearer secret")
        #expect(capturedRequest?.value(forHTTPHeaderField: "Content-Type") == "application/json")
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(DeveloperSettingsSnapshot.self, from: try #require(capturedBody))
        #expect(decoded == snapshot)
    }

    @Test func uploadClientThrowsOnRejectedResponse() async throws {
        let client = DeveloperSettingsUploadClient(
            configuration: DeveloperSettingsUploadConfiguration(
                endpoint: try #require(URL(string: "https://casualcontacts.app/api/developer-settings")),
                token: "secret"
            ),
            send: { request, _ in
                (Data(), HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!)
            }
        )

        await #expect(throws: DeveloperSettingsUploadClient.UploadError.rejected(statusCode: 401)) {
            try await client.upload(.testFixture())
        }
    }
}

private extension DeveloperSettingsSnapshot {
    static func testFixture() -> DeveloperSettingsSnapshot {
        DeveloperSettingsSnapshot(
            schemaVersion: DeveloperSettingsSnapshot.currentSchemaVersion,
            exportedAt: Date(timeIntervalSince1970: 1_777_000_000),
            source: .init(appBundleIdentifier: "tests", appVersion: "1", buildNumber: "1"),
            settings: .init(
                motion: .init(relativeFullScaleDegrees: 45, saveButtonGradientGain: 2.5, zeroPointSettleDuration: 2),
                hologram: .init(
                    backdropBlurOpacity: 1,
                    whiteFillOpacity: 0.56,
                    lightenOpacity: 0.2,
                    luminosityOpacity: 0.35,
                    translationScaleX: 90,
                    translationScaleY: 90,
                    rotationDegrees: 30
                ),
                cardBackdrop: .init(
                    depthScale: 5,
                    hideBackdrop: false,
                    reverseDepthOrder: false,
                    reverseMotionDirection: true,
                    rotationGuillocheMovesInsteadOfRotates: false,
                    guillocheMovementScaleX: 0.8,
                    guillocheMovementScaleY: 0.8
                ),
                diagnostics: .init(showsCardAnimationOverlay: false),
                gradientAndFiligree: .init(
                    emptyStateEdgeReach: 1,
                    emptyStateRotationDegrees: 90,
                    cardRotationDegrees: 45,
                    emptyStateOpacity: 0.3,
                    cardOpacity: 0.2,
                    cardPhotoOpacity: 0.23
                ),
                elementDepth: .init(
                    perspectiveAmount: 1,
                    isSkewEnabled: false,
                    skewAmount: 0.08,
                    moonPhaseLayer: 12,
                    zodiacGlyphLayer: 4,
                    zodiacConstellationLayer: 12
                ),
                zodiacAndPhoto: .init(zodiacRotationDegrees: 300, photoFaceZoom: 0, photoOpacity: 0.35),
                mediumCard: .init(aspectRatio: 1)
            )
        )
    }
}
