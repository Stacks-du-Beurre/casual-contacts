import Foundation
import CoreModels

public struct FixedMetadataGenerator: MetadataGenerator {

    private let metadata: RecordMetadata

    public init(metadata: RecordMetadata = RecordMetadata(timeOfDay: .midday, moonPhase: .fullMoon)) {
        self.metadata = metadata
    }

    public func metadata(at date: Date, location: LocationInfo?) -> RecordMetadata {
        metadata
    }
}
