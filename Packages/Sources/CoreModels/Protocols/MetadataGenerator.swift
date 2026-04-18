import Foundation

public protocol MetadataGenerator: Sendable {
    func metadata(at date: Date, location: LocationInfo?) -> RecordMetadata
}
