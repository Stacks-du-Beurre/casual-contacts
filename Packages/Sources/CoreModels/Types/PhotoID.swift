import Foundation

public struct PhotoID: Hashable, Codable, Sendable {
    public let filename: String

    public init(filename: String) {
        self.filename = filename
    }
}
