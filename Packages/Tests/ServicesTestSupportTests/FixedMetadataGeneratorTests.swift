import Testing
import Foundation
import CoreModels
@testable import ServicesTestSupport

@Suite struct FixedMetadataGeneratorTests {

    @Test func returnsSuppliedMetadataRegardlessOfInput() {
        let expected = RecordMetadata(timeOfDay: .dusk, moonPhase: .waxingCrescent)
        let generator = FixedMetadataGenerator(metadata: expected)

        let a = generator.metadata(at: Date(), location: nil)
        let b = generator.metadata(
            at: Date(timeIntervalSince1970: 0),
            location: LocationInfo(latitude: 0, longitude: 0, label: nil)
        )

        #expect(a == expected)
        #expect(b == expected)
    }
}
